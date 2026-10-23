import CoreLocation
import Foundation

/// WGS84 campus centroids: OpenStreetMap ways 536680356 / 1313755916.
/// Raw location stays in memory and is never shared with extensions or saved.
enum CampusProximity {
    static let north = CLLocation(latitude: 23.41262, longitude: 116.63664)
    static let south = CLLocation(latitude: 23.40428, longitude: 116.63133)
    static func direction(for location: CLLocation, now: Date = Date()) -> ShuttleDirection? {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 300,
              abs(location.timestamp.timeIntervalSince(now)) <= 120 else { return nil }
        let n = location.distance(from: north), s = location.distance(from: south)
        guard min(n, s) <= 5000, abs(n - s) > max(100, location.horizontalAccuracy * 2) else { return nil }
        return s < n ? .southToNorth : .northToSouth
    }
}

@MainActor final class CampusLocationRecommendation: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private var resolvedDirection: ShuttleDirection?
    private var fixDate: Date?
    var direction: ShuttleDirection? {
        guard let fixDate, abs(fixDate.timeIntervalSinceNow) <= 120 else { return nil }
        return resolvedDirection
    }
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private let manager = CLLocationManager()
    private var visible = false
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        authorization = manager.authorizationStatus
    }
    func activate(requestPermission: Bool = false) {
        visible = true
        authorization = manager.authorizationStatus
        if authorization == .notDetermined && requestPermission { manager.requestWhenInUseAuthorization() }
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways { manager.startUpdatingLocation() }
    }
    func deactivate() { visible = false; manager.stopUpdatingLocation(); resolvedDirection = nil }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if visible { activate() }
        if authorization != .authorizedWhenInUse && authorization != .authorizedAlways { resolvedDirection = nil }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard visible else { return }
        fixDate = locations.last?.timestamp
        resolvedDirection = locations.last.flatMap { CampusProximity.direction(for: $0) }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { resolvedDirection = nil }
}
