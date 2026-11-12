import Foundation

/// Compact, read-only weekly agenda plus the school's dated schedule exceptions.
struct CourseWidgetSnapshot: Codable {
    static let key = "widget.course.schedule.v1"
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return value
    }

    struct Slot: Codable, Identifiable, Equatable {
        let id: String
        let title: String
        let location: String
        let startMinute: Int
        let endMinute: Int
        var startText: String { Self.clock(startMinute) }
        var timeRange: String { startText + "–" + Self.clock(endMinute) }
        private static func clock(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }
    }

    struct Day: Identifiable {
        let date: Date
        let slots: [Slot]
        var id: Date { date }
        var url: URL { URL(string: "gtiit-beta://timetable?date=" + CourseWidgetSnapshot.key(for: date))! }
    }

    let validFrom: String
    let validUntil: String
    let weekly: [Int: [Slot]]
    let overrides: [String: [Slot]]

    static func key(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    func days(from date: Date, count: Int = 3) -> [Day] {
        let calendar = Self.calendar
        let first = calendar.startOfDay(for: date)
        return (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: first) else { return nil }
            let key = Self.key(for: day)
            let weekday = (calendar.component(.weekday, from: day) + 5) % 7 + 1
            let slots = key >= validFrom && key <= validUntil ? overrides[key] ?? weekly[weekday] ?? [] : []
            return Day(date: day, slots: slots.filter { slot in
                calendar.date(byAdding: .minute, value: slot.endMinute, to: day).map { $0 > date } ?? false
            })
        }
    }

    func timelineDates(from now: Date) -> [Date] {
        let calendar = Self.calendar
        let today = calendar.startOfDay(for: now)
        var dates = Set([now])
        for day in days(from: now) {
            if day.date > now { dates.insert(day.date) }
            for slot in day.slots {
                if let end = calendar.date(byAdding: .minute, value: slot.endMinute, to: day.date), end > now {
                    dates.insert(end)
                }
            }
        }
        if let next = calendar.date(byAdding: .day, value: 3, to: today) { dates.insert(next) }
        return dates.sorted()
    }
}
