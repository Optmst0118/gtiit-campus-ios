import Foundation

struct MoodleWork: Codable, Identifiable {
    let url: String
    let name: String
    let course: String
    /// Canonical title for numbered homework while retaining the raw Moodle name in storage.
    var displayName: String {
        guard kind == "assign" || kind == "assignment" || source == "assignment" else { return name }
        let pattern = "^\\s*Homework\\s*#?\\s*(\\d+)(?:\\s+Assignment)?\\s*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
              let range = Range(match.range(at: 1), in: name) else { return name }
        return "Homework (\(name[range])) Assignment"
    }
    var due: TimeInterval?
    var opened: TimeInterval?
    let status: String
    let source: String
    let kind: String
    var checkedAt: TimeInterval? = nil
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
    var active: Bool? = nil
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
        // Prefer an all-numeric course code (e.g. 00350026). Moodle shortnames
        // sometimes contain term slugs such as 2026Winter, which must not be
        // mistaken for a course number.
        let candidates = [shortname ?? "", name]
        for candidate in candidates {
            let parts = candidate.components(separatedBy: CharacterSet.alphanumerics.inverted)
            for part in parts {
                let token = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard token.count >= 3, token.count <= 16,
                      token.allSatisfy({ $0.isNumber }) else { continue }
                if token.count == 4 && token.hasPrefix("20") { continue }
                return token
            }
        }
        for candidate in candidates {
            let parts = candidate.components(separatedBy: CharacterSet.alphanumerics.inverted)
            for part in parts {
                let token = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard token.count >= 3, token.count <= 16,
                      token.rangeOfCharacter(from: .decimalDigits) != nil,
                      token.allSatisfy({ $0.isLetter || $0.isNumber }) else { continue }
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
    let directoryRefreshed: Bool?
}


extension MoodleCourse {
    func matches(_ snapshot: TimetableSnapshot?) -> Bool {
        guard let courses = snapshot?.courses, !courses.isEmpty else { return false }
        func code(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }
        func name(_ s: String) -> String {
            code(s.lowercased().replacingOccurrences(of: "\\b(winter|spring|summer|autumn|fall|20\\d{2})\\b", with: "", options: .regularExpression))
        }
        let codes = Set(courses.map { code($0.code) }.filter { !$0.isEmpty })
        if let number = courseNumber, codes.contains(code(number)) { return true }
        let candidates = [displayName, self.name, shortname ?? ""].map(name).filter { $0.count >= 4 }
        return courses.contains { course in
            let value = name(course.name)
            return !value.isEmpty && candidates.contains { $0 == value || (value.count >= 5 && $0.count >= 5 && ($0.contains(value) || value.contains($0))) }
        }
    }
}
