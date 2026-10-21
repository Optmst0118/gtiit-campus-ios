import Foundation

enum ShuttleDirection: String, CaseIterable, Identifiable {
    case southToNorth, northToSouth
    var id: String { rawValue }
    var title: String { self == .southToNorth ? L10n.tr("南 → 北") : L10n.tr("北 → 南") }
    var origin: String { self == .southToNorth ? L10n.tr("南校区") : L10n.tr("北校区") }
    var destination: String { self == .southToNorth ? L10n.tr("北校区") : L10n.tr("南校区") }
}

struct ShuttleTrip: Identifiable {
    let direction: ShuttleDirection
    let minute: Int
    let bus: Int
    /// Calendar weekday: 1 = Sunday. Empty means daily.
    let weekdays: Set<Int>
    var id: String { "\(direction.rawValue)-\(minute)-\(bus)" }
    var time: String { String(format: "%02d:%02d", minute / 60, minute % 60) }
    var daysLabel: String {
        if weekdays.isEmpty { return L10n.tr("每日") }
        if weekdays == Set(2...6) { return L10n.tr("周一至周五") }
        let names = [2: L10n.tr("一"), 3: L10n.tr("二"), 4: L10n.tr("三"), 5: L10n.tr("四"), 6: L10n.tr("五")]
        if L10n.isEnglish { return weekdays.sorted().compactMap { names[$0] }.joined(separator: ", ") }
        return L10n.tr("周") + weekdays.sorted().compactMap { names[$0] }.joined(separator: "、")
    }
    var serviceLabel: String { bus == 1 ? L10n.tr("1 号 · 每日") : L10n.tr("2 号 · 教学周") }
    var gateClosed: Bool { minute >= 19 * 60 + 30 }
    var route: String {
        switch direction {
        case .southToNorth:
            return L10n.tr("南校区 9 号门 → 2 号门 → 北校区正门")
        case .northToSouth:
            return L10n.tr("北校区正门 → 南校区 2 号门 → 9 号门")
        }
    }
}

struct ShuttleDeparture: Identifiable {
    let trip: ShuttleTrip
    let date: Date
    var id: String { "\(trip.id)-\(date.timeIntervalSince1970)" }
    func seconds(from now: Date) -> Int { max(0, Int(ceil(date.timeIntervalSince(now)))) }
    func countdown(from now: Date) -> String {
        let seconds = seconds(from: now)
        if seconds < 60 { return L10n.format("%@ 秒", String(describing: seconds)) }
        let minutes = Int(ceil(Double(seconds) / 60))
        if minutes < 60 { return L10n.format("%@ 分钟", String(describing: minutes)) }
        return L10n.format("%@ 小时 %@ 分", String(describing: minutes / 60), String(describing: minutes % 60))
    }
}

/// 唯一数据来源：用户提供的 2026-10-12 生效校车表，保留重复时间的独立车次。
/// 没有实时定位或行车时长数据，所有倒计时均为计划发车倒计时。
enum ShuttleSchedule {
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return value
    }
    static let effectiveDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12))!
    static var effectiveLabel: String { L10n.tr("2026.10.12 起生效") }
    static let trips: [ShuttleTrip] = {
        func daily(_ direction: ShuttleDirection, _ times: [String]) -> [ShuttleTrip] {
            times.map { make(direction, $0, 1, []) }
        }
        func make(_ direction: ShuttleDirection, _ time: String, _ bus: Int, _ days: Set<Int>) -> ShuttleTrip {
            let parts = time.split(separator: ":").map { Int($0)! }
            return ShuttleTrip(direction: direction, minute: parts[0] * 60 + parts[1], bus: bus, weekdays: days)
        }
        let south = daily(.southToNorth, [
            "7:25", "7:45", "8:10", "8:30", "9:25", "10:05", "10:50", "11:55", "12:20",
            "13:15", "13:35", "15:15", "15:50", "16:10", "17:25", "18:00", "18:30", "19:00",
            "19:40", "20:20", "21:00", "21:30", "22:10",
        ]) + [
            make(.southToNorth, "7:35", 2, Set(2...6)),
            make(.southToNorth, "9:50", 2, [5, 6]),
            make(.southToNorth, "10:50", 2, [5]),
            make(.southToNorth, "11:45", 2, [3]),
            make(.southToNorth, "12:35", 2, [6]),
            make(.southToNorth, "13:35", 2, Set(2...6)),
            make(.southToNorth, "15:50", 2, [4, 5, 6]),
        ]
        let north = daily(.northToSouth, [
            "7:35", "8:00", "8:20", "8:40", "9:35", "10:20", "11:00", "12:05", "12:30",
            "13:25", "13:45", "15:40", "16:00", "16:45", "17:45", "18:15", "18:45", "19:15",
            "20:00", "20:40", "22:00",
        ]) + [
            make(.northToSouth, "12:30", 2, [4, 5, 6]),
            make(.northToSouth, "13:15", 2, [5, 6]),
            make(.northToSouth, "14:15", 2, [3, 4, 5]),
            make(.northToSouth, "16:15", 2, [2, 5, 6]),
            make(.northToSouth, "18:30", 2, Set(2...6)),
            make(.northToSouth, "19:15", 2, [4, 5, 6]),
            make(.northToSouth, "20:15", 2, [3, 4, 5]),
        ]
        return (south + north).sorted {
            $0.minute == $1.minute ? $0.bus < $1.bus : $0.minute < $1.minute
        }
    }()

    static func departures(_ direction: ShuttleDirection, on day: Date, teachingWeek: Bool) -> [ShuttleDeparture] {
        let start = calendar.startOfDay(for: day)
        guard start >= effectiveDate else { return [] }
        let weekday = calendar.component(.weekday, from: start)
        return trips.filter {
            $0.direction == direction && ($0.bus == 1 || teachingWeek && $0.weekdays.contains(weekday))
        }.compactMap { trip in
            calendar.date(byAdding: .minute, value: trip.minute, to: start).map {
                ShuttleDeparture(trip: trip, date: $0)
            }
        }
    }
    static func upcoming(_ direction: ShuttleDirection, after now: Date, teachingWeek: Bool, limit: Int = 3) -> [ShuttleDeparture] {
        guard limit > 0 else { return [] }
        let base = max(calendar.startOfDay(for: now), effectiveDate)
        var result: [ShuttleDeparture] = []
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: base) else { continue }
            result += departures(direction, on: day, teachingWeek: teachingWeek).filter { $0.date >= now }
            if result.count >= limit { break }
        }
        return Array(result.prefix(limit))
    }
    static func dayLabel(_ date: Date, relativeTo now: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return L10n.tr("今天") }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) { return L10n.tr("明天") }
        let parts = calendar.dateComponents([.month, .day], from: date)
        return L10n.format("%@月%@日", String(describing: parts.month ?? 0), String(describing: parts.day ?? 0))
    }
}
