import Foundation
import UserNotifications

struct StudyDailyPlan {
    let date: Date
    let lines: [String]
    static func make(works: [MoodleWork], exams: [StudentExam], days: Int, hour: Int, now: Date, allowEmptySummary: Bool = false, includePastToday: Bool = false, horizonDays: Int = 31) -> [Self] {
        let calendar = CampusDate.calendar
        // Parse each exam only once, outside the planning horizon loop.
        let preparedExams = exams.compactMap { exam -> (exam: StudentExam, start: Date, day: Date)? in
            guard !exam.course.isEmpty, exam.course.count <= 240, exam.duration >= 0, exam.duration <= 24,
                  let start = exam.start else { return nil }
            return (exam, start, calendar.startOfDay(for: start))
        }.sorted { $0.start == $1.start ? $0.exam.id < $1.exam.id : $0.start < $1.start }
        return (0...max(0, min(31, horizonDays))).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                  let fire = calendar.date(bySettingHour: min(23, max(0, hour)), minute: 0, second: 0, of: day), (fire > now || (includePastToday && offset == 0)),
                  let end = calendar.date(byAdding: .day, value: days + 1, to: day) else { return nil }
            let workLines = works.filter { ["notSubmitted", "draft"].contains($0.status) && ($0.dueDate.map { $0 > fire && $0 < end } ?? false) }
                .sorted { $0.dueDate! < $1.dueDate! }.map {
                    L10n.format("《%@》的《%@》，%@截止。", StudyWidgetSnapshot.courseName($0.course), $0.displayName,
                                $0.dueDate!.gtiitFormatted(date: .abbreviated, time: .shortened))
                }
            let examLines = preparedExams.compactMap { entry -> String? in
                let remaining = calendar.dateComponents([.day], from: day, to: entry.day).day ?? -1
                guard entry.start > fire, [0,3,7,14,31].contains(remaining) else { return nil }
                return L10n.format("《%@》将在%@考试。", StudyWidgetSnapshot.courseName(entry.exam.course), entry.exam.date + " " + entry.exam.time)
                    + " · " + L10n.format("还有 %@ 天", String(remaining))
            }
            var lines = examLines + (workLines.isEmpty ? [] : [L10n.format("还有 %@ 项作业没交。", String(workLines.count))]) + workLines
            if lines.isEmpty && allowEmptySummary && offset <= 1 && works.allSatisfy({ $0.status != "unknown" }) {
                let nextThreeDays = calendar.date(byAdding: .day, value: 3, to: day)!
                let remaining = works.filter { ["notSubmitted", "draft"].contains($0.status) }
                if works.allSatisfy({ $0.isSubmitted }) {
                    lines = [L10n.tr("已经没有作业了，接下来 3 天都没有作业。")]
                } else if !remaining.isEmpty && !works.contains(where: { $0.status == "notOpen" && ($0.dueDate.map { $0 < nextThreeDays } ?? true) }) && !remaining.contains(where: { $0.dueDate.map { $0 < nextThreeDays } ?? true }) {
                    lines = [L10n.tr("接下来 3 天没有待交作业。")]
                }
            }
            return lines.isEmpty ? nil : Self(date: fire, lines: lines)
        }
    }
}

@MainActor protocol DailyNotificationDelivery {
    func authorization() async -> UNAuthorizationStatus
    func requestAuthorization() async -> Bool
    func pending() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePending(_ identifiers: [String])
}

@MainActor private struct SystemDailyNotifications: DailyNotificationDelivery {
    private let center = UNUserNotificationCenter.current()
    func authorization() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }
    func requestAuthorization() async -> Bool { (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false }
    func pending() async -> [UNNotificationRequest] { await center.pendingNotificationRequests() }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func removePending(_ identifiers: [String]) { center.removePendingNotificationRequests(withIdentifiers: identifiers) }
}

@MainActor final class StudyDailyReminders {
    static let shared = StudyDailyReminders()
    private var task: Task<Void, Never>?
    private let delivery: any DailyNotificationDelivery
    private let isTestDelivery: Bool
    private(set) var failed = false
    init(delivery: (any DailyNotificationDelivery)? = nil) {
        isTestDelivery = delivery != nil
        self.delivery = delivery ?? SystemDailyNotifications()
    }
    func waitForUpdates() async { await task?.value }
    func update(works: [MoodleWork], exams: [StudentExam], days: Int, hour: Int, allowPermissionRequest: Bool = false, allowEmptySummary: Bool = false, now: Date = Date()) {
        #if GTIIT_REGRESSION
        guard isTestDelivery else { return }
        #endif
        let previous = task
        task = Task {
            await previous?.value
            failed = false
            let pending = await delivery.pending()
            let own = pending.filter { $0.identifier.hasPrefix("study.daily.") }
            let plans = StudyDailyPlan.make(works: works, exams: exams, days: days, hour: hour, now: now, allowEmptySummary: allowEmptySummary)
            let budget = max(0, min(15, 48 - (pending.count - own.count)))
            let selected = Array(plans.prefix(budget))
            let desiredIDs = Set(selected.map { "study.daily." + String(Int($0.date.timeIntervalSince1970)) })
            delivery.removePending(own.filter { !desiredIDs.contains($0.identifier) }.map(\.identifier))
            var status = await delivery.authorization()
            if status == .notDetermined && allowPermissionRequest && !plans.isEmpty {
                _ = await delivery.requestAuthorization()
                status = await delivery.authorization()
            }
            guard status == .authorized || status == .provisional else { return }
            let existing = Dictionary(own.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
            for plan in selected {
                let content = UNMutableNotificationContent()
                content.title = L10n.tr("作业与考试提醒")
                content.body = plan.lines.prefix(12).joined(separator: "\n")
                content.sound = .default
                content.threadIdentifier = "study.daily"
                var components = CampusDate.calendar.dateComponents([.year,.month,.day,.hour,.minute], from: plan.date)
                components.timeZone = CampusDate.calendar.timeZone
                let id = "study.daily." + String(Int(plan.date.timeIntervalSince1970))
                if let old = existing[id], old.content.title == content.title, old.content.body == content.body,
                   let trigger = old.trigger as? UNCalendarNotificationTrigger, trigger.dateComponents == components { continue }
                do {
                    try await delivery.add(UNNotificationRequest(identifier: id, content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
                } catch {
                    failed = true
                    LocalDiagnostics.shared.record("studyDaily.scheduleFailed")
                }
            }
        }
    }
}
