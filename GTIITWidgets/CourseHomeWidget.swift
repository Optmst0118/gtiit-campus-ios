import SwiftUI
import WidgetKit

struct CourseHomeEntry: TimelineEntry {
    let date: Date
    let snapshot: CourseWidgetSnapshot?
    let english: Bool
}

struct CourseHomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> CourseHomeEntry {
        let day = CourseWidgetSnapshot.key(for: .now)
        let slot = CourseWidgetSnapshot.Slot(id: "preview", title: "Robotics", location: "SC L-110", startMinute: 540, endMinute: 660)
        return .init(date: CourseWidgetSnapshot.calendar.startOfDay(for: .now),
                     snapshot: .init(validFrom: day, validUntil: day, weekly: [:], overrides: [day: [slot]]), english: false)
    }
    func getSnapshot(in context: Context, completion: @escaping (CourseHomeEntry) -> Void) {
        let entry = read()
        completion(context.isPreview && entry.snapshot == nil ? placeholder(in: context) : entry)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CourseHomeEntry>) -> Void) {
        let entry = read()
        let tomorrow = CourseWidgetSnapshot.calendar.nextDate(after: entry.date, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? entry.date.addingTimeInterval(86400)
        let dates = entry.snapshot?.timelineDates(from: entry.date) ?? [entry.date]
        completion(Timeline(entries: dates.map { .init(date: $0, snapshot: entry.snapshot, english: entry.english) }, policy: entry.snapshot == nil ? .after(tomorrow) : .atEnd))
    }
    private func read() -> CourseHomeEntry {
        let data = AppGroup.isAvailable ? AppGroup.defaults.data(forKey: CourseWidgetSnapshot.key) : nil
        return .init(date: .now, snapshot: data.flatMap { try? JSONDecoder().decode(CourseWidgetSnapshot.self, from: $0) },
                     english: AppGroup.defaults.string(forKey: AppGroup.Key.language) == "en")
    }
}

struct CourseHomeWidget: Widget {
    static let kind = "CourseHomeWidget"
    private var families: [WidgetFamily] {
        if #available(iOS 27.0, *) { return [.systemSmall, .systemMedium, .systemLarge, .systemExtraLargePortrait] }
        return [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
    }
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CourseHomeProvider()) { entry in
            CourseHomeView(entry: entry)
                .containerBackground(WidgetStyle.background, for: .widget)
        }.configurationDisplayName("临近课程").description("按日期查看接下来的课程")
            .supportedFamilies(families)
    }
}

struct CourseHomeView: View {
    @Environment(\.widgetFamily) private var systemFamily
    var familyOverride: WidgetFamily? = nil
    let entry: CourseHomeEntry
    private var family: WidgetFamily { familyOverride ?? systemFamily }
    private var days: [CourseWidgetSnapshot.Day] { entry.snapshot?.days(from: entry.date) ?? [] }
    private var timetableURL: URL { URL(string: "gtiit-beta://timetable")! }
    var body: some View {
        WidgetFrame(title: words("临近课程"), symbol: "calendar.day.timeline.left") {
            if entry.snapshot == nil {
                Text(words("打开 App 导入课表")).font(WidgetStyle.body)
            } else {
                switch family {
                case .systemSmall: compact
                case .systemMedium: medium
                case .systemLarge: agenda(Array(days.prefix(3)), limit: 2)
                case .systemExtraLarge:
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(days) { day in section(day, limit: 5) }
                    }
                default:
                    ViewThatFits(in: .vertical) {
                        agenda(days, limit: 4).fixedSize(horizontal: false, vertical: true)
                        agenda(days, limit: 3).fixedSize(horizontal: false, vertical: true)
                        agenda(days, limit: 2)
                    }
                }
            }
        } footer: {
            if family == .systemSmall, let day = days.first(where: { !$0.slots.isEmpty }) {
                Text(dayLabel(day.date))
            }
        }
        .widgetURL(family == .systemSmall ? days.first(where: { !$0.slots.isEmpty })?.url ?? timetableURL : timetableURL)
        .privacySensitive()
    }

    @ViewBuilder private var compact: some View {
        if let slot = days.lazy.compactMap({ $0.slots.first }).first {
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.startText).font(.system(size: 24, weight: .semibold)).monospacedDigit().foregroundStyle(WidgetStyle.accent)
                Text(slot.title).font(WidgetStyle.body).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                if !slot.location.isEmpty { Text(slot.location).font(WidgetStyle.detail).foregroundStyle(WidgetStyle.secondary).lineLimit(1) }
            }.accessibilityElement(children: .combine)
        } else { Text(words("未来三天暂无课程")).font(WidgetStyle.body) }
    }
    @ViewBuilder private var medium: some View {
        if let first = days.first(where: { !$0.slots.isEmpty }) {
            section(first, limit: 2, tight: true)
        } else { Text(words("未来三天暂无课程")).font(WidgetStyle.body) }
    }
    private func agenda(_ days: [CourseWidgetSnapshot.Day], limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(days) { day in
                if day.id != days.first?.id { Divider() }
                section(day, limit: limit)
            }
        }
    }
    private func section(_ day: CourseWidgetSnapshot.Day, limit: Int, tight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: tight ? 3 : 5) {
            Link(destination: day.url) {
                HStack {
                    Text(dayLabel(day.date)).font(WidgetStyle.body).foregroundStyle(WidgetStyle.accent)
                    Spacer(minLength: 4)
                    if day.slots.count > limit {
                        Text("+\(day.slots.count - limit)").font(WidgetStyle.detail).foregroundStyle(WidgetStyle.secondary)
                    }
                }
            }.accessibilityAddTraits(.isHeader)
            if day.slots.isEmpty {
                Text(words("无课程")).font(WidgetStyle.detail).foregroundStyle(WidgetStyle.secondary)
            }
            ForEach(day.slots.prefix(limit)) { slot in
                Link(destination: day.url) {
                    HStack(alignment: .top, spacing: 7) {
                        Text(slot.timeRange).font(WidgetStyle.detail).monospacedDigit().foregroundStyle(WidgetStyle.secondary)
                            .fixedSize().padding(.top, 2)
                        Rectangle().fill(WidgetStyle.accent).frame(width: 2).clipShape(.capsule)
                            .frame(height: slot.location.isEmpty ? 14 : 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(slot.title).font(WidgetStyle.body).lineLimit(1)
                            if !slot.location.isEmpty {
                                Text(slot.location).font(WidgetStyle.detail).lineLimit(1).foregroundStyle(WidgetStyle.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }.foregroundStyle(.primary).accessibilityElement(children: .combine)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: entry.english ? "en_US" : "zh_CN")
        formatter.timeZone = CourseWidgetSnapshot.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEE")
        return formatter.string(from: date)
    }
    private func words(_ key: String) -> String { WidgetStyle.text(key, english: entry.english) }
}
