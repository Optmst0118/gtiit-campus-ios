import Foundation

struct LocalCourse: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var code: String
    var group: String
    /// ISO weekday: Monday = 1, Sunday = 7.
    var weekday: Int
    var start: String
    var end: String
    var room: String
    var building: String
    var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...7).contains(weekday)
            && Self.minutes(start) != nil && Self.minutes(end) != nil && Self.minutes(start)! < Self.minutes(end)!
    }
    var location: String { [building, room].filter { !$0.isEmpty }.joined(separator: " · ") }
    static func minutes(_ time: String) -> Int? {
        let p = time.split(separator: ":"); guard p.count == 2, p[0].count == 2, p[1].count == 2,
              let h = Int(p[0]), let m = Int(p[1]), (0...23).contains(h), (0...59).contains(m) else { return nil }
        return h * 60 + m
    }
}
struct TimetableSnapshot: Codable {
    var version = 1
    var importedAt = Date()
    var semester: String
    var validFrom: String
    var validUntil: String
    var courses: [LocalCourse]
    func courses(on date: Date, events: [AcademicEvent] = AcademicCalendarStore.events) -> [LocalCourse] {
        let key = CampusDate.key(date)
        guard key >= validFrom && key <= validUntil else { return [] }
        // Only verified explicit holidays suppress classes. Festivals never do.
        if events.contains(where: { $0.kind == "holiday" && $0.contains(date) }) { return [] }
        var weekday = (CampusDate.calendar.component(.weekday, from: date) + 5) % 7 + 1
        let schedules = ["Monday":1, "Tuesday":2, "Wednesday":3, "Thursday":4, "Friday":5]
        for event in events where event.kind == "adjustment" && event.contains(date) {
            if let match = schedules.first(where: { event.en.contains($0.key + " schedule") }) { weekday = match.value }
        }
        return courses.filter { $0.weekday == weekday && $0.valid }.sorted { $0.start == $1.start ? $0.name < $1.name : $0.start < $1.start }
    }
    func next(after date: Date) -> (LocalCourse, Date)? {
        let calendar = CampusDate.calendar
        for offset in 0..<370 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date)), CampusDate.key(day) <= validUntil else { break }
            for course in courses(on: day) {
                guard let minute = LocalCourse.minutes(course.start), let start = calendar.date(byAdding: .minute, value: minute, to: day), start >= date else { continue }
                return (course, start)
            }
        }
        return nil
    }
}

@MainActor final class LocalTimetableStore: ObservableObject {
    @Published private(set) var snapshot: TimetableSnapshot?
    @Published private(set) var loadError: String?
    private let file: URL
    init(directory: URL? = nil) {
        let directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LocalTimetable", isDirectory: true)
        file = directory.appendingPathComponent("timetable-v1.json")
        if FileManager.default.fileExists(atPath: file.path) {
            do {
                let candidate = try JSONDecoder().decode(TimetableSnapshot.self, from: Data(contentsOf: file))
                guard candidate.version == 1, !candidate.courses.isEmpty, candidate.courses.allSatisfy(\.valid), CampusDate.parse(candidate.validFrom) != nil,
                      CampusDate.parse(candidate.validUntil) != nil, candidate.validFrom <= candidate.validUntil else { throw CocoaError(.fileReadCorruptFile) }
                snapshot = candidate
            } catch { loadError = L10n.tr("本地课表无法读取，请重新提取。") }
        }
    }
    func save(_ value: TimetableSnapshot) throws {
        guard value.version == 1, !value.courses.isEmpty, value.courses.count <= 300,
              value.courses.allSatisfy(\.valid), CampusDate.parse(value.validFrom) != nil, CampusDate.parse(value.validUntil) != nil, value.validFrom <= value.validUntil else { throw CocoaError(.fileWriteInvalidFileName) }
        let directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var protected = directory; var flags = URLResourceValues(); flags.isExcludedFromBackup = true
        try protected.setResourceValues(flags)
        try JSONEncoder().encode(value).write(to: file, options: [.atomic, .completeFileProtection])
        snapshot = value; loadError = nil
    }
    func clear() throws {
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        snapshot = nil; loadError = nil
    }
}
