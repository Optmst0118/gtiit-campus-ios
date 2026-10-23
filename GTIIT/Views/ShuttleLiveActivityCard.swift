import SwiftUI

struct ShuttleLiveActivityCard: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var live = ShuttleLiveActivityController.shared
    let direction: ShuttleDirection
    let departure: ShuttleDeparture

    var body: some View {
        if live.isSupported {
            Button {
                Task {
                    if live.activity == nil {
                        await live.start(direction: direction, departure: departure)
                    } else {
                        await live.stop()
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.badge.clock.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(live.activity == nil ? L10n.tr("开启实时倒计时") : L10n.tr("结束实时活动"))
                            .font(.subheadline.weight(.semibold))
                        Text(L10n.format("下一班 %@ · %@", String(describing: direction.destination), String(describing: departure.trip.time)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: live.activity == nil ? "play.circle.fill" : "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.orange)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardBackground()
            }
            .buttonStyle(CardPressStyle())
        }
    }
}
