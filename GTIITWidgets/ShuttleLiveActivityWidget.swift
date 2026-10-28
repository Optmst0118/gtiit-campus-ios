import ActivityKit
import SwiftUI
import WidgetKit

struct ShuttleLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShuttleActivityAttributes.self) { context in
            ShuttleActivitySummary(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(link(context.attributes))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(ShuttleActivityWords.compact(context.attributes), systemImage: "bus.fill")
                        .font(.headline).foregroundStyle(ActivityPalette.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(ShuttleActivityWords.departure(context.state.departureDate, language: context.attributes.languageCode))
                        .font(.caption.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.75).multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        HStack {
                            Text(context.attributes.busLabel).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(ShuttleActivityWords.planned(context.attributes.languageCode)).font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 20) {
                            ShuttleActivityTrack().frame(maxWidth: .infinity).frame(height: 26)
                            ShuttleActivityCountdown(date: context.state.departureDate, expired: context.isStale, language: context.attributes.languageCode)
                                .font(.title2.monospacedDigit().weight(.semibold)).foregroundStyle(ActivityPalette.orange)
                                .frame(width: 110, alignment: .trailing)
                        }
                    }.padding(.top, 5)

                }
            } compactLeading: {
                Text(ShuttleActivityWords.compact(context.attributes)).font(.caption2.weight(.semibold)).foregroundStyle(ActivityPalette.orange)
            } compactTrailing: {
                ShuttleActivityCountdown(date: context.state.departureDate, expired: context.isStale, language: context.attributes.languageCode)
                    .font(.caption2.monospacedDigit()).frame(width: 54, alignment: .trailing)
            } minimal: {
                Image(systemName: "bus.fill").foregroundStyle(ActivityPalette.orange)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: context.attributes.directionRaw == ShuttleDirection.northToSouth.rawValue ? "arrow.down" : "arrow.up")
                            .font(.system(size: 8, weight: .bold)).foregroundStyle(.black)
                            .padding(2).background(ActivityPalette.orange, in: Circle()).offset(x: 5, y: 4)
                    }
            }.widgetURL(link(context.attributes))
        }
    }
    private func link(_ attributes: ShuttleActivityAttributes) -> URL? {
        URL(string: "gtiit-beta://shuttle?direction=" + (attributes.directionRaw ?? ShuttleDirection.southToNorth.rawValue))
    }
}
