import SwiftUI

struct ShuttleLiveActivityCard: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var live = ShuttleLiveActivityController.shared
    let direction: ShuttleDirection
    let departure: ShuttleDeparture
    var suggested = false
    var body: some View {
        if live.isSupported {
            VStack(alignment: .leading, spacing: 12) {
                if suggested {
                    Label(L10n.format("%@附近", direction.origin), systemImage: "location.fill")
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(direction.title, systemImage: "bus.fill").font(.headline).foregroundStyle(Theme.accent)
                        Text(L10n.format("%@ · %@ 发车", L10n.format("%@ 号车", String(departure.trip.bus)), departure.trip.time))
                            .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button {
                        Task {
                            if matches { await live.stop() }
                            else { settings.favoriteShuttleDirection = direction; await live.start(direction: direction, departure: departure) }
                        }
                    } label: {
                        Image(systemName: matches ? "stop.fill" : "play.fill")
                            .font(.headline).frame(width: 44, height: 44)
                    }.buttonStyle(.bordered).tint(Theme.accent)
                        .accessibilityLabel(matches ? L10n.tr("结束实时活动") : L10n.tr("开启倒计时"))
                }
                if let error = live.errorMessage { Text(error).font(.caption).foregroundStyle(.secondary) }
            }.padding(18).cardBackground()
        }
    }
    private var matches: Bool { live.activity?.attributes.directionRaw == direction.rawValue && live.activity?.content.state.departureDate == departure.date }
}
