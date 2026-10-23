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

    private func registerCategories() {
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
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
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
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return false
        }
        let fireDate = departure.date.addingTimeInterval(-Double(max(1, leadMinutes) * 60))
        guard fireDate > Date() else { return false }

        let content = UNMutableNotificationContent()
        content.title = L10n.tr("班车提醒")
        content.body = L10n.isEnglish
            ? "The \(departure.trip.time) shuttle to \(direction.destination) leaves in \(leadMinutes) minutes."
            : "去\(direction.destination)的 \(departure.trip.time) 班车还有 \(leadMinutes) 分钟发车。"
        content.sound = .default
        content.categoryIdentifier = Self.category
        content.userInfo = [
            "direction": direction.rawValue,
            "departure": departure.date.timeIntervalSince1970,
            "leadMinutes": leadMinutes
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = Self.identifierPrefix + direction.rawValue + "." + String(Int(departure.date.timeIntervalSince1970))
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            await refreshStatus()
            return true
        } catch {
            return false
        }
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
            center.removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
            return
        }
        await MainActor.run {
            ShuttleNotificationCenter.shared.onOpen?(direction)
        }
    }
}
