import Foundation

@main struct ShuttleRegression {
    static func main() throws {
        var checks: [String: Bool] = [:]
        func check(_ name: String, _ result: Bool) { checks[name] = result }
        func date(_ value: String) -> Date {
            let f = ISO8601DateFormatter()
            return f.date(from: value + "+08:00")!
        }
        check("all_58_distinct_trips", ShuttleSchedule.trips.count == 58 && Set(ShuttleSchedule.trips.map(\.id)).count == 58)
        let monday = date("2026-10-19T00:00:00")
        for day in 0...6 {
            let date = ShuttleSchedule.calendar.date(byAdding: .day, value: day, to: monday)!
            let south = ShuttleSchedule.departures(.southToNorth, on: date, teachingWeek: true)
            let north = ShuttleSchedule.departures(.northToSouth, on: date, teachingWeek: true)
            // Independently transcribed red rows for Monday ... Sunday.
            let extraSouth = [2, 3, 3, 5, 5, 0, 0]
            let extraNorth = [2, 3, 5, 7, 5, 0, 0]
            check("south_weekday_\(day)", south.count == 23 + extraSouth[day])
            check("north_weekday_\(day)", north.count == 21 + extraNorth[day])
            check("holiday_south_\(day)", ShuttleSchedule.departures(.southToNorth, on: date, teachingWeek: false).count == 23)
            check("holiday_north_\(day)", ShuttleSchedule.departures(.northToSouth, on: date, teachingWeek: false).count == 21)
        }
        let thursday = date("2026-10-22T10:49:59")
        let duplicate = ShuttleSchedule.upcoming(.southToNorth, after: thursday, teachingWeek: true, limit: 2)
        check("duplicate_time_two_buses", duplicate.count == 2 && duplicate.allSatisfy { $0.trip.time == "10:50" } && Set(duplicate.map { $0.trip.bus }) == [1, 2])
        let boundary = date("2026-10-21T07:35:00")
        check("exact_departure_included", ShuttleSchedule.upcoming(.southToNorth, after: boundary, teachingWeek: true).first?.trip.time == "07:35")
        check("passed_departure_excluded", ShuttleSchedule.upcoming(.southToNorth, after: boundary.addingTimeInterval(1), teachingWeek: true).first?.trip.time == "07:45")
        let late = date("2026-10-23T23:59:59")
        let saturday = ShuttleSchedule.upcoming(.southToNorth, after: late, teachingWeek: true).first!
        check("midnight_rollover_daily_only", saturday.trip.time == "07:25" && saturday.trip.bus == 1 && ShuttleSchedule.dayLabel(saturday.date, relativeTo: late) == "明天")
        check("one_second_countdown", duplicate[0].countdown(from: thursday) == "1 秒")
        check("round_minutes_up", duplicate[0].countdown(from: thursday.addingTimeInterval(-60)) == "2 分钟")
        check("no_negative_countdown", duplicate[0].seconds(from: thursday.addingTimeInterval(100)) == 0)
        let before = date("2026-10-11T08:00:00")
        check("not_before_effective_date", ShuttleSchedule.departures(.northToSouth, on: before, teachingWeek: true).isEmpty)
        check("future_effective_date", ShuttleSchedule.upcoming(.northToSouth, after: before, teachingWeek: true).first!.date >= ShuttleSchedule.effectiveDate)
        check("gate_9_warning_no_invented_reroute", ShuttleSchedule.trips.filter(\.gateClosed).allSatisfy { $0.route.contains("9 号门") })
        check("weekday_extra_1950_not_invented", !ShuttleSchedule.trips.contains { $0.time == "19:50" })
        let output: [String: Any] = ["passed": checks.values.allSatisfy { $0 }, "checks": checks, "count": checks.count]
        let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: "docs/verification/shuttle-results.json"))
        print("Shuttle:", checks.filter { !$0.value }.keys.sorted(), "Passed", checks.values.allSatisfy { $0 }, "Checks", checks.count)
        if checks.values.contains(false) { exit(1) }
    }
}
