import ActivityKit
import SwiftUI
import WidgetKit

struct ShuttleLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShuttleActivityAttributes.self) { context in
            ShuttleLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "gtiit://shuttle"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bus.fill")
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.destination)
                            .font(.caption.weight(.semibold))
                        Text("\(context.attributes.departureTime) · \(context.attributes.busLabel)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ShuttleTimer(departure: context.state.departureDate, departedLabel: context.attributes.departedLabel)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.orange)
                }
            } compactLeading: {
                Image(systemName: "bus.fill").foregroundStyle(.orange)
            } compactTrailing: {
                ShuttleTimer(departure: context.state.departureDate, departedLabel: context.attributes.departedLabel)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.orange)
            } minimal: {
                Image(systemName: "bus.fill").foregroundStyle(.orange)
            }
            .widgetURL(URL(string: "gtiit://shuttle"))
        }
    }
}

private struct ShuttleTimer: View {
    let departure: Date
    let departedLabel: String

    var body: some View {
        if departure > Date() {
            Text(timerInterval: Date.now...departure, countsDown: true)
                .monospacedDigit()
        } else {
            Text(departedLabel)
                .font(.caption)
        }
    }
}

private struct ShuttleLockScreenView: View {
    let context: ActivityViewContext<ShuttleActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "bus.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.destination)
                    .font(.headline)
                Text("\(context.attributes.busLabel) · \(context.attributes.departureTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            ShuttleTimer(departure: context.state.departureDate, departedLabel: context.attributes.departedLabel)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(.orange)
        }
        .padding(16)
    }
}