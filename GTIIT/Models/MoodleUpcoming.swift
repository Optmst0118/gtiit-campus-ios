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
struct MoodleCourse: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let shortname: String?
    let category: String?
    let term: String?
    var displayName: String {
        var value = name
        value = value.replacingOccurrences(
            of: "\\s*[-–—(]?\\s*(Winter|Spring|Summer|Fall|Autumn)\\s*\\d{4}\\s*\\)?\\s*$",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        value = value.replacingOccurrences(
            of: "^\\s*\\d{3,}\\s*[-–—]\\s*",
            with: "",
            options: .regularExpression
        )
        return value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–— ")))
    }
    var courseNumber: String? {
        for candidate in [shortname ?? "", name] {
            let parts = candidate.components(separatedBy: CharacterSet.alphanumerics.inverted)
            for part in parts {
                let token = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard token.count >= 3, token.count <= 16,
                      token.rangeOfCharacter(from: .decimalDigits) != nil,
                      token.allSatisfy({ $0.isLetter || $0.isNumber }) else { continue }
                // Do not turn a bare semester year into a course code.
                if token.count == 4 && token.hasPrefix("20") { continue }
                return token
            }
        }
        return nil
    }
    var url: URL? {
        guard id > 0 else { return nil }
        return URL(string: "https://moodle.gtiit.edu.cn/moodle/course/view.php?id=\(id)")
    }
}
struct MoodleUpcomingResult: Decodable {
    let loginRequired: Bool
    let items: [MoodleWork]
    let courses: Int
    let checked: Int
    let failed: Int
    let courseList: [MoodleCourse]?
}
