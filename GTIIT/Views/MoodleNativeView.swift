import SwiftUI

enum MoodleSection: String, CaseIterable, Identifiable {
    case currentCourses, recent, otherCourses, historyCourses, tools
    var id: String { rawValue }
    var title: String {
        switch self {
        case .currentCourses: return L10n.tr("当前课程")
        case .recent: return L10n.tr("临近日程")
        case .otherCourses: return L10n.tr("其他课程")
        case .historyCourses: return L10n.tr("历史课程")
        case .tools: return L10n.tr("Moodle 工具")
        }
    }
    var symbol: String {
        switch self {
        case .currentCourses: return "book.closed.fill"
        case .recent: return "calendar.day.timeline.left"
        case .otherCourses: return "square.grid.2x2.fill"
        case .historyCourses: return "clock.arrow.circlepath"
        case .tools: return "square.grid.2x2"
        }
    }
}

/// Native Moodle home: a clear dashboard around the official course workspace.
/// Content and submission stay on the official Moodle pages.
struct MoodleTabView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @State private var path = NavigationPath()

    var body: some View {
        let _ = nativeLocale.identifier
        Group {
            if settings.nativeMoodleEnabled {
                native
            } else {
                SiteBrowserView(site: .moodle)
            }
        }
        .onAppear { consumePendingURL() }
        .onChange(of: app.pendingMoodleURL) { _, _ in consumePendingURL() }
    }

    private var native: some View {
        NavigationStack(path: $path) {
            MoodleHomeView(store: app.upcoming, timetable: app.timetable, open: open)
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
                .navigationDestination(for: MoodleDestination.self) { destination in
                    if destination.kind == .course {
                        MoodleCoursePageView(title: destination.title, url: destination.url)
                    } else {
                        MoodleWebPageView(destination: destination)
                    }
                }
        }
        .onChange(of: path.count) { _, count in
            if count == 0 { refresh() }
        }
    }

    private func open(_ destination: MoodleDestination) {
        path.append(destination)
    }

    private func refresh() {
        app.upcoming.refresh(browser: app.browser(for: .moodle), force: true) {
            !app.lock.isLocked && app.lock.isActive && !app.isClearingData
        }
    }

    private func consumePendingURL() {
        guard let url = app.pendingMoodleURL else { return }
        app.pendingMoodleURL = nil
        path.append(MoodleDestination(title: "Moodle", url: url))
    }
}

struct MoodleDestination: Identifiable, Hashable {
    enum Kind: Hashable { case course, web }
    let id = UUID()
    let title: String
    let url: URL
    var kind: Kind = .web

    init(title: String, url: URL, kind: Kind = .web) {
        self.title = title
        self.url = url
        self.kind = kind
    }
}

struct MoodleHomeView: View {
    @Environment(\.locale) private var nativeLocale
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var store: MoodleUpcomingStore
    @ObservedObject var timetable: LocalTimetableStore
    @State private var showLayout = false
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
                ForEach(visibleSections) { section in
                    sectionView(section)
                }
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 20)
            .padding(.top, 8)
            .padding(.bottom, 30)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.pageBackground)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showLayout = true } label: {
                        Label(L10n.tr("编辑 Moodle 布局"), systemImage: "slider.horizontal.3")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(L10n.tr("Moodle 布局"))
            }
        }
        .sheet(isPresented: $showLayout) {
            MoodleLayoutSettingsView()
                .environmentObject(settings)
        }
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
            Text(L10n.tr("课程、作业、测验与消息。"))
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

    private var visibleSections: [MoodleSection] {
        let ordered = settings.moodleSectionOrder.compactMap(MoodleSection.init(rawValue:))
        let missing = MoodleSection.allCases.filter { !ordered.contains($0) }
        let visible = (ordered + missing).filter { !settings.moodleHiddenSections.contains($0.rawValue) }
        return [.currentCourses].filter { visible.contains($0) } + visible.filter { $0 != .currentCourses }
    }

    @ViewBuilder
    private func sectionView(_ section: MoodleSection) -> some View {
        switch section {
        case .currentCourses: currentCoursesSection
        case .recent: dashboard
        case .otherCourses: otherCoursesSection
        case .historyCourses: historyCoursesSection
        case .tools: tools
        }
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

    private var currentTermLabel: String {
        let term = MoodleUpcomingStore.currentTerm()
        return term.season.capitalized + " " + String(term.year)
    }

    private var currentCourses: [MoodleCourse] {
        store.courseItems.filter { ($0.term ?? "").caseInsensitiveCompare(currentTermLabel) == .orderedSame }
            .sorted { $0.name < $1.name }
    }

    private var syncedCurrentCourses: [MoodleCourse] {
        currentCourses.filter(matchesTimetable)
    }

    private var otherCourses: [MoodleCourse] {
        currentCourses.filter { !matchesTimetable($0) }
    }

    private struct CategoryGroup: Identifiable {
        let id: String
        let courses: [MoodleCourse]
    }

    private var otherCategoryGroups: [CategoryGroup] {
        Dictionary(grouping: otherCourses, by: { $0.category ?? L10n.tr("其他") })
            .map { CategoryGroup(id: $0.key, courses: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.id < $1.id }
    }

    private func normalizedName(_ value: String) -> String {
        let stripped = value.lowercased()
            .replacingOccurrences(of: "\\b(winter|spring|summer|autumn|fall)\\b", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\b20\\d{2}\\b", with: "", options: .regularExpression)
        return stripped.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }

    private func normalizedCode(_ value: String) -> String {
        value.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }

    private func matchesTimetable(_ course: MoodleCourse) -> Bool {
        let schedule = timetable.snapshot?.courses ?? []
        guard !schedule.isEmpty else { return false }
        let codes = Set(schedule.map { normalizedCode($0.code) }.filter { !$0.isEmpty })
        let names = schedule.map { normalizedName($0.name) }.filter { !$0.isEmpty }
        let courseCodes = [course.shortname, course.name].compactMap { $0 }.map(normalizedCode).filter { !$0.isEmpty }
        if courseCodes.contains(where: { codes.contains($0) }) { return true }
        let courseNames = [course.name, course.shortname].compactMap { $0 }.map(normalizedName).filter { $0.count >= 4 }
        for name in courseNames {
            if names.contains(where: { candidate in
                candidate == name || (candidate.count >= 5 && name.count >= 5 && (candidate.contains(name) || name.contains(candidate)))
            }) { return true }
        }
        return false
    }

    private var historyCourses: [MoodleCourse] {
        store.courseItems.filter { ($0.term ?? "").caseInsensitiveCompare(currentTermLabel) != .orderedSame }
            .sorted { $0.name < $1.name }
    }

    private var currentCoursesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                sectionTitle(L10n.tr("当前课程"), symbol: "book.closed.fill")
                Text(currentTermLabel).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            if syncedCurrentCourses.isEmpty {
                Text(L10n.tr("导入课表后，这里只显示课表上的课程。"))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(16).cardBackground()
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(syncedCurrentCourses) { course in
                        Button {
                            if let url = course.url {
                                open(MoodleDestination(title: course.displayName, url: url, kind: .course))
                            }
                        } label: {
                            courseCard(course)
                        }.buttonStyle(CardPressStyle())
                    }
                }
            }
        }
    }

    private var otherCoursesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L10n.tr("其他课程"), symbol: "square.grid.2x2.fill")
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(otherCourses.sorted { $0.name < $1.name }) { course in
                    Button {
                        if let url = course.url {
                            open(MoodleDestination(title: course.displayName, url: url, kind: .course))
                        }
                    } label: {
                        courseCard(course)
                    }.buttonStyle(CardPressStyle())
                }
            }
        }
    }

    private var historyCoursesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L10n.tr("历史课程"), symbol: "clock.arrow.circlepath")
            NavigationLink {
                MoodleHistoryView(store: store, open: open)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.orange)
                        .frame(width: 42, height: 42)
                        .background(Theme.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.tr("历史课程")).font(.body.weight(.semibold))
                        Text(L10n.format("%@ 门课程", String(historyCourses.count)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardBackground(corner: 16)
            }
            .buttonStyle(CardPressStyle())
        }
    }

    private func courseCard(_ course: MoodleCourse) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed.fill").foregroundStyle(Theme.accent)
                .frame(width: 38, height: 38).background(Theme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(course.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(2)
                HStack(spacing: 6) {
                    if let number = course.courseNumber, !number.isEmpty {
                        Text(number)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                    Text(course.term ?? L10n.tr("当前学期"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(15).frame(maxWidth: .infinity, minHeight: 86, alignment: .leading).cardBackground(corner: 16)
    }

    private func termKey(_ term: String?) -> (Int, Int) {
        guard let term else { return (0, 0) }
        let parts = term.split(separator: " ")
        guard parts.count >= 2, let year = Int(parts.last ?? "") else { return (0, 0) }
        let order = ["winter": 0, "spring": 1, "summer": 2][String(parts.first ?? "").lowercased()] ?? 3
        return (year, order)
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
        tool("files", L10n.tr("私密文件"), L10n.tr("个人文件与上传"), "folder.fill", Theme.accent, "https://moodle.gtiit.edu.cn/moodle/user/files.php"),
        tool("badges", L10n.tr("徽章"), L10n.tr("我的徽章"), "rosette", Theme.orange, "https://moodle.gtiit.edu.cn/moodle/badges/mybadges.php"),
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

struct MoodleHistoryView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var store: MoodleUpcomingStore
    let open: (MoodleDestination) -> Void

    private var currentTermLabel: String {
        let term = MoodleUpcomingStore.currentTerm()
        return term.season.capitalized + " " + String(term.year)
    }

    private var historyCourses: [MoodleCourse] {
        store.courseItems.filter { ($0.term ?? "").caseInsensitiveCompare(currentTermLabel) != .orderedSame }
    }

    private var columns: [GridItem] {
        horizontalSizeClass == .regular
            ? [GridItem(.adaptive(minimum: 300), spacing: 16)]
            : [GridItem(.flexible())]
    }

    private var groups: [HistoryGroup] {
        Dictionary(grouping: historyCourses, by: { $0.term })
            .map { HistoryGroup(id: $0.key ?? "history", term: $0.key, courses: $0.value.sorted { $0.name < $1.name }) }
            .sorted { termKey($0.term) > termKey($1.term) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if historyCourses.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.tr("暂无历史课程")).font(.headline)
                        Button {
                            open(MoodleDestination(title: L10n.tr("历史课程"), url: URL(string: "https://moodle.gtiit.edu.cn/moodle/my/")!))
                        } label: {
                            Label(L10n.tr("打开 Moodle 个人主页"), systemImage: "arrow.up.right")
                        }.foregroundStyle(Theme.accent)
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
                } else {
                    Text(L10n.format("共 %@ 门课程", String(historyCourses.count)))
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            if let term = group.term {
                                Text(term).font(.headline).foregroundStyle(Theme.orange)
                            }
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(group.courses) { course in
                                    Button {
                                        if let url = course.url {
                                            open(MoodleDestination(title: course.displayName, url: url, kind: .course))
                                        }
                                    } label: {
                                        historyCard(course)
                                    }.buttonStyle(CardPressStyle())
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 20)
            .padding(.top, 8).padding(.bottom, 30)
            .frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }
        .background(Theme.pageBackground)
        .navigationTitle(L10n.tr("历史课程"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    open(MoodleDestination(title: L10n.tr("历史课程"), url: URL(string: "https://moodle.gtiit.edu.cn/moodle/my/")!))
                } label: {
                    Image(systemName: "person.crop.circle")
                }
                .accessibilityLabel(L10n.tr("打开 Moodle 个人主页"))
            }
        }
    }

    private struct HistoryGroup: Identifiable {
        let id: String
        let term: String?
        let courses: [MoodleCourse]
    }

    private func historyCard(_ course: MoodleCourse) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed.fill").foregroundStyle(Theme.orange)
                .frame(width: 38, height: 38)
                .background(Theme.orange.opacity(0.11), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(course.displayName).font(.subheadline.weight(.semibold)).lineLimit(3)
                HStack(spacing: 6) {
                    if let number = course.courseNumber, !number.isEmpty {
                        Text(number)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                    Text(course.term ?? L10n.tr("历史课程"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(15).frame(maxWidth: .infinity, minHeight: 86, alignment: .leading).cardBackground(corner: 16)
    }

    private func termKey(_ term: String?) -> (Int, Int) {
        guard let term else { return (0, 0) }
        let parts = term.split(separator: " ")
        guard parts.count >= 2, let year = Int(parts.last ?? "") else { return (0, 0) }
        let order = ["winter": 0, "spring": 1, "summer": 2][String(parts.first ?? "").lowercased()] ?? 3
        return (year, order)
    }
}

struct MoodleLayoutSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(settings.moodleSectionOrder, id: \.self) { raw in
                        if let section = MoodleSection(rawValue: raw) {
                            Toggle(isOn: Binding(
                                get: { !settings.moodleHiddenSections.contains(raw) },
                                set: { visible in
                                    if visible { settings.moodleHiddenSections.remove(raw) }
                                    else { settings.moodleHiddenSections.insert(raw) }
                                }
                            )) {
                                Label(section.title, systemImage: section.symbol)
                            }
                        }
                    }
                    .onMove { source, destination in
                        settings.moodleSectionOrder.move(fromOffsets: source, toOffset: destination)
                    }
                } header: {
                    Text(L10n.tr("显示的内容"))
                } footer: {
                    Text(L10n.tr("拖动排序；关闭开关即可收起对应内容。"))
                }
                Section {
                    Button(L10n.tr("恢复默认布局")) {
                        settings.moodleSectionOrder = ["currentCourses", "recent", "otherCourses", "historyCourses", "tools"]
                        settings.moodleHiddenSections = []
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle(L10n.tr("Moodle 布局"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("完成")) { dismiss() }
                }
            }
        }
    }
}

struct MoodleWebPageView: View {
    @EnvironmentObject private var app: AppModel
    let destination: MoodleDestination

    var body: some View {
        WebViewContainer(model: app.browser(for: .moodle))
            .navigationTitle(destination.title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                let browser = app.browser(for: .moodle)
                browser.webView.allowsBackForwardNavigationGestures = false
                WebAppearance.setMoodleCourseChrome(hidden: false, on: browser.webView)
                if browser.webView.url?.absoluteString != destination.url.absoluteString {
                    browser.load(destination.url)
                }
            }
            .onDisappear {
                app.browser(for: .moodle).webView.allowsBackForwardNavigationGestures = true
            }
    }
}

struct MoodleCoursePageView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let url: URL

    var body: some View {
        WebViewContainer(model: app.browser(for: .moodle))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    let browser = app.browser(for: .moodle)
                    browser.webView.allowsBackForwardNavigationGestures = false
                    WebAppearance.setMoodleCourseChrome(hidden: true, on: browser.webView, pageHex: Theme.pageHex(for: colorScheme))
                    browser.webView.scrollView.setContentOffset(.zero, animated: false)
                    if browser.webView.url?.absoluteString != url.absoluteString {
                        browser.load(url)
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(80))
                        browser.webView.scrollView.setContentOffset(.zero, animated: false)
                        WebViewHostController.resetForCourse(browser.webView)
                        try? await Task.sleep(for: .milliseconds(350))
                        browser.webView.scrollView.setContentOffset(.zero, animated: false)
                        WebViewHostController.resetForCourse(browser.webView)
                    }
                }
                .onChange(of: colorScheme) { _, scheme in
                    WebAppearance.setMoodleCourseChrome(hidden: true, on: app.browser(for: .moodle).webView, pageHex: Theme.pageHex(for: scheme))
                }
                .onDisappear {
                    let browser = app.browser(for: .moodle)
                    browser.webView.allowsBackForwardNavigationGestures = true
                    WebAppearance.setMoodleCourseChrome(hidden: false, on: browser.webView)
                }
                .background(Theme.pageBackground)
                .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}
