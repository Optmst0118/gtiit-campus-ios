import ActivityKit
import SwiftUI
import WidgetKit

struct ShuttleLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShuttleActivityAttributes.self) { context in
            ShuttleActivitySummary(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color(red: 0.055, green: 0.078, blue: 0.11))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(link(context.attributes))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(ShuttleActivityWords.compact(context.attributes), systemImage: "bus.fill")
                        .font(.headline).foregroundStyle(.cyan)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.departureTime).font(.headline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.busLabel).font(.subheadline).foregroundStyle(.secondary)
                        Spacer(minLength: 12)
                        ShuttleActivityCountdown(date: context.state.departureDate, expired: context.isStale, language: context.attributes.languageCode)
                            .font(.title2.monospacedDigit().weight(.semibold)).foregroundStyle(.cyan).frame(width: 110, alignment: .trailing)
                    }.padding(.top, 5)
                }
            } compactLeading: {
                Text(ShuttleActivityWords.compact(context.attributes)).font(.caption2.weight(.semibold)).foregroundStyle(.cyan)
            } compactTrailing: {
                ShuttleActivityCountdown(date: context.state.departureDate, expired: context.isStale, language: context.attributes.languageCode)
                    .font(.caption2.monospacedDigit()).frame(maxWidth: 54)
            } minimal: {
                Image(systemName: "bus.fill").foregroundStyle(.cyan)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: context.attributes.directionRaw == ShuttleDirection.northToSouth.rawValue ? "arrow.down" : "arrow.up")
                            .font(.system(size: 8, weight: .bold)).foregroundStyle(.black)
                            .padding(2).background(.cyan, in: Circle()).offset(x: 5, y: 4)
                    }
            }.widgetURL(link(context.attributes))
        }
    }
    private func link(_ attributes: ShuttleActivityAttributes) -> URL? {
        URL(string: "gtiit://shuttle?direction=" + (attributes.directionRaw ?? ShuttleDirection.southToNorth.rawValue))
    }
}
