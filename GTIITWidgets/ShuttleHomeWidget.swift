import CoreLocation
import SwiftUI
import WidgetKit

struct ShuttleHomeEntry: TimelineEntry {
    let date: Date
    let suggested: ShuttleDirection?
    let north: ShuttleDeparture?
    let south: ShuttleDeparture?
}

struct ShuttleHomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShuttleHomeEntry {
        ShuttleHomeEntry(date: Date(), suggested: nil, north: nil, south: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ShuttleHomeEntry) -> Void) {
        Task { completion(await makeEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShuttleHomeEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(600))))
        }
    }

    private func makeEntry() async -> ShuttleHomeEntry {
        let now = Date()
        let defaults = UserDefaults(suiteName: "group.io.github.optmst0118.gtiit") ?? .standard
        let teaching = defaults.object(forKey: "shuttle.teachingWeek") as? Bool ?? true
        let location = await WidgetLocationFetcher().request()
        let suggested = location.flatMap { CampusProximity.direction(for: $0) }
        let north = ShuttleSchedule.upcoming(.southToNorth, after: now, teachingWeek: teaching, limit: 1).first
        let south = ShuttleSchedule.upcoming(.northToSouth, after: now, teachingWeek: teaching, limit: 1).first
        return ShuttleHomeEntry(date: now, suggested: suggested, north: north, south: south)
    }
}

@MainActor
private final class WidgetLocationFetcher: NSObject, CLLocationManagerDelegate {
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
        continuation?.resume(returning: location)
        continuation = nil
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(nil)
    }
}

struct ShuttleHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShuttleHomeWidget", provider: ShuttleHomeProvider()) { entry in
            ShuttleHomeView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Shuttle next bus")
        .description("Next bus home or back, based on your campus location.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

private struct ShuttleHomeView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ShuttleHomeEntry

    private var english: Bool { Locale.current.language.languageCode?.identifier == "en" }
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
                if let primary {
                    Text("\(directionLabel(primary.trip.direction)) \(primary.trip.time)").font(.headline)
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
            Text(english ? "Due" : "已到")
                .font(.caption)
        }
    }
}
