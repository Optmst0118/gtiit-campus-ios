import EventKit
import Foundation

struct CampusCalendarItem: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let allDay: Bool
    let location: String
    let category: String
    let symbol: String
    let academic: AcademicEvent?
    var dateText: String {
        if allDay {
            let last = CampusDate.calendar.date(byAdding: .day, value: -1, to: end)!
            return last == start ? CampusDate.display(start) : "\(CampusDate.display(start)) – \(CampusDate.display(last))"
        }
        return CampusDate.display(start) + " · " + start.gtiitFormatted(date: .omitted, time: .shortened) + "–" + end.gtiitFormatted(date: .omitted, time: .shortened)
    }
    static func timetable(_ snapshot: TimetableSnapshot, events: [AcademicEvent] = AcademicCalendarStore.events) -> [Self] {
        guard let first = CampusDate.parse(snapshot.validFrom), let last = CampusDate.parse(snapshot.validUntil), first <= last,
              (CampusDate.calendar.dateComponents([.day], from: first, to: last).day ?? 9999) <= 730 else { return [] }
        var result: [Self] = []
        var day = first
        while day <= last {
            for course in snapshot.courses(on: day, events: events) {
                guard let a = LocalCourse.minutes(course.start), let b = LocalCourse.minutes(course.end),
                      let start = CampusDate.calendar.date(byAdding: .minute, value: a, to: day),
                      let end = CampusDate.calendar.date(byAdding: .minute, value: b, to: day) else { continue }
                let identity = [snapshot.semester, course.code, course.group, CampusDate.key(day), course.start, course.end].joined(separator: "|")
                result.append(Self(id: "class:" + identity, title: course.name, start: start, end: end, allDay: false,
                    location: course.location, category: L10n.tr("课表"), symbol: "book", academic: nil))
            }
            guard let next = CampusDate.calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        var seen = Set<String>()
        return result.filter { seen.insert($0.id).inserted }.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }
    static func make(events: [AcademicEvent], exams: [StudentExam]) -> [Self] {
        var items = events.compactMap { event -> Self? in
            guard event.verified, let start = event.startDate,
                  let end = CampusDate.calendar.date(byAdding: .day, value: 1, to: event.endDate ?? start) else { return nil }
            return Self(id: "academic:" + event.id, title: event.title, start: start, end: end, allDay: true,
                location: "", category: event.category, symbol: event.symbol, academic: event)
        }
        items += exams.compactMap { exam -> Self? in
            guard exam.valid, let start = exam.start else { return nil }
            // A missing duration remains a point-in-time appointment, not an invented exam length.
            return Self(id: "exam:" + exam.id, title: exam.course, start: start,
                end: start.addingTimeInterval(exam.duration * 3600), allDay: false, location: exam.venue,
                category: L10n.tr("考试") + " · " + exam.session, symbol: "pencil.and.list.clipboard", academic: nil)
        }
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }
}

@MainActor enum CampusCalendarExport {
    static func save(_ items: [CampusCalendarItem]) async throws -> Int {
        let store = EKEventStore()
        guard try await store.requestFullAccessToEvents() else { throw ExportError.permission }
        let key = "calendar.export.calendarID"
        let calendar: EKCalendar
        if let id = UserDefaults.standard.string(forKey: key), let existing = store.calendar(withIdentifier: id), existing.allowsContentModifications {
            calendar = existing
        } else {
            guard let source = store.defaultCalendarForNewEvents?.source else { throw ExportError.calendar }
            calendar = EKCalendar(for: .event, eventStore: store)
            calendar.title = "GTIIT Beta"
            calendar.source = source
            try store.saveCalendar(calendar, commit: true)
            UserDefaults.standard.set(calendar.calendarIdentifier, forKey: key)
        }
        guard let first = items.map(\.start).min(), let last = items.map(\.end).max() else { return 0 }
        let predicate = store.predicateForEvents(withStart: first.addingTimeInterval(-86400), end: last.addingTimeInterval(86400), calendars: [calendar])
        let existing = store.events(matching: predicate)
        var count = 0
        do {
            for item in items {
                var parts = URLComponents(); parts.scheme = "gtiit-beta"; parts.host = "calendar-event"
                parts.queryItems = [URLQueryItem(name: "id", value: item.id)]
                guard let marker = parts.url else { continue }
                if existing.contains(where: { $0.url == marker }) { continue }
                let event = EKEvent(eventStore: store)
                event.calendar = calendar; event.title = item.title; event.startDate = item.start; event.endDate = item.end
                event.isAllDay = item.allDay; event.timeZone = CampusDate.calendar.timeZone
                event.location = item.location; event.url = marker
                try store.save(event, span: .thisEvent, commit: false)
                count += 1
            }
            try store.commit()
        } catch { store.reset(); throw error }
        return count
    }
    enum ExportError: LocalizedError {
        case permission, calendar
        var errorDescription: String? {
            L10n.tr(self == .permission ? "请在系统设置中允许日历访问后重试。" : "没有可写入的日历，请先在 Apple 日历中添加账户。")
        }
    }
}
