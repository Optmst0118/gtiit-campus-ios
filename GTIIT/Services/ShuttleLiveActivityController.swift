import ActivityKit
import Foundation

@MainActor
final class ShuttleLiveActivityController: ObservableObject {
    static let shared = ShuttleLiveActivityController()

    @Published private(set) var activity: Activity<ShuttleActivityAttributes>?

    var isSupported: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func start(direction: ShuttleDirection, departure: ShuttleDeparture) async {
        guard isSupported else { return }
        if let activity {
            await activity.end(nil, dismissalPolicy: .immediate)
            self.activity = nil
        }
        let attributes = ShuttleActivityAttributes(
            directionTitle: direction.title,
            origin: direction.origin,
            destination: direction.destination,
            departureTime: departure.trip.time,
            busLabel: L10n.format("%@ 号车", String(departure.trip.bus)),
            departedLabel: L10n.tr("已发车")
        )
        let content = ActivityContent(
            state: ShuttleActivityAttributes.ContentState(
                departureDate: departure.date,
                busNumber: departure.trip.bus
            ),
            staleDate: departure.date
        )
        activity = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    func stop() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
    }
}
