import SwiftUI

struct CampusInboxView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var store: CampusMessageStore
    @State private var expanded: Set<SiteID> = []
    var body: some View {
        let loginGroups = Dictionary(grouping: store.messages.filter { $0.loginSite != nil }, by: \.loginSite)
        List {
            if store.messages.isEmpty { ContentUnavailableView(L10n.tr("通知中心"), systemImage: "bell") }
            ForEach(store.messages) { message in
                if let site = message.loginSite, let group = loginGroups[site] {
                    if group.first?.id == message.id {
                        row(message, group: group.count > 1 ? site : nil)
                        if expanded.contains(site) {
                            ForEach(group.dropFirst()) { row($0, inset: true) }
                        }
                    }
                } else {
                    row(message)
                }
            }
        }.listStyle(.insetGrouped).nativeDetailSurface(title: L10n.tr("通知中心"))
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { Haptics.selection(); store.markAllRead() } label: { Image(systemName: "checkmark") }
                .accessibilityLabel(L10n.tr("全部已读")).disabled(store.unreadCount == 0)
        } }
    }
    private func row(_ message: CampusMessage, group: SiteID? = nil, inset: Bool = false) -> some View {
        HStack(spacing: 10) {
            Button {
                Haptics.light()
                if message.destination != .login { store.markRead(message.id) }
                app.openMessage(message)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: message.symbol).font(.title3).foregroundStyle(Theme.accent).frame(width: 28).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(message.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Spacer(minLength: 8)
                            Text(message.date.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated).locale(L10n.locale)))
                                .font(.caption).foregroundStyle(.secondary).fixedSize()
                        }
                        Text(message.body).font(.subheadline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                    }
                    Circle().fill(Theme.accent).frame(width: 6, height: 6).padding(.top, 6).opacity(message.read ? 0 : 1)
                }.padding(.vertical, 7).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if let group {
                Button {
                    Haptics.selection()
                    withAnimation {
                        if expanded.remove(group) == nil { expanded.insert(group) }
                    }
                } label: {
                    Image(systemName: expanded.contains(group) ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold)).foregroundStyle(Theme.accent)
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel(L10n.tr(expanded.contains(group) ? "收起" : "展开"))
            }
        }.padding(.leading, inset ? 16 : 0)
            .listRowBackground(Theme.cardBackground)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { store.delete(message.id) } label: {
                    Label(L10n.tr("删除"), systemImage: "trash")
                }
            }
    }
}

struct CampusCacheView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var sync: CampusSessionSync
    @ObservedObject var upcoming: MoodleUpcomingStore
    @ObservedObject var exams: StudentExamStore
    var body: some View {
        List {
            Section("Moodle") {
                ForEach(upcoming.courseItems) { course in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.displayName)
                        Text([course.shortname, course.category, course.term].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(Color.secondary)
                    }
                }
                if upcoming.courseItems.isEmpty { Text(L10n.tr("暂无已缓存课程")).foregroundStyle(Color.secondary) }
            }
            Section("Student") {
                ForEach(sync.studentCourses) { course in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.name)
                        Text([course.code, course.semester, course.teacher, course.location].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(Color.secondary)
                    }
                }
                if sync.studentCourses.isEmpty { Text(L10n.tr("暂无已缓存课程")).foregroundStyle(Color.secondary) }
            }
            if !upcoming.upcoming(days: settings.moodleUpcomingRange.rawValue).isEmpty { Section(L10n.tr("临近作业")) {
                ForEach(upcoming.upcoming(days: settings.moodleUpcomingRange.rawValue)) { work in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(work.displayName)
                        Text(work.course).font(.caption).foregroundStyle(Color.secondary)
                        MoodleDeadlineDate(item: work)
                    }
                }
            }
            }
            if !exams.upcoming.isEmpty { Section(L10n.tr("临近考试")) {
                ForEach(exams.upcoming) { exam in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exam.course)
                        Text([exam.code, exam.date, exam.time, exam.venue].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(Color.secondary)
                    }
                }
            }
            }
            Section(L10n.tr("我的预约")) {
                ForEach(sync.reservations.filter { $0.end > Date() }) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                        Text(item.start.gtiitFormatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(Color.secondary)
                    }
                }
                if sync.reservations.filter({ $0.end > Date() }).isEmpty { Text(L10n.tr("暂无已缓存预约")).foregroundStyle(Color.secondary) }
            }
        }.navigationTitle(L10n.tr("本地校园信息")).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
            .scrollContentBackground(.hidden).background(Theme.pageBackground)
    }
}

struct CampusInboxToolbarButton: View {
    @ObservedObject var store: CampusMessageStore
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: store.unreadCount > 0 ? "bell.badge" : "bell") }
            .accessibilityLabel(L10n.tr("通知中心"))
            .accessibilityValue(L10n.format("%@ 条通知", String(store.unreadCount)))
            .accessibilityIdentifier("home.inbox")
    }
}
