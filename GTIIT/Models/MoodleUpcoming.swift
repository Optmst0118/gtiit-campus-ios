import Foundation

struct MoodleWork: Codable, Identifiable {
    let url: String
    let name: String
    let course: String
    var due: TimeInterval?
    var opened: TimeInterval?
    let status: String
    let source: String
    let kind: String
    var id: String { url }
    var isSubmitted: Bool { status == "submitted" }
    var dueDate: Date? { due.map { Date(timeIntervalSince1970: $0) } }
    var openedDate: Date? { opened.map { Date(timeIntervalSince1970: $0) } }
    func relevant(now: Date = Date()) -> Bool {
        guard !isSubmitted, Self.safeURL(url) != nil else { return false }
        let t = now.timeIntervalSince1970
        return due.map { $0 >= t - 86_400 && $0 <= t + 7 * 86_400 } == true
            || opened.map { $0 >= t - 2 * 86_400 && $0 <= t + 86_400 } == true
    }
    func priority(now: Date = Date()) -> TimeInterval {
        due ?? opened ?? .greatestFiniteMagnitude
    }
    static func safeURL(_ value: String) -> URL? {
        guard let u = URLComponents(string: value), u.scheme == "https", u.host == "moodle.gtiit.edu.cn", u.port == nil,
              ["/moodle/mod/assign/view.php", "/moodle/mod/quiz/view.php"].contains(u.path),
              u.user == nil, u.password == nil, u.fragment == nil,
              let query = u.queryItems, query.count == 1, query[0].name == "id",
              let id = query[0].value, !id.isEmpty, id.allSatisfy(\.isNumber), Int(id) != nil else { return nil }
        return u.url
    }
}
struct MoodleUpcomingResult: Decodable {
    let loginRequired: Bool
    let items: [MoodleWork]
    let courses: Int
    let checked: Int
    let failed: Int
}
