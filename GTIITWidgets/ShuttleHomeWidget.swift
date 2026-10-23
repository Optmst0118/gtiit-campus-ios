import AppIntents
import CoreLocation
import SwiftUI
import WidgetKit

enum WidgetShuttleDirection: String, AppEnum {
    case nearby, southToNorth, northToSouth, both
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Shuttle direction"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .nearby: "Nearby campus", .southToNorth: "South → North",
        .northToSouth: "North → South", .both: "Both directions"
    ]
}
enum WidgetTeachingWeek: String, AppEnum {
    case teaching, holiday
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Service calendar"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .teaching: "Teaching week", .holiday: "Daily buses only"
    ]
}
struct ShuttleWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Shuttle settings"
    @Parameter(title: "Direction", default: .nearby) var direction: WidgetShuttleDirection
    @Parameter(title: "Service calendar", default: .teaching) var service: WidgetTeachingWeek
}
struct ShuttleHomeEntry: TimelineEntry {
    let date: Date
    let suggested: ShuttleDirection?
    let north: ShuttleDeparture?
    let south: ShuttleDeparture?
    var english = false
    var url: URL {
        var components = URLComponents(string: "gtiit://shuttle")!
        if let suggested { components.queryItems = [URLQueryItem(name: "direction", value: suggested.rawValue)] }
        return components.url!
    }
}
struct ShuttleHomeProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ShuttleHomeEntry {
        entry(at: Date(), teaching: true, direction: nil)
    }
    func snapshot(for configuration: ShuttleWidgetConfiguration, in context: Context) async -> ShuttleHomeEntry {
        entry(at: Date(), teaching: teaching(configuration), direction: configuredDirection(configuration))
    }
    func timeline(for configuration: ShuttleWidgetConfiguration, in context: Context) async -> Timeline<ShuttleHomeEntry> {
        let now = Date(), teaching = teaching(configuration)
        let location = configuration.direction == .nearby ? await WidgetLocationFetcher().request() : nil
        let nearby = location.flatMap { CampusProximity.direction(for: $0, now: now) }
        let manual = configuredDirection(configuration)
        let end = now.addingTimeInterval(24 * 3600)
        let entries = ShuttleTimelinePolicy.dates(after: now, teachingWeek: teaching,
            locationExpiry: location?.timestamp.addingTimeInterval(121)).map { date in
            let stillNearby = location.map { date.timeIntervalSince($0.timestamp) <= 120 } ?? false
            return entry(at: date, teaching: teaching, direction: manual ?? (stillNearby ? nearby : nil))
        }
        return Timeline(entries: entries, policy: .after(end))
    }
    private func configuredDirection(_ config: ShuttleWidgetConfiguration) -> ShuttleDirection? {
        switch config.direction {
        case .southToNorth: return .southToNorth
        case .northToSouth: return .northToSouth
        case .nearby, .both: return nil
        }
    }
    private func teaching(_ config: ShuttleWidgetConfiguration) -> Bool {
        switch config.service {
        case .teaching: return true
        case .holiday: return false
        }
    }
    private func entry(at date: Date, teaching: Bool, direction: ShuttleDirection?) -> ShuttleHomeEntry {
        let language = AppGroup.isAvailable ? AppGroup.defaults.string(forKey: AppGroup.Key.language) : nil
        let english = language.map { $0 == "en" } ?? (Locale.current.language.languageCode?.identifier == "en")
        return ShuttleHomeEntry(date: date, suggested: direction,
            north: ShuttleSchedule.upcoming(.southToNorth, after: date, teachingWeek: teaching, limit: 1).first,
            south: ShuttleSchedule.upcoming(.northToSouth, after: date, teachingWeek: teaching, limit: 1).first,
            english: english)
    }
}
@MainActor private final class WidgetLocationFetcher: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var finished = false
    func request() async -> CLLocation? {
        guard manager.isAuthorizedForWidgetUpdates else { return nil }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                self?.finish(nil)
            }
        }
    }
    private func finish(_ location: CLLocation?) {
        guard !finished else { return }
        finished = true
        continuation?.resume(returning: location); continuation = nil
        manager.stopUpdatingLocation()
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { finish(locations.last) }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { finish(nil) }
}
struct ShuttleHomeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ShuttleHomeWidget", intent: ShuttleWidgetConfiguration.self, provider: ShuttleHomeProvider()) { entry in
            ShuttleHomeView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(entry.url)
        }
        .configurationDisplayName("Shuttle next bus")
        .description("Choose your direction and service calendar.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

private struct ShuttleHomeView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ShuttleHomeEntry

    private var english: Bool { entry.english }
    private var primary: ShuttleDeparture? {
        switch entry.suggested {
        case .southToNorth: return entry.north
        case .northToSouth: return entry.south
        case nil: return entry.north
        }
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(inlineText)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(english ? "SHUTTLE" : "班车").font(.caption2.weight(.semibold))
                if primary != nil {
                    Text(inlineText).font(.subheadline.weight(.semibold)).minimumScaleFactor(0.8)
                } else {
                    Text(english ? "No bus" : "暂无班次").font(.headline)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 5) {
                    Image(systemName: "bus.fill").foregroundStyle(.orange)
                    Text(english ? "NEXT SHUTTLE" : "下一班").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                }
                if entry.suggested != nil, let primary {
                    row(primary)
                } else {
                    if let north = entry.north { row(north) }
                    if let south = entry.south { row(south) }
                }
                Spacer(minLength: 0)
            }
            .padding(2)
        }
    }

    private func row(_ departure: ShuttleDeparture) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(directionLabel(departure.trip.direction))
                    .font(.subheadline.weight(.semibold))
                Text(departure.trip.time).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            ShuttleWidgetCountdown(date: departure.date, english: english)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.orange)
        }
    }

    private func directionLabel(_ direction: ShuttleDirection) -> String {
        if direction == .southToNorth { return english ? "To North" : "去北校" }
        return english ? "To South" : "去南校"
    }

    private var inlineText: String {
        guard let primary else { return english ? "Shuttle: no bus" : "班车：暂无班次" }
        if entry.suggested == nil, let north = entry.north, let south = entry.south {
            return english ? "N \(north.trip.time) · S \(south.trip.time)" : "南→北 \(north.trip.time) · 北→南 \(south.trip.time)"
        }
        return "\(directionLabel(primary.trip.direction)) \(primary.trip.time)"
    }
}

private struct ShuttleWidgetCountdown: View {
    let date: Date
    let english: Bool

    var body: some View {
        if date > Date() {
            Text(timerInterval: Date.now...date, countsDown: true, showsHours: false)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        } else {
            Text(english ? "Scheduled time passed" : "计划时间已过")
                .font(.caption)
        }
    }
}
