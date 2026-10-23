import SwiftUI

struct MoodleUpcomingEntry: View {
    @Environment(\.locale) private var nativeLocale
    @Environment(\.scenePhase) private var phase
    @EnvironmentObject private var app: AppModel
    @ObservedObject var store: MoodleUpcomingStore
    private var upcoming: [MoodleWork] { store.items.filter { $0.relevant() }.sorted { $0.priority() < $1.priority() } }
    var body: some View {
        let _ = nativeLocale.identifier
        NavigationLink {
            MoodleUpcomingView(store: store)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(L10n.tr("Moodle 临近日程"), systemImage: "checklist").font(.headline)
                    Spacer()
                    if store.refreshing { ProgressView().controlSize(.small) }
                }.foregroundStyle(Theme.accent)
                if let first = upcoming.first {
                    MoodleWorkRow(item: first)
                    if upcoming.count > 1 { Text(L10n.format("另有 %@ 项近期安排", String(upcoming.count - 1))).font(.caption).foregroundStyle(.secondary) }
                } else {
                    Text(L10n.tr(store.loginRequired ? "登录学习页面后自动更新" : store.refreshing ? "正在核对课程与作业…" : store.error ? "更新未完成，点按重试" : store.updatedAt == nil ? "连接 Moodle 后查看近期作业" : "近期没有查到待办作业"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if store.partial { Label(L10n.tr("部分更新，仍有课程未能核对"), systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(Theme.orange) }
            }.padding(.vertical, 8)
                .padding(18).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
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
        store.refresh(browser: app.browser(for: .moodle), allowed: { !app.lock.isLocked && app.lock.isActive && !app.isClearingData })
    }
}

struct MoodleUpcomingView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @ObservedObject var store: MoodleUpcomingStore
    private var upcoming: [MoodleWork] { store.items.filter { $0.relevant() }.sorted { $0.priority() < $1.priority() } }
    var body: some View {
        let _ = nativeLocale.identifier
        List {
            Section {
                if store.refreshing {
                    HStack(spacing: 12) { ProgressView(); Text(L10n.tr("正在逐课程核对作业…")) }
                }
                if store.loginRequired {
                    Button(L10n.tr("前往 Moodle 登录")) { app.switchTo(.moodle) }
                } else if store.error {
                    Label(L10n.tr("更新失败，请确认学习页面已登录后重试。"), systemImage: "exclamationmark.triangle").foregroundStyle(Theme.orange)
                }
                Text(L10n.tr("自动每 30 分钟更新，也可手动刷新。")).font(.caption).foregroundStyle(.secondary)
                if let date = store.updatedAt {
                    LabeledContent(L10n.tr(store.partial ? "部分更新" : "最近更新"), value: date.gtiitFormatted())
                        .font(.caption).foregroundStyle(.secondary)
                    Text(L10n.format("已检查 %@／%@ 门课程的作业列表", String(store.checked), String(store.courses)))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if store.partial {
                    Text(L10n.tr("部分页面未能读取，以下结果可能不完整；可重试并在 Moodle 核对。"))
                        .font(.footnote).foregroundStyle(Theme.orange)
                }
            }
            Section {
                if upcoming.isEmpty && !store.refreshing {
                    ContentUnavailableView(L10n.tr("暂无近期作业"), systemImage: "checkmark.circle", description: Text(L10n.tr("显示未来 7 天截止、最近 2 天开放及明天将开放的安排；已确认提交的作业不列入待办。")))
                }
                ForEach(upcoming) { item in
                    Button { open(item) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.kind == "quiz" ? "pencil.and.list.clipboard" : "doc.text")
                                .foregroundStyle(Theme.accent).frame(width: 24)
                            MoodleWorkRow(item: item)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                        }.padding(.vertical, 6)
                    }.buttonStyle(CardPressStyle())
                }
            } header: { Text(L10n.tr("即将截止与最近开放")) } footer: {
                Text(L10n.tr("结合 Moodle 日历与各课程作业页面。时间为北京时间；未识别的提交状态需在 Moodle 核对，课程临时变更以原页面为准。"))
            }
        }.navigationTitle(L10n.tr("Moodle 临近日程")).navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden).background(Theme.pageBackground)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button { refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(store.refreshing).accessibilityLabel(L10n.tr("更新日程"))
            } }
            .onAppear { if store.updatedAt == nil { refresh() } }
    }
    private func refresh() {
        store.refresh(browser: app.browser(for: .moodle), force: true, allowed: { !app.lock.isLocked && app.lock.isActive && !app.isClearingData })
    }
    private func open(_ item: MoodleWork) {
        guard let url = MoodleWork.safeURL(item.url) else { return }
        app.browser(for: .moodle).load(url); app.switchTo(.moodle)
    }
}
private struct MoodleWorkRow: View {
    @Environment(\.locale) private var nativeLocale
    let item: MoodleWork
    var body: some View {
        let _ = nativeLocale.identifier
        VStack(alignment: .leading, spacing: 5) {
            Text(item.name).font(.headline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            Text(item.course).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            if let date = item.dueDate {
                Label(L10n.format(date < Date() ? "已截止 · %@" : "截止 · %@", dateLabel(date)), systemImage: "clock")
                    .font(.subheadline.weight(.medium)).foregroundStyle(date < Date() ? Color(uiColor: .systemRed) : Theme.accent)
            }
            if let date = item.openedDate {
                Text(L10n.format(date > Date() ? "开放 · %@" : "最近开放 · %@", dateLabel(date))).font(.caption).foregroundStyle(Theme.accent)
            }
            Text(L10n.tr(item.status == "notSubmitted" ? "尚未提交" : item.status == "draft" ? "草稿，尚未正式提交" : item.status == "submitted" ? "已提交" : "请在 Moodle 核对提交状态"))
                .font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }
    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = L10n.locale; f.timeZone = CampusDate.calendar.timeZone
        f.setLocalizedDateFormatFromTemplate("MMM d EEE HH:mm"); return f.string(from: date)
    }
}
