#if DEBUG
import ActivityKit
import Foundation
import WidgetKit

/// Debug builds only: synthetic system-level fixtures, never modifies the user's timetable.
@MainActor enum ActivityReviewLauncher {
    static func run(kind: String) async {
        if kind == "widget" { WidgetCenter.shared.reloadAllTimelines(); record("widget reload requested"); return }
        for activity in Activity<CourseActivityAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
        for activity in Activity<ShuttleActivityAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
        if kind == "end" { return }
        let now = Date()
        do {
            let id: String
            if kind == "shuttle" {
                let date = now.addingTimeInterval(345)
                let attributes = ShuttleActivityAttributes(directionTitle: "南 → 北", origin: "南校区", destination: "北校区",
                    departureTime: ShuttleActivityWords.time(date), busLabel: "1 号", directionRaw: "southToNorth", languageCode: "zh-Hans", departedLabel: "已发车")
                id = try Activity.request(attributes: attributes, content: ActivityContent(state: .init(departureDate: date, busNumber: 1), staleDate: date), pushType: nil).id
            } else {
                let start = now.addingTimeInterval(kind == "scheduled" ? 615 : 480)
                let plan = CourseActivityPlan(id: "review-" + UUID().uuidString, title: "Introduction to Robotics", room: "E1-205", building: "南校区", start: start, end: start.addingTimeInterval(5400))
                let activity = try CourseLiveActivityController.request(plan: plan, language: "zh-Hans", now: now)
                id = activity.id
                record("initial: " + String(describing: activity.activityState))
                Task {
                    for await state in activity.activityStateUpdates {
                        record("state: " + String(describing: state))
                    }
                }
            }
            record("created " + kind + " " + id)
        } catch {
            try? String(describing: error).write(to: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("activity-review.txt"), atomically: true, encoding: .utf8)
        }
    }
    private static func record(_ line: String) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("activity-review.txt")
        let old = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? (old + ISO8601DateFormatter().string(from: Date()) + " " + line + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

}
#endif
