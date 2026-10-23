import Foundation

/// Departure boundaries are scheduled up front; WidgetKit need not fetch at each bus.
enum ShuttleTimelinePolicy {
    static func dates(after now: Date, teachingWeek: Bool, locationExpiry: Date? = nil) -> [Date] {
        let end = now.addingTimeInterval(24 * 3600)
        let departures = ShuttleDirection.allCases.flatMap {
            ShuttleSchedule.upcoming($0, after: now, teachingWeek: teachingWeek, limit: 64)
        }
        var dates = Set(departures.map { $0.date.addingTimeInterval(1) })
        dates.insert(now)
        if let locationExpiry { dates.insert(locationExpiry) }
        return dates.filter { $0 >= now && $0 < end }.sorted()
    }
}
