import SwiftUI

/// Native Moodle home: a clear dashboard around the official course workspace.
/// Content and submission stay on the official Moodle pages.
struct MoodleTabView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @State private var official: MoodleDestination?

    var body: some View {
        let _ = nativeLocale.identifier
        Group {
            if settings.nativeMoodleEnabled {
                native
            } else {
                SiteBrowserView(site: .moodle)
            }
        }
        .sheet(item: $official, onDismiss: { refresh() }) { destination in
            MoodleOfficialSheet(destination: destination)
                .environmentObject(app)
        }
        .onAppear { consumePendingURL() }
        .onChange(of: app.pendingMoodleURL) { _, _ in consumePendingURL() }
    }

    private var native: some View {
        NavigationStack {
            MoodleHomeView(store: app.upcoming, open: open)
                .navigationTitle("Moodle")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { refresh() } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel(L10n.tr("刷新 Moodle"))
                    }
                }
        }
    }

    private func open(_ destination: MoodleDestination) {
        official = destination
    }

    private func refresh() {
        app.upcoming.refresh(browser: app.browser(for: .moodle), force: true) {
            !app.lock.isLocked && app.lock.isActive && !app.isClearingData
        }
    }

    private func consumePendingURL() {
        guard let url = app.pendingMoodleURL else { return }
        app.pendingMoodleURL = nil
        official = MoodleDestination(title: "Moodle", url: url)
    }
}

struct MoodleDestination: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
}

struct MoodleHomeView: View {
    @Environment(\.locale) private var nativeLocale
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var app: AppModel
    @ObservedObject var store: MoodleUpcomingStore
    let open: (MoodleDestination) -> Void

    private var upcoming: [MoodleWork] {
        store.items.filter { $0.relevant() }.sorted { $0.priority() < $1.priority() }
    }

    private var columns: [GridItem] {
        horizontalSizeClass == .regular
            ? [GridItem(.adaptive(minimum: 280), spacing: 16)]
            : [GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                stats
                dashboard
                courses
                tools
                footer
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 20)
            .padding(.top, 8)
            .padding(.bottom, 30)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.pageBackground)
        .task { refreshIfNeeded() }
        .onChange(of: app.lock.isLocked) { _, locked in if !locked { refreshIfNeeded() } }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 58, height: 58)
                    .background(Theme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Spacer(minLength: 8)
                AlphaBadge()
            }
            Text(L10n.tr("课程学习"))
                .font(.caption.weight(.semibold)).tracking(1.4).foregroundStyle(Theme.accent)
            Text(L10n.tr("你的 Moodle 工作台"))
                .font(.title2.weight(.bold))
            Text(L10n.tr("课程、作业、测验、日历与消息集中在这里；打开官方页面继续学习。"))
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Theme.accent.opacity(0.17), Theme.accent.opacity(0.035)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.12))
        }
    }

    private var stats: some View {
        LazyVGrid(columns: horizontalSizeClass == .regular ? [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(value: upcoming.count, label: L10n.tr("近期事项"), symbol: "checklist", tint: Theme.accent)
            statCard(value: store.courses, label: L10n.tr("已核对课程"), symbol: "book.closed", tint: Theme.orange)
            statCard(value: store.partial ? 1 : 0, label: L10n.tr("部分更新"), symbol: "exclamationmark.circle", tint: store.partial ? Theme.orange : .secondary)
        }
    }

    private func statCard(value: Int, label: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tint).font(.headline)
            VStack(alignment: .leading, spacing: 1) {
                Text(String(value)).font(.title3.monospacedDigit().weight(.semibold))
                Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(corner: 16)
    }

    // MARK: Dashboard

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L10n.tr("临近日程"), symbol: "calendar.day.timeline.left")
            if store.refreshing && store.updatedAt == nil {
                HStack(spacing: 10) { ProgressView(); Text(L10n.tr("正在刷新课程与作业…")).font(.subheadline).foregroundStyle(.secondary) }
                    .padding(16).cardBackground()
            } else if upcoming.isEmpty {
                emptyUpcoming
            } else {
                VStack(spacing: 8) {
                    ForEach(upcoming.prefix(5)) { item in
                        Button { open(MoodleDestination(title: item.name, url: URL(string: item.url)!)) } label: {
                            MoodleWorkRowNative(item: item)
                        }.buttonStyle(CardPressStyle())
                    }
                    if upcoming.count > 5 {
                        Button { open(MoodleDestination(title: L10n.tr("Moodle 临近日程"), url: URL(string: "https://moodle.gtiit.edu.cn/moodle/calendar/view.php?view=upcoming")!)) } label: {
                            Label(L10n.format("查看全部 %@ 项", String(upcoming.count)), systemImage: "arrow.up.right")
                                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                        }.foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    private var emptyUpcoming: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(store.loginRequired ? L10n.tr("需要登录 Moodle") : L10n.tr("暂无近期事项"), systemImage: store.loginRequired ? "person.crop.circle.badge.exclamationmark" : "checkmark.circle")
                .font(.headline).foregroundStyle(store.loginRequired ? Theme.orange : Theme.accent)
            Text(store.loginRequired ? L10n.tr("打开官方 Moodle 完成登录，返回后这里会自动更新。") : L10n.tr("连接 Moodle 后查看近期作业与测验。"))
                .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button { open(MoodleDestination(title: L10n.tr("Moodle 登录"), url: URL(string: "https://moodle.gtiit.edu.cn/moodle/my/")!)) } label: {
                Label(store.loginRequired ? L10n.tr("打开 Moodle 登录") : L10n.tr("打开 Moodle"), systemImage: "arrow.up.right")
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            }.foregroundStyle(Theme.accent)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    // MARK: Courses

    private var courses: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L10n.tr("课程"), symbol: "book.closed")
            if courseGroups.isEmpty {
                Text(L10n.tr("登录后可查看课程与活动。"))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(16).cardBackground()
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(courseGroups) { group in
                        Button { open(MoodleDestination(title: group.name, url: URL(string: "https://moodle.gtiit.edu.cn/moodle/my/")!)) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "book.closed.fill").foregroundStyle(Theme.accent)
                                    .frame(width: 38, height: 38).background(Theme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(group.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(2)
                                    Text(L10n.format("%@ 项近期内容", String(group.count))).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(15).frame(maxWidth: .infinity, minHeight: 86, alignment: .leading).cardBackground(corner: 16)
                        }.buttonStyle(CardPressStyle())
                    }
                }
            }
        }
    }

    private struct CourseGroup: Identifiable {
        let id: String
        let name: String
        let count: Int
    }

    private var courseGroups: [CourseGroup] {
        Dictionary(grouping: upcoming, by: \.course)
            .map { CourseGroup(id: $0.key, name: $0.key, count: $0.value.count) }
            .sorted { $0.name < $1.name }
    }

    // MARK: Tools

    private var tools: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L10n.tr("Moodle 工具"), symbol: "square.grid.2x2")
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(MoodleDirectory.tools) { tool in
                    Button { open(MoodleDestination(title: tool.title, url: tool.url)) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: tool.symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(tool.tint)
                                .frame(width: 40, height: 40).background(tool.tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tool.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text(tool.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(14).frame(maxWidth: .infinity, minHeight: 76, alignment: .leading).cardBackground(corner: 16)
                    }.buttonStyle(CardPressStyle())
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let updated = store.updatedAt {
                Text(L10n.format("最近更新：%@", updated.formatted(date: .abbreviated, time: .shortened)))
            } else if store.refreshing {
                Text(L10n.tr("正在连接 Moodle…"))
            }
            Text(L10n.tr("课程内容、作业提交、测验与成绩以 Moodle 官方页面为准。"))
        }
        .font(.caption).foregroundStyle(.tertiary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func sectionTitle(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.title3.weight(.semibold))
    }

    private func refreshIfNeeded() {
        guard !store.refreshing else { return }
        store.refresh(browser: app.browser(for: .moodle)) {
            !app.lock.isLocked && app.lock.isActive && !app.isClearingData
        }
    }
}

private struct MoodleWorkRowNative: View {
    let item: MoodleWork
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.kind == "quiz" ? "pencil.and.list.clipboard" : "doc.text")
                .foregroundStyle(item.kind == "quiz" ? Theme.orange : Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(2)
                Text(item.course).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if let due = item.dueDate {
                    Label(due.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                        .font(.caption).foregroundStyle(Theme.accent)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(15).frame(maxWidth: .infinity, alignment: .leading).cardBackground(corner: 16)
    }
}

struct MoodleTool: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let url: URL
}

enum MoodleDirectory {
    static let tools: [MoodleTool] = [
        tool("my", L10n.tr("我的课程"), L10n.tr("Dashboard / 最近访问"), "book.closed.fill", Theme.accent, "https://moodle.gtiit.edu.cn/moodle/my/"),
        tool("timeline", L10n.tr("时间线"), L10n.tr("课程动态与近期活动"), "clock.arrow.circlepath", Theme.accent, "https://moodle.gtiit.edu.cn/moodle/my/"),
        tool("calendar", L10n.tr("日历"), L10n.tr("即将到来的事件"), "calendar", Theme.orange, "https://moodle.gtiit.edu.cn/moodle/calendar/view.php?view=upcoming"),
        tool("export", L10n.tr("导出日历"), L10n.tr("官方 iCal 订阅入口"), "square.and.arrow.up", Theme.orange, "https://moodle.gtiit.edu.cn/moodle/calendar/export.php"),
        tool("grades", L10n.tr("成绩"), L10n.tr("课程成绩与反馈"), "chart.bar.doc.horizontal", Theme.accent, "https://moodle.gtiit.edu.cn/moodle/grade/report/overview/index.php"),
        tool("messages", L10n.tr("消息"), L10n.tr("课程与同学消息"), "message.fill", Theme.sky, "https://moodle.gtiit.edu.cn/moodle/message/index.php"),
        tool("notifications", L10n.tr("通知"), L10n.tr("作业、测验与课程提醒"), "bell.fill", Theme.sky, "https://moodle.gtiit.edu.cn/moodle/message/output/popup/notifications.php"),
        tool("timetable", L10n.tr("学校课表"), L10n.tr("GTIIT Calendar 插件"), "tablecells", Theme.orange, "https://moodle.gtiit.edu.cn/moodle/local/calendar/index.php"),
        tool("profile", L10n.tr("个人资料"), L10n.tr("账号与课程档案"), "person.crop.circle", Theme.accent, "https://moodle.gtiit.edu.cn/moodle/user/profile.php"),
        tool("preferences", L10n.tr("偏好设置"), L10n.tr("通知、时区与编辑器"), "gearshape", .secondary, "https://moodle.gtiit.edu.cn/moodle/user/preferences.php"),
        tool("site", L10n.tr("站点首页"), L10n.tr("Moodle 首页"), "house", Theme.accent, "https://moodle.gtiit.edu.cn/moodle/"),
        tool("search", L10n.tr("搜索"), L10n.tr("搜索课程与内容"), "magnifyingglass", Theme.sky, "https://moodle.gtiit.edu.cn/moodle/search/index.php")
    ]

    private static func tool(_ id: String, _ title: String, _ subtitle: String, _ symbol: String,
                             _ tint: Color, _ url: String) -> MoodleTool {
        MoodleTool(id: id, title: title, subtitle: subtitle, symbol: symbol, tint: tint, url: URL(string: url)!)
    }
}

private struct MoodleOfficialSheet: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    let destination: MoodleDestination

    var body: some View {
        NavigationStack {
            WebViewContainer(model: app.browser(for: .moodle))
                .navigationTitle(destination.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.tr("完成")) { dismiss() }
                    }
                }
                .onAppear {
                    let browser = app.browser(for: .moodle)
                    if browser.webView.url?.absoluteString != destination.url.absoluteString {
                        browser.load(destination.url)
                    }
                }
        }
    }
}
