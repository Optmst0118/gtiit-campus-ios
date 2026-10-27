import CryptoKit
import Foundation
import UserNotifications

/// Only a checked, unsubmitted assignment is eligible. A calendar event alone
/// doesn't establish submission state. No overdue or undated work is scheduled.
enum MoodleReminderLead: Int, CaseIterable, Identifiable {
    case oneDay = 24, twoDays = 48, fiveDays = 120, oneWeek = 168
    var id: Int { rawValue }
    var seconds: TimeInterval { TimeInterval(rawValue) * 3600 }
    var title: String {
        switch self {
        case .oneDay: return L10n.tr("24 小时")
        case .twoDays: return L10n.tr("2 天")
        case .fiveDays: return L10n.tr("5 天")
        case .oneWeek: return L10n.tr("1 周")
        }
    }
}

struct MoodleDeadlinePlan {
    static let prefix = "moodle.deadline."
    let work: MoodleWork
    let deadline: Date
    let fireDate: Date
    let workKey: String
    let identifier: String

    static func key(for url: String) -> String {
        SHA256.hash(data: Data(url.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    init?(_ work: MoodleWork, now: Date, lead: MoodleReminderLead = .oneDay) {
        guard ["notSubmitted", "draft"].contains(work.status),
              MoodleWork.safeURL(work.url) != nil,
              let due = work.due, due.isFinite, due > now.timeIntervalSince1970,
              due <= now.timeIntervalSince1970 + max(7 * 86400, lead.seconds + 86400) else { return nil }
        self.work = work
        deadline = Date(timeIntervalSince1970: due)
        fireDate = max(now.addingTimeInterval(2), deadline.addingTimeInterval(-lead.seconds))
        guard fireDate < deadline else { return nil }
        workKey = Self.key(for: work.url)
        identifier = Self.prefix + Self.key(for: work.url + "|" + String(due))
    }

    func request(now: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = L10n.tr("作业截止提醒")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.isEnglish ? "en_US" : "zh_CN")
        formatter.timeZone = CampusDate.calendar.timeZone
        formatter.dateFormat = "MM/dd HH:mm"
        content.body = L10n.format("%@ · %@\n截止 %@", work.course, work.displayName, formatter.string(from: deadline))
        content.sound = .default
        content.threadIdentifier = "moodle.deadlines"
        content.userInfo = ["moodleURL": work.url, "workKey": workKey, "deadline": deadline.timeIntervalSince1970]
        return UNNotificationRequest(identifier: identifier, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, fireDate.timeIntervalSince(now)), repeats: false))
    }
}

@MainActor protocol MoodleNotificationDelivery {
    func authorization() async -> UNAuthorizationStatus
    func requestAuthorization() async -> Bool
    func pending() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func remove(_ identifiers: [String])
}

@MainActor private struct SystemMoodleNotifications: MoodleNotificationDelivery {
    private let center = UNUserNotificationCenter.current()
    func authorization() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }
    func requestAuthorization() async -> Bool { (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false }
    func pending() async -> [UNNotificationRequest] { await center.pendingNotificationRequests() }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func remove(_ identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

/// Serialized reconciliation keeps a late summary from resurrecting reminders
/// after logout/disable. The protected ledger survives relaunch and records only
/// hashed identifiers and times, not course names, URLs or credentials.
@MainActor final class MoodleDeadlineReminders: ObservableObject {
    static let shared = MoodleDeadlineReminders()
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var failed = false
    private struct Entry: Codable { let workKey: String; let deadline: Date; let fireDate: Date; var leadHours: Int? }
    private var ledger: [String: Entry] = [:]
    private let delivery: any MoodleNotificationDelivery
    private let ledgerURL: URL
    private var task: Task<Void, Never>?

    init(delivery: (any MoodleNotificationDelivery)? = nil, directory: URL? = nil) {
        self.delivery = delivery ?? SystemMoodleNotifications()
        let folder = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MoodleReminders", isDirectory: true)
        ledgerURL = folder.appendingPathComponent("scheduled.json")
        if let data = try? Data(contentsOf: ledgerURL), data.count < 1_000_000,
           let stored = try? JSONDecoder().decode([String: Entry].self, from: data) { ledger = stored }
    }

    func update(items: [MoodleWork], updatedAt: Date?, partial: Bool, enabled: Bool,
                allowPermissionRequest: Bool = false, lead: MoodleReminderLead = .oneDay, now: Date = Date()) {
        let previous = task
        task = Task { [weak self] in
            await previous?.value
            await self?.reconcile(items: items, updatedAt: updatedAt, partial: partial,
                                  enabled: enabled, allowPermissionRequest: allowPermissionRequest, lead: lead, now: now)
        }
    }

    func clear() {
        let previous = task
        task = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            let ids = await delivery.pending().filter { $0.identifier.hasPrefix(MoodleDeadlinePlan.prefix) }.map(\.identifier)
            delivery.remove(Array(Set(ids + Array(ledger.keys))))
            ledger = [:]; persist()
        }
    }
    func waitForUpdates() async { await task?.value }
    func refreshAuthorization() async { authorizationStatus = await delivery.authorization() }
    func requestPermission() async {
        _ = await delivery.requestAuthorization()
        await refreshAuthorization()
    }

    private func reconcile(items: [MoodleWork], updatedAt: Date?, partial: Bool, enabled: Bool,
                           allowPermissionRequest: Bool, lead: MoodleReminderLead, now: Date) async {
        failed = false
        let allPending = await delivery.pending()
        let own = allPending.filter { $0.identifier.hasPrefix(MoodleDeadlinePlan.prefix) }
        if !enabled {
            delivery.remove(Array(Set(own.map(\.identifier) + Array(ledger.keys))))
            return
        }
        guard let updatedAt, updatedAt <= now.addingTimeInterval(60), now.timeIntervalSince(updatedAt) <= 86400 else { return }
        let plans = items.compactMap { MoodleDeadlinePlan($0, now: now, lead: lead) }.sorted { $0.deadline < $1.deadline }
        let byWork = Dictionary(items.map { (MoodleDeadlinePlan.key(for: $0.url), $0) }, uniquingKeysWith: { first, _ in first })
        let valid = Set(plans.map(\.identifier))
        let obsolete = ledger.filter { id, entry in
            if let work = byWork[entry.workKey] {
                return work.isSubmitted || (work.due != nil && work.due != entry.deadline.timeIntervalSince1970)
                    || (work.dueDate.map { $0 <= now } ?? false)
            }
            return !partial
        }.map(\.key)
        delivery.remove(obsolete)
        // A missing item in a partial refresh must not cancel its prior reminder.
        let removed = Set(obsolete)
        let orphaned = own.filter { request in
            guard !valid.contains(request.identifier), !removed.contains(request.identifier) else { return false }
            if let key = request.content.userInfo["workKey"] as? String, let work = byWork[key] {
                return work.isSubmitted || (work.dueDate.map { $0 <= now } ?? false)
            }
            return !partial
        }.map(\.identifier)
        delivery.remove(orphaned)
        ledger = ledger.filter { $0.value.deadline > now.addingTimeInterval(-7 * 86400) }
        persist()
        await refreshAuthorization()
        if authorizationStatus == .notDetermined && allowPermissionRequest && !plans.isEmpty { await requestPermission() }
        guard ShuttleReminderPlan.permits(authorizationStatus) else { return }
        let otherCount = allPending.count - own.count
        let budget = min(32, max(0, 48 - otherCount))
        let pendingIDs = Set(own.map(\.identifier)).subtracting(removed).subtracting(orphaned)
        var scheduled = 0
        var seen = Set<String>()
        for plan in plans where seen.insert(plan.identifier).inserted {
            guard scheduled < budget else { break }
            if let prior = ledger[plan.identifier] {
                // Once due for delivery, a consumed/dismissed request isn't sent again.
                if !pendingIDs.contains(plan.identifier) && prior.fireDate <= now { continue }
                if pendingIDs.contains(plan.identifier) && (prior.leadHours ?? 24) == lead.rawValue { scheduled += 1; continue }
                // Replacing a pending identifier is atomic in Notification Center.
                // Already delivered reminders remain deduplicated above.
            }
            do {
                try await delivery.add(plan.request(now: now))
                ledger[plan.identifier] = Entry(workKey: plan.workKey, deadline: plan.deadline, fireDate: plan.fireDate, leadHours: lead.rawValue)
                scheduled += 1
                persist()
            } catch { failed = true }
        }
    }

    private func persist() {
        do {
            var folder = ledgerURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            try JSONEncoder().encode(ledger).write(to: ledgerURL, options: [.atomic, .completeFileProtection])
        } catch { failed = true }
    }
}
