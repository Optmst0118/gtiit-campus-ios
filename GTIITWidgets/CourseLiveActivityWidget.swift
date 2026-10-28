import ActivityKit
import SwiftUI
import WidgetKit
struct CourseLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CourseActivityAttributes.self) { context in
            CourseActivitySummary(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .activityBackgroundTint(.clear).activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "gtiit-beta://timetable"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    CourseActivitySummary(attributes: context.attributes, state: context.state,
                        isStale: context.isStale, island: true)
                }
            } compactLeading: {
                Text(context.attributes.room).font(.system(size: 12, weight: .semibold))
                    .lineLimit(1).foregroundStyle(ActivityPalette.blue).frame(maxWidth: 65)
            } compactTrailing: {
                ShuttleActivityCountdown(date: context.state.start, expired: context.isStale,
                    language: context.attributes.language, expiredLabel: context.attributes.language == "en" ? "Started" : "已上课")
                    .font(.system(size: 13, weight: .semibold)).frame(width: 58).foregroundStyle(ActivityPalette.blue)
            } minimal: {
                Text(context.attributes.language == "en" ? "Class" : "课")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(ActivityPalette.blue)
            }
            .widgetURL(URL(string: "gtiit-beta://timetable"))
        }
    }
}
