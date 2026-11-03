import Foundation
import UserNotifications

struct StudyDailyPlan {
    let date: Date
    let lines: [String]
    static func make(works: [MoodleWork], exams: [StudentExam], days: Int, hour: Int, now: Date) -> [Self] {
        let calendar = CampusDate.calendar
        return (0...14).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                  let fire = calendar.date(bySettingHour: min(23, max(0, hour)), minute: 0, second: 0, of: day), fire > now,
                  let end = calendar.date(byAdding: .day, value: days + 1, to: day) else { return nil }
            let workLines = works.filter { ["notSubmitted", "draft"].contains($0.status) && ($0.dueDate.map { $0 > fire && $0 < end } ?? false) }
                .sorted { $0.dueDate! < $1.dueDate! }.map { $0.course + " · " + $0.displayName }
            let examLines = exams.filter { $0.valid && ($0.start.map { $0 > fire && $0 < end } ?? false) }
                .sorted { $0.start! < $1.start! }.map { $0.course + " · " + $0.date + " " + $0.time }
            let lines = workLines + examLines
            return lines.isEmpty ? nil : Self(date: fire, lines: lines)
        }
    }
}

@MainActor final class StudyDailyReminders {
    static let shared = StudyDailyReminders()
    private var task: Task<Void, Never>?
    func update(works: [MoodleWork], exams: [StudentExam], days: Int, hour: Int, allowPermissionRequest: Bool = false) {
        #if GTIIT_REGRESSION
        return
        #else
        let previous = task
        task = Task {
            await previous?.value
            let center = UNUserNotificationCenter.current(), now = Date()
            let pending = await center.pendingNotificationRequests()
            let own = pending.filter { $0.identifier.hasPrefix("study.daily.") }
            center.removePendingNotificationRequests(withIdentifiers: own.map(\.identifier))
            let plans = StudyDailyPlan.make(works: works, exams: exams, days: days, hour: hour, now: now)
            var status = await center.notificationSettings().authorizationStatus
            if status == .notDetermined && allowPermissionRequest && !plans.isEmpty {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
                status = await center.notificationSettings().authorizationStatus
            }
            guard status == .authorized || status == .provisional else { return }
            let budget = max(0, min(15, 48 - (pending.count - own.count)))
            for plan in plans.prefix(budget) {
                let content = UNMutableNotificationContent()
                content.title = L10n.isEnglish ? "Upcoming assignments & exams" : "作业与考试提醒"
                content.body = plan.lines.prefix(12).joined(separator: "\n")
                content.sound = .default
                content.threadIdentifier = "study.daily"
                var components = CampusDate.calendar.dateComponents([.year,.month,.day,.hour,.minute], from: plan.date)
                components.timeZone = CampusDate.calendar.timeZone
                try? await center.add(UNNotificationRequest(identifier: "study.daily." + String(Int(plan.date.timeIntervalSince1970)), content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
            }
        }
        #endif
    }
}
