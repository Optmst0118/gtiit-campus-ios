import SwiftUI

struct StudentExamsEntry: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.scenePhase) private var phase
    @ObservedObject var store: StudentExamStore
    private var groups: [StudentExamKind] { [.midterm, .final] + (store.upcoming.contains { $0.kind == .other } ? [.other] : []) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.tr("临近考试"), systemImage: "pencil.and.list.clipboard").font(.headline)
                Spacer()
                if store.refreshing { ProgressView().controlSize(.small) }
            }.foregroundStyle(Theme.accent)
            ForEach(groups, id: \.self) { kind in
                let exams = store.upcoming.filter { $0.kind == kind }
                NavigationLink { CampusDetailPage(destination: .exams) } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text(kind.title).font(.headline); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
                        if let exam = exams.first { StudentExamRow(exam: exam) }
                        else { Text(L10n.tr(store.loginRequired ? "登录 Student 后查看考试" : "暂无即将举行的考试")).font(.subheadline).foregroundStyle(.secondary) }
                        if exams.count > 1 { Text(L10n.format("另有 %@ 场考试", String(exams.count - 1))).font(.caption).foregroundStyle(.secondary) }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
                }.buttonStyle(CardPressStyle())
            }
        }
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
    private var groups: [StudentExamKind] { [.midterm, .final] + (store.upcoming.contains { $0.kind == .other } ? [.other] : []) }
    var body: some View {
        List {
            if store.loginRequired { Section { Button(L10n.tr("前往 Student 登录")) { app.openSite(.portal) } } }
            else if store.failed { Section { Button(L10n.tr("更新未完成，点按重试")) { refresh() } } }
            ForEach(groups, id: \.self) { kind in
                let exams = store.upcoming.filter { $0.kind == kind }
                Section(kind.title) {
                    if exams.isEmpty { Text(L10n.tr("暂无即将举行的考试")).foregroundStyle(.secondary) }
                    ForEach(exams) { exam in StudentExamRow(exam: exam).padding(.vertical, 6) }
                }
            }
            Section {
                Button(L10n.tr("在 Student 核对")) { app.openSite(.portal) }
            } footer: {
                if let date = store.updatedAt { Text(L10n.tr("最近更新") + " · " + date.gtiitFormatted()).font(.caption) }
            }
        }.nativeDetailSurface(title: L10n.tr("临近考试"))
            .onAppear { refresh() }
            .refreshable { refresh() }
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button { if store.refreshing { store.cancel() } else { refresh() } } label: { Image(systemName: store.refreshing ? "xmark" : "arrow.clockwise") }
                    .accessibilityLabel(L10n.tr(store.refreshing ? "取消更新" : "更新考试安排"))
            } }
    }
    private func refresh() { store.refresh(force: true, allowed: { !app.lock.isLocked && app.lock.isActive && !app.isClearingData }) }
}
struct StudentExamRow: View {
    let exam: StudentExam
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exam.course).font(.headline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            HStack { Text(exam.code); Text(exam.session).fontWeight(.medium) }.font(.caption).foregroundStyle(.secondary)
            if let date = exam.start {
                Label { Text(date, format: .dateTime.month().day().weekday().hour().minute().timeZone(.specificName(.short))).monospacedDigit() } icon: { Image(systemName: "calendar") }.font(.subheadline).foregroundStyle(Theme.accent)
            }
            TimelineView(.periodic(from: .now, by: 60)) { context in
                if let days = exam.daysUntil(from: context.date), days >= 0 {
                    Text(L10n.format("还有 %@ 天", String(days))).font(.subheadline.weight(.medium)).foregroundStyle(Theme.accent)
                }
            }
            Label(exam.venue.isEmpty ? L10n.tr("地点待定") : exam.venue, systemImage: "mappin.and.ellipse").font(.subheadline).foregroundStyle(.secondary)
            if exam.duration > 0 { Text(L10n.format("时长 %@ 小时", String(exam.duration))).font(.caption).foregroundStyle(.secondary) }
        }.environment(\.timeZone, TimeZone(identifier: "Asia/Shanghai")!).accessibilityElement(children: .combine)
    }
}

struct StudentExamProbe: View {
    @ObservedObject var store: StudentExamStore
    var body: some View {
        Group {
            if let web = store.webView {
                CampusSessionProbeHost(webView: web).id(ObjectIdentifier(web))
            }
        }.allowsHitTesting(false).accessibilityHidden(true).opacity(0.01)
    }
}
