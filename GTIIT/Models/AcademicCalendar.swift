import Foundation

/// All dates are source calendar days in Shanghai, with inclusive end dates.
enum CampusDate {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        c.firstWeekday = 2
        return c
    }
    static func parse(_ value: String) -> Date? {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1900...2200).contains(year), (1...12).contains(month), (1...31).contains(day),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let checked = calendar.dateComponents([.year, .month, .day], from: date)
        return checked.year == year && checked.month == month && checked.day == day ? date : nil
    }
    static func key(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    static func display(_ date: Date, weekday: Bool = false) -> String {
        let f = DateFormatter(); f.calendar = calendar; f.locale = L10n.locale
        f.timeZone = calendar.timeZone; f.setLocalizedDateFormatFromTemplate(weekday ? "MMM d EEE" : "yyyy MMM d")
        return f.string(from: date)
    }
}

struct AcademicEvent: Codable, Identifiable {
    let id: String
    let year: String
    let start: String
    let end: String?
    let kind: String
    let zh: String
    let en: String
    let raw: String
    let verified: Bool
    let source: String
    var title: String { L10n.isEnglish ? en : zh }
    var startDate: Date? { CampusDate.parse(start) }
    var endDate: Date? { end.flatMap(CampusDate.parse) }
    var category: String {
        switch kind {
        case "holiday": return L10n.tr("放假")
        case "adjustment": return L10n.tr("调课")
        case "study": return L10n.tr("教学与考试")
        default: return L10n.tr("节日与说明")
        }
    }
    var symbol: String {
        switch kind { case "holiday": return "sun.max"; case "adjustment": return "arrow.triangle.swap"; case "study": return "book"; default: return "info.circle" }
    }
    var dateText: String {
        guard let a = startDate else { return raw }
        guard let b = endDate else { return raw }
        return a == b ? CampusDate.display(a) : "\(CampusDate.display(a)) – \(CampusDate.display(b))"
    }
    func contains(_ date: Date) -> Bool {
        guard verified, let a = startDate, let b = endDate else { return false }
        let day = CampusDate.calendar.startOfDay(for: date)
        return day >= a && day <= b
    }
}

enum AcademicCalendarStore {
    static let years = ["2026-2027", "2025-2026"]
    static let events: [AcademicEvent] = {
        guard let url = Bundle.main.url(forResource: "academic-events", withExtension: "json", subdirectory: "CampusData"),
              let data = try? Data(contentsOf: url), let events = try? JSONDecoder().decode([AcademicEvent].self, from: data) else { return [] }
        return events.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }()
    static func defaultYear(now: Date = Date()) -> String {
        let c = CampusDate.calendar.dateComponents([.year, .month], from: now)
        let first = (c.year ?? 2026) - ((c.month ?? 8) < 8 ? 1 : 0)
        let year = "\(first)-\(first + 1)"
        return years.contains(year) ? year : years[0]
    }
    /// Weekends follow the source calendar; semester gaps exclude exam-end and term-start days.
    static func isDayOff(_ date: Date, year: String) -> Bool {
        CampusDate.calendar.isDateInWeekend(date) || holidays(year: year).contains { $0.contains(date) }
    }
    static func holidays(year: String) -> [AcademicEvent] {
        let explicit = events.filter { $0.year == year && $0.kind == "holiday" && $0.verified }
        let starts = events.filter { $0.verified && ["Summer semester begins", "Winter semester begins", "Spring semester begins"].contains($0.en) }.compactMap(\.startDate).sorted()
        var gaps: [AcademicEvent] = []
        for sourceYear in years {
            for term in ["Summer", "Winter", "Spring"] {
                let exams = events.filter { $0.year == sourceYear && $0.verified && $0.en.hasPrefix(term + " exams") }
                guard let end = exams.compactMap(\.endDate).max(),
                      let a = CampusDate.calendar.date(byAdding: .day, value: 1, to: end) else { continue }
                let next = starts.first { $0 > end }
                // The last published calendar ends in July; do not invent a later term date.
                guard let upper = next.flatMap({ CampusDate.calendar.date(byAdding: .day, value: -1, to: $0) }) ?? CampusDate.parse(String(sourceYear.suffix(4)) + "-07-31"), a <= upper else { continue }
                let lowerBound = CampusDate.parse(String(year.prefix(4)) + "-07-01")!
                let upperBound = CampusDate.parse(String(year.suffix(4)) + "-07-31")!
                let start = max(a, lowerBound), finish = min(upper, upperBound)
                guard start <= finish else { continue }
                gaps.append(AcademicEvent(id: "break-" + sourceYear + "-" + term, year: year,
                    start: CampusDate.key(start), end: CampusDate.key(finish), kind: "holiday",
                    zh: "学期间假期", en: "Semester break", raw: CampusDate.key(start) + " – " + CampusDate.key(finish),
                    verified: true, source: exams.first!.source))
            }
        }
        return (explicit + gaps).sorted { $0.start < $1.start }
    }
    static func pdfURL(year: String) -> URL? {
        guard years.contains(year) else { return nil }
        return Bundle.main.url(forResource: "academic-calendar-\(year)-original", withExtension: "pdf", subdirectory: "CampusData")
    }
}
