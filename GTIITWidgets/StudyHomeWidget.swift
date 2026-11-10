import SwiftUI
import WidgetKit

struct StudyHomeEntry: TimelineEntry {
    let date: Date
    let snapshot: StudyWidgetSnapshot?
    var english = false
}
struct StudyHomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudyHomeEntry { .init(date: .now, snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (StudyHomeEntry) -> Void) { completion(read()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyHomeEntry>) -> Void) {
        let current = read()
        let dates = current.snapshot?.timelineDates(from: current.date) ?? [current.date]
        let entries = Set(dates).sorted().map { StudyHomeEntry(date: $0, snapshot: current.snapshot, english: current.english) }
        completion(Timeline(entries: entries, policy: .after(current.date.addingTimeInterval(900))))
    }
    private func read() -> StudyHomeEntry {
        let snapshot = AppGroup.isAvailable ? AppGroup.defaults.data(forKey: StudyWidgetSnapshot.key).flatMap { try? JSONDecoder().decode(StudyWidgetSnapshot.self, from: $0) } : nil
        let english = AppGroup.defaults.string(forKey: AppGroup.Key.language) == "en"
        return .init(date: .now, snapshot: snapshot, english: english)
    }
}
struct StudyHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StudyHomeWidget", provider: StudyHomeProvider()) { entry in
            StudyHomeView(entry: entry)
                .containerBackground(WidgetStyle.background, for: .widget)
                .widgetURL(URL(string: "gtiit-beta://assignments"))
        }.configurationDisplayName("作业").description("Upcoming assignments")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
struct StudyHomeView: View {
    @Environment(\.widgetFamily) private var systemFamily
    var familyOverride: WidgetFamily? = nil
    private var family: WidgetFamily { familyOverride ?? systemFamily }
    let entry: StudyHomeEntry
    private var limit: Int { family == .systemLarge ? 5 : 2 }
    private var pending: [StudyWidgetSnapshot.Item] { entry.snapshot?.pending(at: entry.date) ?? [] }
    private var verified: Bool {
        entry.snapshot?.verified == true && entry.snapshot?.updatedAt.map { entry.date.timeIntervalSince($0) < 6 * 3600 } == true
    }
    var body: some View {
        WidgetFrame(title: words("临近作业"), symbol: "checklist") {
            if entry.snapshot?.updatedAt != nil {
                if pending.isEmpty {
                    VStack(alignment: .leading, spacing: WidgetStyle.rowGap) {
                        Image(systemName: verified ? "checkmark.circle" : "arrow.clockwise.circle")
                            .font(.title2).foregroundStyle(WidgetStyle.accent)
                        Text(words(verified ? "近期没有待交作业" : "状态待核对")).font(WidgetStyle.body)
                    }.frame(maxHeight: .infinity, alignment: .center)
                } else {
                    VStack(alignment: .leading, spacing: WidgetStyle.rowGap) {
                        ForEach(pending.prefix(limit)) { item in
                            VStack(alignment: .leading, spacing: WidgetStyle.tight) {
                                if family == .systemSmall {
                                    Text(item.course).font(WidgetStyle.course).foregroundStyle(WidgetStyle.secondary).lineLimit(1)
                                    Text(StudyWidgetSnapshot.compactTitle(item.title)).font(WidgetStyle.body).lineLimit(1)
                                    deadline(item)
                                } else {
                                    HStack(alignment: .firstTextBaseline, spacing: WidgetStyle.rowGap) {
                                        Text(item.course).font(WidgetStyle.course).foregroundStyle(WidgetStyle.secondary).lineLimit(1)
                                        Spacer(minLength: 0)
                                        deadline(item).fixedSize()
                                    }
                                    Text(StudyWidgetSnapshot.compactTitle(item.title)).font(WidgetStyle.body).lineLimit(1)
                                }
                            }.frame(maxWidth: .infinity, minHeight: WidgetStyle.taskHeight, maxHeight: WidgetStyle.taskHeight, alignment: .topLeading)
                        }
                    }
                }
            } else {
                Text(words("打开 App 更新")).font(WidgetStyle.body).frame(maxHeight: .infinity, alignment: .center)
            }
        } footer: {
            if pending.count > limit {
                Text(WidgetStyle.text("+%@ 项", english: entry.english, String(pending.count - limit)))
            } else if !verified && !pending.isEmpty { Text(words("状态待核对")) }
            else { Color.clear }
        }
    }
    private func deadline(_ item: StudyWidgetSnapshot.Item) -> some View {
        Text(item.due.map { WidgetStyle.deadline($0, now: entry.date, english: entry.english) } ?? "—")
            .font(WidgetStyle.detail).monospacedDigit().lineLimit(1)
            .foregroundStyle(item.due.map { $0.timeIntervalSince(entry.date) < 86400 } == true ? WidgetStyle.urgent : WidgetStyle.secondary)
    }
    private func words(_ key: String) -> String { WidgetStyle.text(key, english: entry.english) }
}
