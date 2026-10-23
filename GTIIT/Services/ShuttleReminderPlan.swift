import Foundation
import UserNotifications

struct ShuttleReminderPlan {
    let direction: ShuttleDirection
    let departure: ShuttleDeparture
    let leadMinutes: Int
    let fireDate: Date
    var identifier: String { "shuttle.\(direction.rawValue).\(Int(departure.date.timeIntervalSince1970))" }
    init?(direction: ShuttleDirection, departure: ShuttleDeparture, leadMinutes: Int, now: Date) {
        guard [5, 10, 15].contains(leadMinutes) else { return nil }
        let fire = departure.date.addingTimeInterval(-Double(leadMinutes * 60))
        guard fire > now else { return nil }
        self.direction = direction; self.departure = departure; self.leadMinutes = leadMinutes; fireDate = fire
    }
    static func permits(_ status: UNAuthorizationStatus) -> Bool { status == .authorized || status == .provisional }
    var trigger: UNCalendarNotificationTrigger {
        var components = ShuttleSchedule.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        components.calendar = ShuttleSchedule.calendar; components.timeZone = ShuttleSchedule.calendar.timeZone
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}
