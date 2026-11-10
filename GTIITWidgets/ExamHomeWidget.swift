import SwiftUI
import WidgetKit

struct ExamHomeEntry: TimelineEntry {
    let date: Date
    let snapshot: ExamWidgetSnapshot?
    let english: Bool
}
struct ExamHomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExamHomeEntry { .init(date: .now, snapshot: nil, english: false) }
    func getSnapshot(in context: Context, completion: @escaping (ExamHomeEntry) -> Void) { completion(read()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ExamHomeEntry>) -> Void) {
        let entry = read()
        completion(Timeline(entries: (entry.snapshot?.timelineDates(from: entry.date) ?? [entry.date]).map {
            ExamHomeEntry(date: $0, snapshot: entry.snapshot, english: entry.english)
        }, policy: .after(entry.date.addingTimeInterval(900))))
    }
    private func read() -> ExamHomeEntry {
        let snapshot = AppGroup.isAvailable ? AppGroup.defaults.data(forKey: ExamWidgetSnapshot.key).flatMap { try? JSONDecoder().decode(ExamWidgetSnapshot.self, from: $0) } : nil
        return .init(date: .now, snapshot: snapshot, english: AppGroup.defaults.string(forKey: AppGroup.Key.language) == "en")
    }
}
struct ExamHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ExamHomeWidget", provider: ExamHomeProvider()) { entry in
            ExamHomeView(entry: entry).containerBackground(WidgetStyle.background, for: .widget)
                .widgetURL(entry.snapshot?.upcoming(at: entry.date).first?.calendarURL ?? URL(string: "gtiit-beta://exams"))
        }.configurationDisplayName("临近考试").description("考试日期、地点与倒计时")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
struct ExamHomeView: View {
    @Environment(\.widgetFamily) private var systemFamily
    var familyOverride: WidgetFamily? = nil
    private var family: WidgetFamily { familyOverride ?? systemFamily }
    let entry: ExamHomeEntry
    private var limit: Int { family == .systemSmall ? 1 : family == .systemMedium ? 2 : 5 }
    private var items: [ExamWidgetSnapshot.Item] { entry.snapshot?.upcoming(at: entry.date) ?? [] }
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Shanghai")!; return c }
    var body: some View {
        WidgetFrame(title: words("临近考试"), symbol: "pencil.and.list.clipboard") {
            if entry.snapshot?.updatedAt == nil { Text(words("打开 App 更新")).font(WidgetStyle.body) }
            else if items.isEmpty { Text(words("暂无即将举行的考试")).font(WidgetStyle.body) }
            else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items.prefix(limit)) { exam in
                        Link(destination: exam.calendarURL) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(alignment: .top) {
                                    Text(StudyWidgetSnapshot.courseName(exam.course)).font(WidgetStyle.body).lineLimit(2)
                                    Spacer(minLength: 4)
                                    Text(WidgetStyle.text("%@天", english: entry.english, String(calendar.dateComponents([.day], from: calendar.startOfDay(for: entry.date), to: calendar.startOfDay(for: exam.date)).day ?? 0))).font(WidgetStyle.detail).foregroundStyle(WidgetStyle.accent)
                                }
                                Text(WidgetStyle.deadline(exam.date, now: entry.date, english: entry.english)).font(WidgetStyle.detail).foregroundStyle(WidgetStyle.accent)
                                Text([exam.sitting.map { words($0) }, exam.venue.isEmpty ? words("地点待定") : exam.venue].compactMap { $0 }.joined(separator: " · ")).font(WidgetStyle.detail).foregroundStyle(WidgetStyle.secondary).lineLimit(1)
                            }.frame(maxWidth: .infinity, alignment: .topLeading).multilineTextAlignment(.leading)
                        }.foregroundStyle(.primary)
                    }
                }
            }
        } footer: { if items.count > limit { Text(WidgetStyle.text("+%@ 场", english: entry.english, String(items.count - limit))) } else { Color.clear } }
    }
    private func words(_ text: String) -> String { WidgetStyle.text(text, english: entry.english) }
}
