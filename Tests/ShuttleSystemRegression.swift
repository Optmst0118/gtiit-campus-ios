import Foundation
import CoreLocation
import UserNotifications

@main struct ShuttleSystemRegression {
    static func main() throws {
        var checks: [String: Bool] = [:]
        func check(_ key: String, _ value: Bool) { checks[key] = value }
        let now = ISO8601DateFormatter().date(from: "2026-10-23T07:59:00+08:00")!
        func fix(_ latitude: Double, _ longitude: Double, accuracy: Double = 30, age: Double = 0) -> CLLocation {
            CLLocation(coordinate: .init(latitude: latitude, longitude: longitude), altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: -1, timestamp: now.addingTimeInterval(-age))
        }
        check("south_recommends_northbound", CampusProximity.direction(for: fix(23.40428,116.63133), now: now) == .southToNorth)
        check("north_recommends_southbound", CampusProximity.direction(for: fix(23.41262,116.63664), now: now) == .northToSouth)
        check("outside_5km_no_recommendation", CampusProximity.direction(for: fix(23.47,116.64), now: now) == nil)
        check("far_away_no_recommendation", CampusProximity.direction(for: fix(31.2,121.5), now: now) == nil)
        check("reduced_accuracy_no_guess", CampusProximity.direction(for: fix(23.40428,116.63133,accuracy:1000), now: now) == nil)
        check("invalid_accuracy_rejected", CampusProximity.direction(for: fix(23.40428,116.63133,accuracy: -1), now: now) == nil)
        check("old_fix_rejected", CampusProximity.direction(for: fix(23.40428,116.63133,age:121), now: now) == nil)
        check("boundary_uncertain_no_guess", CampusProximity.direction(for: fix(23.40845,116.633985,accuracy:150), now: now) == nil)
        let departure = ShuttleSchedule.upcoming(.southToNorth, after: now, teachingWeek: true, limit: 1).first!
        let plan = ShuttleReminderPlan(direction: .southToNorth, departure: departure, leadMinutes: 5, now: now)!
        check("lead_exact", plan.fireDate == departure.date.addingTimeInterval(-300))
        check("past_trigger_rejected", ShuttleReminderPlan(direction: .southToNorth, departure: departure, leadMinutes: 15, now: departure.date.addingTimeInterval(-100)) == nil)
        check("exact_trigger_rejected", ShuttleReminderPlan(direction: .southToNorth, departure: departure, leadMinutes: 5, now: departure.date.addingTimeInterval(-300)) == nil)
        check("invalid_lead_rejected", ShuttleReminderPlan(direction: .southToNorth, departure: departure, leadMinutes: 3, now: now) == nil)
        check("duplicate_identifier_stable", plan.identifier == ShuttleReminderPlan(direction: .southToNorth, departure: departure, leadMinutes: 10, now: now)?.identifier)
        check("campus_timezone_explicit", plan.trigger.dateComponents.timeZone?.identifier == "Asia/Shanghai")
        check("denied_no_schedule", !ShuttleReminderPlan.permits(.denied))
        check("unknown_permission_no_schedule", !ShuttleReminderPlan.permits(.notDetermined))
        check("authorized_schedule", ShuttleReminderPlan.permits(.authorized))
        check("provisional_schedule", ShuttleReminderPlan.permits(.provisional))
        let tomorrow = ShuttleSchedule.upcoming(.southToNorth, after: ISO8601DateFormatter().date(from: "2026-10-23T23:59:59+08:00")!, teachingWeek: true, limit: 1).first!
        check("rollover_daily", tomorrow.trip.bus == 1 && tomorrow.trip.time == "07:25")
        let data = try JSONSerialization.data(withJSONObject: ["passed":checks.values.allSatisfy{$0},"count":checks.count,"checks":checks], options:[.prettyPrinted,.sortedKeys])
        try data.write(to: URL(fileURLWithPath:"docs/verification/shuttle-system-alpha9.json"))
        print("Shuttle system:",checks.count,"passed:",checks.values.allSatisfy{$0},"failed:",checks.filter{!$0.value}.keys)
        if checks.values.contains(false) { exit(1) }
    }
}
