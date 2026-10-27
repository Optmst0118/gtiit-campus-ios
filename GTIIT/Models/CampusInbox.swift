import Foundation

struct CachedCampusCourse: Codable, Identifiable, Hashable {
    let code: String
    let name: String
    var semester: String
    var teacher: String
    var location: String
    var credits: String? = nil
    var id: String { [semester, code, name, location].joined(separator: "|") }
}

struct CachedRoomReservation: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let location: String
    let start: Date
    let end: Date
    let url: String
    var valid: Bool {
        !id.isEmpty && id.count <= 200 && !title.isEmpty && title.count <= 1000 && location.count <= 1000
            && start.timeIntervalSince1970.isFinite && end > start && end.timeIntervalSince(start) < 31 * 86400
            && Self.safeURL(url) != nil
    }
    static func safeURL(_ raw: String) -> URL? {
        guard let u = URLComponents(string: raw), u.scheme == "https", u.host == SiteID.rooms.host,
              u.user == nil, u.password == nil, u.port == nil, u.fragment == nil,
              u.path == "/Web/reservation.php", let q = u.queryItems, q.count == 1,
              q[0].name == "rn", let value = q[0].value, !value.isEmpty,
              value.count <= 100, value.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { return nil }
        return u.url
    }
}

enum CampusInboxPolicy {
    static func loginSites(_ states: [SiteID: CampusLoginState], beta: Bool) -> [SiteID] {
        SiteID.allCases.filter { beta || states[$0] == .needsLogin }
    }

    static func assignments(_ items: [MoodleWork], now: Date) -> [MoodleWork] {
        var seen = Set<String>()
        return items.filter {
            guard !$0.isSubmitted, let due = $0.due, due > now.timeIntervalSince1970, due <= now.addingTimeInterval(86400).timeIntervalSince1970,
                  MoodleWork.safeURL($0.url) != nil else { return false }
            return seen.insert($0.url).inserted
        }.sorted { $0.priority() < $1.priority() }
    }
    static func reservations(_ items: [CachedRoomReservation], now: Date) -> [CachedRoomReservation] {
        var seen = Set<String>()
        return items.filter { $0.valid && $0.start >= now && $0.start <= now.addingTimeInterval(21600) && seen.insert($0.id).inserted }
            .sorted { $0.start < $1.start }
    }
}

enum CampusLoginState: String, Codable {
    case checking, signedIn, needsLogin, unavailable, unknown
    var title: String {
        switch self {
        case .checking: return L10n.tr("正在检查登录状态…")
        case .signedIn: return L10n.tr("已登录")
        case .needsLogin: return L10n.tr("需要更新登录状态")
        case .unavailable: return L10n.tr("暂时无法连接")
        case .unknown: return L10n.tr("尚未确认登录状态")
        }
    }
}
