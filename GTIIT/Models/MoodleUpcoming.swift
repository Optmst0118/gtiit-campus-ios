import Foundation

struct MoodleWork: Codable, Identifiable {
    let url: String
    let name: String
    let course: String
    /// Canonical title for numbered homework while retaining the raw Moodle name in storage.
    var displayName: String {
        guard ["assign", "assignment", "quiz"].contains(kind) || source == "assignment" else { return name }
        guard let number = Self.homeworkNumber(in: name) else { return name }
        return "Homework \(number) Assignment"
    }

    /// All numbered assignment objects, including calendar-generated ones, use
    /// the same title: Homework 2 Assignment. Unnumbered assignments keep the
    /// official name rather than inventing a number.
    private static func homeworkNumber(in value: String) -> String? {
        let lower = value.lowercased()
        for keyword in ["homework", "assignment", "hw"] {
            guard let range = lower.range(of: keyword) else { continue }
            let tail = lower[range.upperBound...]
            for part in tail.components(separatedBy: CharacterSet.decimalDigits.inverted) {
                guard part.count >= 1, part.count <= 3 else { continue }
                return Int(part).map(String.init)
            }
        }
        return nil
    }
    var due: TimeInterval?
    var opened: TimeInterval?
    var status: String
    let source: String
    let kind: String
    var checkedAt: TimeInterval? = nil
    var id: String { url }
    var isSubmitted: Bool { status == "submitted" }
    var dueDate: Date? { due.map { Date(timeIntervalSince1970: $0) } }
    var openedDate: Date? { opened.map { Date(timeIntervalSince1970: $0) } }
    func relevant(now: Date = Date(), days: Int = 10) -> Bool {
        guard !isSubmitted, Self.safeURL(url) != nil else { return false }
        let t = now.timeIntervalSince1970
        if let due { return due >= t - 86_400 && due <= t + Double(max(1, min(30, days))) * 86_400 }
        return opened.map { $0 >= t - 2 * 86_400 && $0 <= t + 86_400 } == true
    }
    func priority(now: Date = Date()) -> TimeInterval {
        due ?? opened ?? .greatestFiniteMagnitude
    }
    static func activityURL(_ url: URL) -> URL? {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let query = parts.queryItems, query.allSatisfy({ $0.name == "id" || ($0.name == "forceview" && $0.value == "1") }),
              query.filter({ $0.name == "id" }).count == 1 else { return nil }
        parts.queryItems = query.filter { $0.name == "id" }; parts.fragment = nil
        return parts.url.flatMap { safeURL($0.absoluteString) }
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

// Separate from the system notification lead time and the inbox's 24-hour window.
enum MoodleUpcomingRange: Int, CaseIterable, Identifiable {
    case three = 3, seven = 7, ten = 10, fourteen = 14, thirty = 30
    var id: Int { rawValue }
    var title: String { L10n.format("未来 %@ 天", String(rawValue)) }
}
