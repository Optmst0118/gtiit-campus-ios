import SwiftUI

struct StudentExamsEntry: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.scenePhase) private var phase
    @Environment(\.locale) private var locale
    @ObservedObject var store: StudentExamStore
    var body: some View {
        NavigationLink { StudentExamsView(store: store) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(L10n.tr("临近考试"), systemImage: "pencil.and.list.clipboard").font(.headline)
                    Spacer()
                    if store.refreshing { ProgressView().controlSize(.small) }
                }.foregroundStyle(Theme.accent)
                if let exam = store.upcoming.first {
                    if let start = exam.start, start.timeIntervalSinceNow <= 14 * 86400 { StudentExamRow(exam: exam) }
                    else {
                        HStack(alignment: .firstTextBaseline) {
                            Text(exam.course).font(.subheadline).lineLimit(1)
                            Spacer()
                            Text(exam.start ?? .now, format: .dateTime.month().day()).font(.caption).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
                else { Text(L10n.tr(store.loginRequired ? "登录 Student 后查看考试" : store.refreshing ? "正在核对考试安排…" : store.failed ? "更新未完成，点按重试" : store.updatedAt == nil ? "连接 Student 后查看考试安排" : "暂无即将举行的考试")).font(.subheadline).foregroundStyle(.secondary) }
                if store.upcoming.count > 1 { Text(L10n.format("另有 %@ 场考试", String(store.upcoming.count - 1))).font(.caption).foregroundStyle(.secondary) }
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
        }.buttonStyle(CardPressStyle())
        .task {
            while !Task.isCancelled {
                refresh()
                do { try await Task.sleep(for: .seconds(StudentExamStore.refreshInterval)) } catch { return }
            }
        }
        .onChange(of: phase) { _, value in if value == .active { refresh() } else { store.cancel() } }
    }
    private func refresh() { store.refresh(allowed: { !app.lock.isLocked && app.lock.isActive && !app.isClearingData }) }
}
struct StudentExamsView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var store: StudentExamStore
    var body: some View {
        List {
            Section {
                if store.refreshing && store.upcoming.isEmpty {
                    HStack { ProgressView(); Text(L10n.tr("正在核对考试安排…")) }
                }
                if store.loginRequired {
                    Button(L10n.tr("前往 Student 登录")) { app.openSite(.portal) }
                } else if store.failed {
                    Button(L10n.tr("更新未完成，点按重试")) { refresh() }
                } else if store.upcoming.isEmpty && !store.refreshing {
                    ContentUnavailableView(L10n.tr("暂无即将举行的考试"), systemImage: "calendar.badge.checkmark")
                }
                ForEach(store.upcoming) { exam in StudentExamRow(exam: exam).padding(.vertical, 6) }
            } header: { Text(L10n.tr("考试安排")) } footer: {
                if let date = store.updatedAt {
                    Text(L10n.tr("最近更新") + " · " + date.gtiitFormatted()).font(.caption)
                }
            }
            Button(L10n.tr("在 Student 核对")) { app.switchTo(.portal); app.browser(for: .portal).loadHome() }
        }.navigationTitle(L10n.tr("临近考试")).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
            .scrollContentBackground(.hidden).background(Theme.pageBackground)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { refresh() } label: { Image(systemName: "arrow.clockwise") }.disabled(store.refreshing).accessibilityLabel(L10n.tr("更新考试安排")) } }
    }
    private func refresh() {
        store.refresh(force: true, allowed: { !app.lock.isLocked && app.lock.isActive && !app.isClearingData })
    }
}
private struct StudentExamRow: View {
    let exam: StudentExam
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exam.course).font(.headline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            HStack { Text(exam.code); Text(exam.session).fontWeight(.medium) }.font(.caption).foregroundStyle(.secondary)
            if let date = exam.start {
                Label { Text(date, format: .dateTime.month().day().weekday().hour().minute().timeZone(.specificName(.short))).monospacedDigit() } icon: { Image(systemName: "calendar") }.font(.subheadline).foregroundStyle(Theme.accent)
            }
            Label(exam.venue.isEmpty ? L10n.tr("地点待定") : exam.venue, systemImage: "mappin.and.ellipse").font(.subheadline).foregroundStyle(.secondary)
            if exam.duration > 0 { Text(L10n.format("时长 %@ 小时", String(exam.duration))).font(.caption).foregroundStyle(.secondary) }
        }.environment(\.timeZone, TimeZone(identifier: "Asia/Shanghai")!).accessibilityElement(children: .combine)
    }
}
