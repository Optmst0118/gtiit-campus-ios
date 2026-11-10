import ActivityKit
import SwiftUI
import WidgetKit

struct ShuttleLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShuttleActivityAttributes.self) { context in
            ShuttleActivitySummary(attributes: context.attributes, state: context.state, isStale: context.isStale, systemSurface: true)
                .environment(\.colorScheme, .dark)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(link(context.attributes))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    ShuttleActivitySummary(attributes: context.attributes, state: context.state,
                        isStale: context.isStale, island: true)
                }
            } compactLeading: {
                HStack(spacing: 2) {
                    Text(ShuttleActivityWords.northbound(context.attributes) ? (context.attributes.languageCode == "en" ? "S" : "南") : (context.attributes.languageCode == "en" ? "N" : "北"))
                    Image(systemName: "arrow.right").font(.system(size: 10, weight: .semibold))
                    Text(ShuttleActivityWords.northbound(context.attributes) ? (context.attributes.languageCode == "en" ? "N" : "北") : (context.attributes.languageCode == "en" ? "S" : "南"))
                }
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(ActivityPalette.orange)
                .frame(width: 58, alignment: .center)
                .accessibilityLabel(ShuttleActivityWords.route(context.attributes))
            } compactTrailing: {
                ShuttleActivityCountdown(date: context.state.departureDate, expired: context.isStale,
                    language: context.attributes.languageCode, centered: true)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(ActivityPalette.orange)
                    .frame(width: 58)
            } minimal: {
                Text(context.attributes.languageCode == "en" ?
                    (context.attributes.directionRaw == "northToSouth" ? "S" : "N") :
                    (context.attributes.directionRaw == "northToSouth" ? "南" : "北"))
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(ActivityPalette.orange)
                    .accessibilityLabel(context.attributes.destination)
            }.widgetURL(link(context.attributes))
        }
    }
    private func link(_ attributes: ShuttleActivityAttributes) -> URL? {
        URL(string: "gtiit-beta://shuttle?direction=" + (attributes.directionRaw ?? ShuttleDirection.southToNorth.rawValue))
    }
}
