import Foundation

/// Read-only presentation snapshot. No credentials or school requests cross targets.
struct StudyWidgetSnapshot: Codable {
    struct Item: Codable, Identifiable {
        let id: String
        let course: String
        let title: String
        let due: Date?
        let pending: Bool
    }
    let items: [Item]
    let updatedAt: Date?
    let verified: Bool
    var days: Int = 10
    static let key = "study.widget.snapshot"
    func pending(at now: Date) -> [Item] {
        items.filter { $0.pending && StudyDeadlineWindow.contains($0.due, now: now, days: days) }.sorted {
            if $0.due == $1.due { return $0.id < $1.id }
            return ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture)
        }
    }
    /// Presentation boundaries can change even when no new network snapshot arrives.
    func timelineDates(from now: Date) -> [Date] {
        let horizon = now.addingTimeInterval(86400)
        var dates = [now]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            dates.append(midnight)
        }
        if let updatedAt { dates.append(updatedAt.addingTimeInterval(6 * 3600)) }
        let window = Double(max(1, min(30, days))) * 86400
        for item in items where item.pending {
            guard let due = item.due else { continue }
            dates.append(contentsOf: [due.addingTimeInterval(-window), due.addingTimeInterval(-86400), due.addingTimeInterval(1)])
        }
        return Array(Set(dates.filter { $0 >= now && $0 <= horizon })).sorted()
    }
    static func courseName(_ raw: String) -> String {
        let name = raw.replacingOccurrences(of: "^\\s*\\d{3,}\\s*[-–—:]?\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s*[-–—(]?\\s*(Winter|Spring|Summer|Fall|Autumn)\\s*\\d{4}\\s*\\)?\\s*$", with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (name == name.uppercased() ? name.capitalized : name)
            .replacingOccurrences(of: "^Introduction To ", with: "", options: [.regularExpression, .caseInsensitive])
    }
    static func compactTitle(_ raw: String) -> String {
        raw.replacingOccurrences(of: "^(Homework [0-9]+) Assignment$", with: "$1", options: .regularExpression)
    }
}

enum StudyDeadlineWindow {
    static func contains(_ due: Date?, now: Date, days: Int) -> Bool {
        guard let due else { return false }
        return due >= now && due <= now.addingTimeInterval(Double(max(1, min(30, days))) * 86400)
    }
}

enum CourseLocationPresentation {
    static func room(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "(?i)(?<![a-z0-9])[a-z]{0,2}[0-9]{3,6}[a-z]?(?![a-z0-9])"
        guard let range = value.range(of: pattern, options: .regularExpression) else { return value }
        return String(value[range]).uppercased()
    }
}

struct ExamWidgetSnapshot: Codable {
    struct Item: Codable, Identifiable {
        let id: String
        let course: String
        let date: Date
        let end: Date
        let venue: String
        let sitting: String?
        var calendarURL: URL {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
            let c = calendar.dateComponents([.year, .month, .day], from: date)
            return URL(string: String(format: "gtiit-beta://calendar?date=%04d-%02d-%02d", c.year!, c.month!, c.day!))!
        }
    }
    let items: [Item]
    let updatedAt: Date?
    static let key = "exams.widget.snapshot"
    func upcoming(at now: Date) -> [Item] { items.filter { $0.end > now }.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date } }
    func timelineDates(from now: Date) -> [Date] {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let midnight = c.date(byAdding: .day, value: 1, to: c.startOfDay(for: now))!
        return Array(Set([now, midnight] + items.flatMap { [$0.date, $0.end] }.filter { $0 > now && $0 < midnight })).sorted()
    }
}
