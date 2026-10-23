import ActivityKit
import Foundation

/// Shared between the app and the Live Activity widget extension.
struct ShuttleActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var departureDate: Date
        var busNumber: Int
    }

    let directionTitle: String
    let origin: String
    let destination: String
    let departureTime: String
    let busLabel: String
    var directionRaw: String? = nil
    var languageCode: String? = nil
    let departedLabel: String
}
