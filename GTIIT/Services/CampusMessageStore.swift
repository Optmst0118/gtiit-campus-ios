import Foundation
import Combine
import UserNotifications

struct CampusMessage: Codable, Identifiable, Equatable {
    enum Destination: String, Codable { case study, assignments, exams, reservation, login, shuttle }
    let id: String
    let date: Date
    let title: String
    let body: String
    let destination: Destination
    var value: String? = nil
    var read = false
    var symbol: String {
        switch destination {
        case .study, .assignments: return "checklist"
        case .exams: return "pencil.and.list.clipboard"
        case .reservation: return "calendar"
        case .login: return "person.crop.circle.badge.exclamationmark"
        case .shuttle: return "bus"
        }
    }
}

/// Durable event log: producers publish once; the inbox only renders messages.
@MainActor final class CampusMessageStore: ObservableObject {
    @Published private(set) var messages: [CampusMessage] = []
    private let file: URL
    private var subscriptions = Set<AnyCancellable>()
    private var seen: Set<String> = []
    private var signedIn = Set<SiteID>()
    private var expired = Set<SiteID>()
    private struct Archive: Codable { let messages: [CampusMessage]; let seen: Set<String>; var expired: Set<SiteID>? = nil }
    var unreadCount: Int { messages.filter { !$0.read }.count }
    init(directory: URL? = nil) {
        file = (directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CampusMessages")).appendingPathComponent("events.json")
        if let archive = ProtectedCampusCache.read(Archive.self, from: file, maxBytes: 2_000_000) {
            messages = Array(archive.messages.prefix(200)); seen = archive.seen; expired = archive.expired ?? []
        }
    }
    func connect(sync: CampusSessionSync) {
        sync.$states.sink { [weak self] in self?.recordLogin($0) }.store(in: &subscriptions)
        sync.$reservations.sink { [weak self] in self?.recordReservations($0, now: Date()) }.store(in: &subscriptions)
    }
    func append(_ message: CampusMessage) {
        guard !seen.contains(message.id) else { return }
        seen.insert(message.id)
        messages = Array((messages + [message]).sorted { $0.date == $1.date ? $0.id < $1.id : $0.date > $1.date }.prefix(200))
        persist()
    }
    func markRead(_ id: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }), !messages[index].read else { return }
        messages[index].read = true; persist()
    }
    func markAllRead() {
        guard unreadCount > 0 else { return }
        messages = messages.map { var item = $0; item.read = true; return item }; persist()
    }
    func recordLogin(_ states: [SiteID: CampusLoginState], now: Date = Date()) {
        for (site, state) in states {
            if state == .signedIn {
                signedIn.insert(site)
                if expired.remove(site) != nil { persist() }
            }
            if state == .needsLogin, (signedIn.contains(site) || UserDefaults.standard.bool(forKey: "campus.session.wasSignedIn.\(site.rawValue)")), expired.insert(site).inserted {
                append(CampusMessage(id: "login.\(site.rawValue).\(UUID().uuidString)", date: now,
                    title: site.displayName, body: L10n.tr("需要更新登录状态"), destination: .login, value: site.rawValue))
            }
        }
    }
    func recordReservations(_ items: [CachedRoomReservation], now: Date) {
        for item in CampusInboxPolicy.reservations(items, now: now) {
            append(CampusMessage(id: "reservation.\(item.id).\(Int(item.start.timeIntervalSince1970))", date: now,
                title: L10n.tr("我的预约"), body: [item.title, item.start.gtiitFormatted(date: .abbreviated, time: .shortened)].joined(separator: " · "),
                destination: .reservation, value: item.url))
        }
    }
    func recordStudy(works: [MoodleWork], exams: [StudentExam], days: Int, hour: Int, now: Date = Date()) {
        guard let plan = StudyDailyPlan.make(works: works, exams: exams, days: days, hour: hour,
            now: now, includePastToday: true, horizonDays: 0).first, plan.date <= now else { return }
        append(CampusMessage(id: "study.daily." + String(Int(plan.date.timeIntervalSince1970)), date: plan.date,
            title: L10n.tr("作业与考试提醒"), body: plan.lines.prefix(12).joined(separator: "\n"), destination: plan.containsAssignments ? .study : .exams))
    }
    func ingest(_ notification: UNNotification) {
        let request = notification.request
        let destination: CampusMessage.Destination
        var value: String?
        if request.identifier.hasPrefix("study.daily.") { destination = request.content.userInfo["studyDestination"] as? String == "exams" ? .exams : .study }
        else if request.identifier.hasPrefix(MoodleDeadlinePlan.prefix) {
            destination = .assignments; value = request.content.userInfo["moodleURL"] as? String
        } else if request.identifier.hasPrefix("shuttle.") {
            destination = .shuttle; value = request.content.userInfo["direction"] as? String
        } else { return }
        append(CampusMessage(id: request.identifier, date: notification.date, title: request.content.title,
            body: request.content.body, destination: destination, value: value))
    }
    func clear() {
        messages = []; seen = []; signedIn = []; expired = []; persist()
    }
    private func persist() {
        if seen.count > 2000 { seen = Set(messages.map(\.id)) }
        try? ProtectedCampusCache.write(Archive(messages: messages, seen: seen, expired: expired), to: file)
    }
}
