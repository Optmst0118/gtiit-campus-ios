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
                DynamicIslandExpandedRegion(.leading) { Text(context.attributes.title).font(.headline).lineLimit(2) }
                DynamicIslandExpandedRegion(.trailing) { Text(context.attributes.room).font(.title2.bold()).foregroundStyle(ActivityPalette.blue) }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.building).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        ShuttleActivityCountdown(date: context.state.start, expired: context.isStale, language: context.attributes.language, expiredLabel: context.attributes.language == "en" ? "Started" : "已上课")
                            .frame(width: 95).foregroundStyle(ActivityPalette.blue)
                    }
                }
            } compactLeading: { Image(systemName: "graduationcap.fill").foregroundStyle(ActivityPalette.blue) }
            compactTrailing: {
                ShuttleActivityCountdown(date: context.state.start, expired: context.isStale, language: context.attributes.language, expiredLabel: context.attributes.language == "en" ? "Started" : "已上课").frame(width: 54).font(.caption2)
            } minimal: { Image(systemName: "graduationcap.fill").foregroundStyle(ActivityPalette.blue) }
            .widgetURL(URL(string: "gtiit-beta://timetable"))
        }
    }
}
