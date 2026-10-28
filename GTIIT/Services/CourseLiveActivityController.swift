import ActivityKit
import Foundation
import UIKit

struct CourseActivityPlan: Equatable {
    let id: String
    let title: String
    let room: String
    let building: String
    let start: Date
    let end: Date
    var activate: Date { start.addingTimeInterval(-600) }
    static func upcoming(_ snapshot: TimetableSnapshot?, now: Date) -> [Self] {
        guard let snapshot else { return [] }
        let classes = CampusCalendarItem.timetable(snapshot).filter { $0.start > now }
        return Array(classes.prefix(2)).map { item in
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
    func sync(snapshot: TimetableSnapshot?, enabled: Bool) {
        #if GTIIT_REGRESSION
        return
        #else
        guard UIApplication.shared.applicationState == .active else { return }
        task?.cancel()
        let token = UUID(); generation = token
        task = Task {
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
                if !valid || activity.content.state.start.addingTimeInterval(300) < now {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    issued.remove(activity.attributes.occurrenceID + "|" + activity.attributes.language)
                }
            }
            guard !Task.isCancelled, token == generation else { return }
            UserDefaults.standard.set(Array(issued.suffix(150)), forKey: "course.activity.issued")
            if !enabled || snapshot == nil { UserDefaults.standard.removeObject(forKey: "course.activity.issued"); return }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            for plan in desired {
                let key = plan.id + "|" + language
                if issued.contains(key) || Activity<CourseActivityAttributes>.activities.contains(where: { $0.attributes.occurrenceID == plan.id }) { continue }
                let attributes = CourseActivityAttributes(occurrenceID: plan.id, title: plan.title, room: plan.room, building: plan.building, language: language)
                let content = ActivityContent(state: CourseActivityAttributes.ContentState(start: plan.start, end: plan.end), staleDate: plan.start)
                do {
                    if plan.activate > now {
                        if #available(iOS 26.0, *) {
                            _ = try Activity.request(attributes: attributes, content: content, pushType: nil, style: .standard,
                                alertConfiguration: AlertConfiguration(title: "课前提醒", body: "课程将在 10 分钟后开始", sound: .default), start: plan.activate)
                        } else { continue }
                    } else {
                        _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
                    }
                    issued.insert(key)
                    UserDefaults.standard.set(Array(issued.suffix(150)), forKey: "course.activity.issued")
                } catch { LocalDiagnostics.shared.record("courseActivity.requestFailed"); break }
            }
        }
        #endif
    }
}
