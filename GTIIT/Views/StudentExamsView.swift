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
    @State private var now = Date()
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let date = exam.start {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exam.shortDateLabel).font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit().foregroundStyle(Theme.accent)
                    Text(date, format: .dateTime.weekday(.abbreviated)).font(.caption).foregroundStyle(.secondary)
                }.frame(width: 66, alignment: .leading)
                Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 1, height: 66)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(StudyWidgetSnapshot.courseName(exam.course)).font(.headline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(timeRange).monospacedDigit()
                    if let sitting = exam.sitting { Text(sitting).font(.caption.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 2).background(Theme.accent.opacity(0.12), in: Capsule()) }
                }.font(.subheadline).foregroundStyle(.primary)
                Text(exam.venue.isEmpty ? L10n.tr("地点待定") : exam.venue).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if typeSize.isAccessibilitySize { countdown }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if !typeSize.isAccessibilitySize { countdown }
        }.environment(\.timeZone, CampusDate.calendar.timeZone)
            .accessibilityElement(children: .combine)
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
    }
    private var countdown: some View {
        Group {
            if let days = exam.daysUntil(from: now), days >= 0 {
                Text(L10n.format("%@天", String(days))).font(.headline).monospacedDigit().foregroundStyle(Theme.accent).fixedSize()
            }
        }
    }
    private var timeRange: String {
        guard let start = exam.start else { return exam.time }
        var style = Date.FormatStyle().hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        style.timeZone = CampusDate.calendar.timeZone
        let beginning = start.formatted(style)
        guard exam.duration > 0 else { return beginning }
        let end = start.addingTimeInterval(exam.duration * 3600)
        return beginning + "–" + end.formatted(style)
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
