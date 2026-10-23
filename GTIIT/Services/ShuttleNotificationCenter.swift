import Foundation
import UserNotifications

/// Local-only shuttle reminders. No server, no remote push.
@MainActor
final class ShuttleNotificationCenter: NSObject, ObservableObject {
    static let shared = ShuttleNotificationCenter()

    private static let category = "SHUTTLE_DEPARTURE"
    private static let openAction = "SHUTTLE_OPEN"
    private static let cancelAction = "SHUTTLE_CANCEL"
    private static let identifierPrefix = "shuttle."

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var pendingCount = 0
    /// Set by AppModel to route a notification tap into the Shuttle tab.
    var onOpen: ((ShuttleDirection?) -> Void)?

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
        registerCategories()
        Task { await refreshStatus() }
    }

    func registerCategories() {
        let open = UNNotificationAction(
            identifier: Self.openAction,
            title: L10n.tr("查看时刻表"),
            options: [.foreground]
        )
        let cancel = UNNotificationAction(
            identifier: Self.cancelAction,
            title: L10n.tr("取消提醒"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.category,
            actions: [open, cancel],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        let requests = await center.pendingNotificationRequests()
        pendingCount = requests.filter { $0.identifier.hasPrefix(Self.identifierPrefix) }.count
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            await refreshStatus()
            return granted
        } catch {
            await refreshStatus()
            return false
        }
    }

    @discardableResult
    func scheduleReminder(
        direction: ShuttleDirection,
        departure: ShuttleDeparture,
        leadMinutes: Int
    ) async -> Bool {
        let settings = await center.notificationSettings()
        guard ShuttleReminderPlan.permits(settings.authorizationStatus) else {
            return false
        }
        guard let plan = ShuttleReminderPlan(direction: direction, departure: departure, leadMinutes: leadMinutes, now: Date()) else { return false }
        let pending = await center.pendingNotificationRequests()
        guard pending.count < 48 || pending.contains(where: { $0.identifier == plan.identifier }) else { return false }
        let content = makeContent(direction: direction, departure: departure.date, time: departure.trip.time,
                                  bus: departure.trip.bus, lead: leadMinutes)
        let request = UNNotificationRequest(identifier: plan.identifier, content: content, trigger: plan.trigger)
        do {
            try await center.add(request)
            await refreshStatus()
            return true
        } catch {
            return false
        }
    }

    private func makeContent(direction: ShuttleDirection, departure: Date, time: String, bus: Int, lead: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = L10n.tr("班车提醒")
        content.body = UserDefaults.standard.bool(forKey: "settings.privateShuttleReminders")
            ? L10n.tr("该出发了")
            : L10n.format("%@ · %@ 发车", direction.title, time)
        content.sound = .default; content.categoryIdentifier = Self.category
        content.userInfo = ["direction": direction.rawValue, "departure": departure.timeIntervalSince1970, "leadMinutes": lead, "bus": bus]
        return content
    }
    func reconcile(teachingWeek: Bool) async {
        registerCategories()
        for request in await center.pendingNotificationRequests() where request.identifier.hasPrefix(Self.identifierPrefix) {
            let info = request.content.userInfo
            guard let raw = info["direction"] as? String, let direction = ShuttleDirection(rawValue: raw),
                  let seconds = info["departure"] as? Double, let lead = info["leadMinutes"] as? Int else {
                center.removePendingNotificationRequests(withIdentifiers: [request.identifier]); continue
            }
            let date = Date(timeIntervalSince1970: seconds), bus = info["bus"] as? Int
            guard let departure = ShuttleSchedule.departures(direction, on: date, teachingWeek: teachingWeek)
                .first(where: { $0.date == date && (bus == nil || $0.trip.bus == bus) }),
                  let plan = ShuttleReminderPlan(direction: direction, departure: departure, leadMinutes: lead, now: Date()) else {
                center.removePendingNotificationRequests(withIdentifiers: [request.identifier]); continue
            }
            let content = makeContent(direction: direction, departure: date, time: departure.trip.time, bus: departure.trip.bus, lead: lead)
            try? await center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: plan.trigger))
        }
        await refreshStatus()
    }
    func cancelReminder(for departure: ShuttleDeparture, direction: ShuttleDirection) {
        let identifier = Self.identifierPrefix + direction.rawValue + "." + String(Int(departure.date.timeIntervalSince1970))
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        Task { await refreshStatus() }
    }

    func cancelAllShuttleReminders() {
        Task {
            let requests = await center.pendingNotificationRequests()
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            await refreshStatus()
        }
    }
}

extension ShuttleNotificationCenter: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let direction = (userInfo["direction"] as? String).flatMap(ShuttleDirection.init(rawValue:))
        if response.actionIdentifier == "SHUTTLE_CANCEL" {
            center.removePendingNotificationRequests(withIdentifiers: [response.notification.request.identifier])
            center.removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
            return
        }
        await MainActor.run {
            ShuttleNotificationCenter.shared.onOpen?(direction)
        }
    }
}
