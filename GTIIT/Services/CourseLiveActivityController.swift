import ActivityKit
import Foundation
import UIKit
import UserNotifications

struct CourseActivityPlan: Equatable {
    let id: String
    let title: String
    let room: String
    let building: String
    let start: Date
    let end: Date
    var activate: Date { start.addingTimeInterval(-900) }
    static func upcoming(_ snapshot: TimetableSnapshot?, now: Date) -> [Self] {
        guard let snapshot else { return [] }
        let classes = CampusCalendarItem.timetable(snapshot).filter { $0.end.addingTimeInterval(600) > now }
        // Preserve chronological order and let ActivityKit enforce the
        // device's actual capacity; a fixed two-class cutoff misses later classes.
        return classes.map { item in
            Self(id: item.id, title: item.title, room: snapshot.courses.first {
                $0.name == item.title && $0.location == item.location && LocalCourse.minutes($0.start) == CampusDate.calendar.component(.hour, from: item.start) * 60 + CampusDate.calendar.component(.minute, from: item.start)
            }?.room ?? item.location, building: snapshot.courses.first { $0.name == item.title && $0.location == item.location }?.building ?? "", start: item.start, end: item.end)
        }
    }
}

@MainActor final class CourseLiveActivityController {
    static let shared = CourseLiveActivityController()
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var expiryTask: Task<Void, Never>?
    private var reservingShuttleSlot = false
    func sync(snapshot: TimetableSnapshot?, enabled: Bool) {
        #if GTIIT_REGRESSION
        return
        #else
        guard UIApplication.shared.applicationState == .active, !reservingShuttleSlot else { return }
        task?.cancel()
        let token = UUID(); generation = token
        task = Task {
            defer { scheduleExpiry() }
            let now = Date()
            let desired = enabled ? CourseActivityPlan.upcoming(snapshot, now: now) : []
            let language = L10n.language.rawValue
            var issued = Set(UserDefaults.standard.stringArray(forKey: "course.activity.issued") ?? [])
            for activity in Activity<CourseActivityAttributes>.activities {
                let valid = desired.contains {
                    $0.id == activity.attributes.occurrenceID && activity.attributes.language == language &&
                    $0.title == activity.attributes.title && $0.room == activity.attributes.room && $0.building == activity.attributes.building &&
                    $0.start == activity.content.state.start && $0.end == activity.content.state.end
                }
                if !valid || activity.content.state.end.addingTimeInterval(600) <= now {
                    issued.remove(activity.attributes.occurrenceID + "|" + activity.attributes.language)
                    UserDefaults.standard.set(Array(issued.suffix(150)), forKey: "course.activity.issued")
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
            guard !Task.isCancelled, token == generation else { return }
            UserDefaults.standard.set(Array(issued.suffix(150)), forKey: "course.activity.issued")
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let prefix = "course.fiveMinute."
            // Remove reminders scheduled by older builds; the course Live Activity
            // is now the sole pre-class reminder.
            center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier))
            guard !Task.isCancelled, token == generation else { return }
            if !enabled || snapshot == nil { UserDefaults.standard.removeObject(forKey: "course.activity.issued"); return }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            for plan in desired where plan.start > now {
                if #unavailable(iOS 26.0) { if plan.activate > now { continue } }
                let key = plan.id + "|" + language
                if issued.contains(key) || Activity<CourseActivityAttributes>.activities.contains(where: { $0.attributes.occurrenceID == plan.id }) { continue }
                do {
                    _ = try Self.request(plan: plan, language: language, now: now)
                    issued.insert(key)
                    UserDefaults.standard.set(Array(issued.suffix(150)), forKey: "course.activity.issued")
                } catch { LocalDiagnostics.shared.record("courseActivity.requestFailed"); break }
            }
        }
        #endif
    }
    /// On a capacity error, yield the furthest pending course to a shuttle the
    /// user explicitly starts. The course remains eligible for a later refill.
    func reserveSlotForShuttle() async -> Bool {
        guard #available(iOS 26.0, *), !reservingShuttleSlot,
              let pending = Activity<CourseActivityAttributes>.activities
                .filter({ $0.activityState == .pending && $0.content.state.start > Date() })
                .max(by: { $0.content.state.start < $1.content.state.start }) else { return false }
        reservingShuttleSlot = true
        generation = UUID(); task?.cancel()
        await pending.end(nil, dismissalPolicy: .immediate)
        var issued = Set(UserDefaults.standard.stringArray(forKey: "course.activity.issued") ?? [])
        issued.remove(pending.attributes.occurrenceID + "|" + pending.attributes.language)
        UserDefaults.standard.set(Array(issued), forKey: "course.activity.issued")
        return true
    }
    func finishReservingShuttleSlot() { reservingShuttleSlot = false }
    private func scheduleExpiry() {
        ActivityLifecycleCleanup.schedule()
        expiryTask?.cancel()
        expiryTask = Task {
            while !Task.isCancelled {
                let activities = Activity<CourseActivityAttributes>.activities
                guard let next = activities.map({ $0.content.state.end.addingTimeInterval(600) }).min() else { return }
                do { try await Task.sleep(for: .seconds(max(0, next.timeIntervalSinceNow))) } catch { return }
                for activity in Activity<CourseActivityAttributes>.activities where activity.content.state.end.addingTimeInterval(600) <= Date() {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }
    /// Production and debug verification use the identical ActivityKit request path.
    @discardableResult
    static func request(plan: CourseActivityPlan, language: String, now: Date) throws -> Activity<CourseActivityAttributes> {
        let attributes = CourseActivityAttributes(occurrenceID: plan.id, title: plan.title, room: plan.room, building: plan.building, language: language)
        let content = ActivityContent(state: CourseActivityAttributes.ContentState(start: plan.start, end: plan.end), staleDate: plan.start)
        if #available(iOS 26.0, *), plan.activate > now {
            return try Activity.request(attributes: attributes, content: content, pushType: nil, style: .standard,
                alertConfiguration: AlertConfiguration(title: "课前提醒", body: "课程将在 15 分钟后开始", sound: .default), start: plan.activate)
        }
        return try Activity.request(attributes: attributes, content: content, pushType: nil)
    }

}
