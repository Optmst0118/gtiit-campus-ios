import SwiftUI

enum CalendarSyncCategory: String, CaseIterable, Identifiable {
    case timetable, holidays, exams
    var id: String { rawValue }
    var title: String {
        switch self {
        case .timetable: return L10n.tr("导出课表到本地日历")
        case .holidays: return L10n.tr("导出假期到本地日历")
        case .exams: return L10n.tr("导出考期到本地日历")
        }
    }
    var symbol: String { self == .timetable ? "book" : self == .holidays ? "sun.max" : "pencil.and.list.clipboard" }
}

struct CalendarSyncSettingsView: View {
    var body: some View {
        List {
            ForEach(CalendarSyncCategory.allCases) { category in
                NavigationLink { CalendarSyncDetailView(category: category) } label: {
                    Label(category.title, systemImage: category.symbol)
                }
            }
        }.nativeDetailSurface(title: L10n.tr("日历同步"))
    }
}

private struct CalendarSyncDetailView: View {
    let category: CalendarSyncCategory
    @EnvironmentObject private var app: AppModel
    @State private var year = AcademicCalendarStore.defaultYear()
    @State private var importing = false
    @State private var busy = false
    @State private var message: String?
    @State private var confirm = false
    @State private var revision = 0
    private var items: [CampusCalendarItem] {
        switch category {
        case .timetable:
            return app.timetable.snapshot.map { CampusCalendarItem.timetable($0) } ?? []
        case .holidays:
            return CampusCalendarItem.make(events: AcademicCalendarStore.holidays(year: year), exams: [])
        case .exams:
            let first = CampusDate.parse(String(year.prefix(4)) + "-07-01")!
            let last = CampusDate.parse(String(year.suffix(4)) + "-07-31")!
            return CampusCalendarItem.make(events: AcademicCalendarStore.events.filter {
                $0.year == year && $0.verified && $0.en.lowercased().contains("exams")
            }, exams: CalendarExamSelection.items(app.exams.items, range: first...last))
        }
    }
    var body: some View {
        let _ = revision
        List {
            Section {
                if category != .timetable {
                    Picker(L10n.tr("学年"), selection: $year) {
                        ForEach(AcademicCalendarStore.years, id: \.self) { Text($0).tag($0) }
                    }
                } else if let snapshot = app.timetable.snapshot {
                    LabeledContent(L10n.tr("学期"), value: snapshot.semester)
                    Text(snapshot.validFrom + " – " + snapshot.validUntil).foregroundStyle(.secondary)
                }
                LabeledContent(L10n.tr("日程数量"), value: String(items.count))
                if category == .timetable {
                    Button(L10n.tr("从门户导入课表")) { importing = true }
                }
                if category == .exams {
                    Button { app.exams.refresh(force: true, allowed: { !app.lock.isLocked && app.lock.isActive && !app.isClearingData }) } label: {
                        HStack { Text(L10n.tr("更新考试安排")); if app.exams.refreshing { Spacer(); ProgressView() } }
                    }.disabled(app.exams.refreshing)
                    if app.exams.loginRequired {
                        Button(L10n.tr("前往 Student 登录")) { app.openSite(.portal) }
                    }
                }
                Button { confirm = true } label: {
                    HStack { Label(L10n.tr("导入 Apple 日历"), systemImage: "calendar.badge.plus"); if busy { Spacer(); ProgressView() } }
                }.disabled(items.isEmpty || busy || (category == .exams && app.exams.refreshing))
            }
            Section(L10n.tr("日程预览")) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.title).font(.headline)
                        Text(item.dateText).font(.caption).foregroundStyle(.secondary)
                        if !item.location.isEmpty { Text(item.location).font(.caption).foregroundStyle(.secondary) }
                    }.padding(.vertical, 3)
                }
            }
        }.nativeDetailSurface(title: category.title)
            .task {
                if category == .exams { app.exams.refresh(allowed: { !app.lock.isLocked && app.lock.isActive && !app.isClearingData }) }
            }
            .sheet(isPresented: $importing) { TimetableImportView(automatic: true) }
            .onReceive(app.timetable.objectWillChange) { _ in revision += 1 }
            .onReceive(app.exams.objectWillChange) { _ in revision += 1 }
            .confirmationDialog(category.title, isPresented: $confirm, titleVisibility: .visible) {
                Button(L10n.tr("导入 Apple 日历")) {
                    let selected = items
                    busy = true
                    Task { @MainActor in
                        defer { busy = false }
                        do { let count = try await CampusCalendarExport.save(selected); message = L10n.format("已导入 %@ 项，已有日程自动跳过。", String(count)) }
                        catch { message = error.localizedDescription }
                    }
                }
            }
            .alert(L10n.tr("Apple 日历"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button(L10n.tr("完成")) { message = nil }
            } message: { Text(message ?? "") }
    }
}
