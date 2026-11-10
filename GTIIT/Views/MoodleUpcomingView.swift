import SwiftUI

struct MoodleUpcomingEntry: View {
    @Environment(\.locale) private var nativeLocale
    @Environment(\.scenePhase) private var phase
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var app: AppModel
    @ObservedObject var store: MoodleUpcomingStore
    private var upcoming: [MoodleWork] { store.upcoming(days: settings.moodleUpcomingRange.rawValue) }
    var body: some View {
        let _ = nativeLocale.identifier
        NavigationLink {
            CampusDetailPage(destination: .assignments)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(L10n.tr("临近作业"), systemImage: "checklist").font(.headline)
                    Spacer()
                    if store.refreshing { ProgressView().controlSize(.small) }
                }.foregroundStyle(Theme.accent)
                if let first = upcoming.first {
                    MoodleWorkText(item: first)
                    if upcoming.count > 1 { Text(L10n.format("另有 %@ 项近期安排", String(upcoming.count - 1))).font(.caption).foregroundStyle(.secondary) }
                } else {
                    Text(L10n.tr(store.loginRequired ? "登录学习页面后自动更新" : store.refreshing ? "正在核对课程与作业…" : store.error ? "更新未完成，点按重试" : store.updatedAt == nil ? "连接 Moodle 后查看近期作业" : "近期没有查到待办作业"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if store.partial { Label(L10n.tr("部分更新，仍有课程未能核对"), systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(Theme.orange) }
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
        }.buttonStyle(CardPressStyle())
        .task {
            while !Task.isCancelled {
                refresh()
                do { try await Task.sleep(for: .seconds(MoodleUpcomingStore.refreshInterval)) } catch { return }
            }
        }
        .onChange(of: phase) { _, value in if value != .active { store.cancel() } else { refresh() } }
    }
    private func refresh() {
        app.refreshMoodleSummary(force: false)
    }
}

struct MoodleUpcomingView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var app: AppModel
    @ObservedObject var store: MoodleUpcomingStore
    @State private var now = Date()
    private var upcoming: [MoodleWork] { store.upcoming(now: now, days: settings.moodleUpcomingRange.rawValue) }
    private var opening: [MoodleWork] {
        store.items.filter { !$0.isSubmitted && StudyDeadlineWindow.contains($0.openedDate, now: now, days: settings.moodleUpcomingRange.rawValue) && ($0.openedDate ?? .distantPast) > now }
            .sorted { $0.openedDate! < $1.openedDate! }
    }
    var body: some View {
        let _ = nativeLocale.identifier
        List {
            if store.loginRequired {
                Section { Button(L10n.tr("前往 Moodle 登录")) { app.openWeb(SiteID.moodle.homeURL, site: .moodle, title: L10n.tr("Moodle 登录")) } }
            } else if store.error {
                Section { Button(L10n.tr("更新未完成，点按重试")) { refresh() } }
            }
            Section {
                if upcoming.isEmpty && !store.refreshing {
                    ContentUnavailableView(L10n.tr("暂无近期作业"), systemImage: "checkmark.circle")
                }
                dateGroups(upcoming, opening: false)
            } header: { Text(L10n.tr("即将截止")) } footer: {
                if let date = store.updatedAt { Text(L10n.tr("最近更新") + " · " + date.gtiitFormatted()).font(.caption) }
            }
            Section(L10n.tr("即将开放")) {
                dateGroups(opening, opening: true)
                if opening.isEmpty { Text(L10n.tr("暂无即将开放的作业")).foregroundStyle(.secondary) }
            }
        }.nativeDetailSurface(title: L10n.tr("临近作业"))
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button { if store.refreshing { store.cancel() } else { refresh() } } label: { Image(systemName: store.refreshing ? "xmark" : "arrow.clockwise") }
                    .accessibilityLabel(L10n.tr(store.refreshing ? "取消更新" : "更新日程"))
            } }
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
            .onAppear { app.restoreStudyCaches(); app.refreshMoodleSummary() }
            .refreshable { app.refreshMoodleSummary(force: true) }
    }
    private func dateGroups(_ items: [MoodleWork], opening: Bool) -> some View {
        let groups = Dictionary(grouping: items) { item in
            CampusDate.calendar.startOfDay(for: (opening ? item.openedDate : item.dueDate) ?? .distantPast)
        }
        return ForEach(groups.keys.sorted(), id: \.self) { day in
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day, format: .dateTime.month(.twoDigits).day(.twoDigits)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                    Text(day, format: .dateTime.weekday()).font(.caption).foregroundStyle(.secondary)
                }.frame(width: 66, alignment: .leading)
                VStack(spacing: 0) {
                    Circle().stroke(Theme.accent, lineWidth: 2).frame(width: 8, height: 8)
                    Rectangle().fill(Color.secondary.opacity(0.25)).frame(width: 1).frame(maxHeight: .infinity)
                }.frame(width: 10).padding(.top, 5)
                VStack(spacing: 0) {
                    ForEach(Array((groups[day] ?? []).enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().padding(.vertical, 12) }
                        Button { open(item) } label: { AssignmentTimelineRow(item: item, opening: opening, now: now) }
                            .buttonStyle(.plain)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8).environment(\.timeZone, CampusDate.calendar.timeZone)
        }
    }
    private func refresh() {
        app.refreshMoodleSummary(force: true)
    }
    private func open(_ item: MoodleWork) {
        guard let url = MoodleWork.safeURL(item.url) else { return }
        app.openWeb(url, site: .moodle, title: item.displayName)
    }
}

private struct AssignmentTimelineRow: View {
    let item: MoodleWork
    let opening: Bool
    let now: Date
    @Environment(\.dynamicTypeSize) private var typeSize
    private var color: Color { !opening && item.hasUrgentDeadline(now: now) ? .red : Theme.accent }
    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    details
                    timing.frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    details.frame(maxWidth: .infinity, alignment: .leading)
                    timing.frame(width: 76, alignment: .trailing)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
    private var details: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(StudyWidgetSnapshot.compactTitle(item.displayName)).font(.headline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            Text(StudyWidgetSnapshot.courseName(item.course)).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var timing: some View {
        VStack(alignment: .trailing, spacing: 5) {
            if let date = opening ? item.openedDate : item.dueDate {
                Text(date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(color)
            }
            if !opening { Text(L10n.tr(item.status == "notSubmitted" ? "尚未提交" : item.status == "draft" ? "草稿" : item.status == "submitted" ? "已提交" : "提交状态未知")).font(.caption).foregroundStyle(.secondary) }
        }.multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true)
    }
}
