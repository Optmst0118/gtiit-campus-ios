import SwiftUI

protocol SettingChoice: RawRepresentable, CaseIterable, Identifiable where RawValue == String {
    var title: String { get }
}
extension SettingChoice { var id: String { rawValue } }
enum AppAppearance: String, SettingChoice {
    case system, light, dark
    var title: String {
        switch self {
        case .system: return L10n.tr("跟随系统")
        case .light: return L10n.tr("浅色")
        case .dark: return L10n.tr("深色")
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
enum ExternalLinkMode: String, SettingChoice {
    case webView, safariView, systemBrowser
    var title: String {
        switch self {
        case .webView: return L10n.tr("当前网页")
        case .safariView: return L10n.tr("App 内 Safari")
        case .systemBrowser: return L10n.tr("默认浏览器")
        }
    }
}
enum LockDelay: String, SettingChoice {
    case immediately, minute, fiveMinutes
    var title: String {
        switch self {
        case .immediately: return L10n.tr("立即")
        case .minute: return L10n.tr("1 分钟后")
        case .fiveMinutes: return L10n.tr("5 分钟后")
        }
    }
    var seconds: TimeInterval {
        switch self {
        case .immediately: return 0
        case .minute: return 60
        case .fiveMinutes: return 300
        }
    }
}
enum DownloadRetention: String, SettingChoice {
    case forever, session, day, week
    var title: String {
        switch self {
        case .forever: return L10n.tr("永久保留（手动删除）")
        case .session: return L10n.tr("下次启动时清理")
        case .day: return L10n.tr("1 天")
        case .week: return L10n.tr("7 天")
        }
    }
    var seconds: TimeInterval {
        switch self {
        case .forever: return .infinity
        case .session: return 0
        case .day: return 86_400
        case .week: return 604_800
        }
    }
}

enum MyPageSection: String, CaseIterable, Identifiable {
    case timetable, assignments, exams, shortcuts
    var id: String { rawValue }
    var title: String {
        switch self {
        case .timetable: return L10n.tr("本地课表")
        case .assignments: return L10n.tr("临近作业")
        case .exams: return L10n.tr("临近考试")
        case .shortcuts: return L10n.tr("常用入口")
        }
    }
    var symbol: String {
        switch self { case .timetable: return "calendar"; case .assignments: return "checklist"; case .exams: return "pencil.and.list.clipboard"; case .shortcuts: return "square.grid.2x2" }
    }
}
enum EntryOrder {
    static func normalized(_ stored: [String], allowed: [String]) -> [String] {
        var seen = Set<String>()
        return (stored + allowed).filter { allowed.contains($0) && seen.insert($0).inserted }
    }
}

@MainActor final class AppSettings: ObservableObject {
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "settings.language"); AppGroup.defaults.set(language.rawValue, forKey: AppGroup.Key.language); L10n.language = language }
    }
    @Published var shuttleReminderLead: Int {
        didSet { defaults.set(shuttleReminderLead, forKey: "settings.shuttleReminderLead") }
    }
    @Published var moodleUpcomingRange: MoodleUpcomingRange {
        didSet { defaults.set(moodleUpcomingRange.rawValue, forKey: "settings.moodleUpcomingRange") }
    }
    @Published var moodleReminderLead: MoodleReminderLead {
        didSet { defaults.set(moodleReminderLead.rawValue, forKey: "settings.moodleReminderLead") }
    }
    @Published var moodleDeadlineRemindersEnabled: Bool {
        didSet { defaults.set(moodleDeadlineRemindersEnabled, forKey: "settings.moodleDeadlineRemindersEnabled") }
    }
    @Published var privateShuttleReminders: Bool {
        didSet { defaults.set(privateShuttleReminders, forKey: "settings.privateShuttleReminders") }
    }
    @Published var yilongUnlocked: Bool {
        didSet { defaults.set(yilongUnlocked, forKey: "settings.yilongUnlocked") }
    }
    private let defaults: UserDefaults
    @Published var mySectionOrder: [String] { didSet { defaults.set(mySectionOrder, forKey: "settings.mySectionOrder") } }
    @Published var hiddenMySections: Set<String> { didSet { defaults.set(hiddenMySections.sorted(), forKey: "settings.hiddenMySections") } }
    @Published var shortcutOrder: [String] { didSet { defaults.set(shortcutOrder, forKey: "settings.shortcutOrder") } }
    @Published var shortcutIDs: Set<String> {
        didSet { defaults.set(shortcutIDs.sorted(), forKey: "settings.shortcutIDs") }
    }
    @Published var webDarkMode: Bool {
        didSet { defaults.set(webDarkMode, forKey: "settings.webDarkMode") }
    }
    @Published var originalColorSites: Set<SiteID> {
        didSet { defaults.set(originalColorSites.map(\.rawValue), forKey: "settings.originalColorSites") }
    }
    func webDarkModeEnabled(for site: SiteID) -> Bool { webDarkMode && !originalColorSites.contains(site) }
    @Published var preloadSitesOnLaunch: Bool {
        didSet { defaults.set(preloadSitesOnLaunch, forKey: "settings.preloadSitesOnLaunch") }
    }
    @Published var nativeBookingEnabled: Bool {
        didSet { defaults.set(nativeBookingEnabled, forKey: "settings.nativeBookingEnabled") }
    }
    @Published var nativeMoodleEnabled: Bool {
        didSet { defaults.set(nativeMoodleEnabled, forKey: "settings.nativeMoodleEnabled") }
    }
    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: "settings.hapticsEnabled") }
    }
    @Published var loginEmail: String {
        didSet { defaults.set(loginEmail, forKey: "settings.loginEmail") }
    }
    @Published var prefillLoginEmail: Bool {
        didSet { defaults.set(prefillLoginEmail, forKey: "settings.prefillLoginEmail") }
    }
    @Published var followedMoodleCourseIDs: Set<Int> {
        didSet { defaults.set(followedMoodleCourseIDs.sorted(), forKey: "settings.followedMoodleCourseIDs") }
    }
    @Published var moodleSectionOrder: [String] {
        didSet { defaults.set(moodleSectionOrder, forKey: "settings.moodleSectionOrder") }
    }
    @Published var moodleHiddenSections: Set<String> {
        didSet { defaults.set(moodleHiddenSections.sorted(), forKey: "settings.moodleHiddenSections") }
    }
    @Published var shuttleTeachingWeek: Bool {
        didSet {
            defaults.set(shuttleTeachingWeek, forKey: "settings.shuttleTeachingWeek")
            AppGroup.defaults.set(shuttleTeachingWeek, forKey: AppGroup.Key.teachingWeek)
        }
    }
    @Published var favoriteShuttleDirection: ShuttleDirection {
        didSet {
            defaults.set(favoriteShuttleDirection.rawValue, forKey: "settings.shuttleFavoriteDirection")
            AppGroup.defaults.set(favoriteShuttleDirection.rawValue, forKey: AppGroup.Key.favoriteDirection)
        }
    }
    @Published var hasSeenWelcome: Bool {
        didSet { defaults.set(hasSeenWelcome, forKey: "settings.hasSeenWelcome") }
    }
    @Published var biometricLockEnabled: Bool {
        didSet { defaults.set(biometricLockEnabled, forKey: "settings.biometricLock") }
    }
    @Published var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: "settings.appearance") }
    }
    @Published var startupTab: AppTab {
        didSet { defaults.set(startupTab.rawValue, forKey: "settings.startupTab") }
    }
    @Published var defaultBooking: BookingSegment {
        didSet { defaults.set(defaultBooking.rawValue, forKey: "settings.defaultBooking") }
    }
    @Published var externalLinks: ExternalLinkMode {
        didSet { defaults.set(externalLinks.rawValue, forKey: "settings.externalLinks") }
    }
    @Published var lockDelay: LockDelay {
        didSet { defaults.set(lockDelay.rawValue, forKey: "settings.lockDelay") }
    }
    @Published var hideInAppSwitcher: Bool {
        didSet { defaults.set(hideInAppSwitcher, forKey: "settings.hideInAppSwitcher") }
    }
    @Published var restoreLastPage: Bool {
        didSet {
            defaults.set(restoreLastPage, forKey: "settings.restoreLastPage")
            if !restoreLastPage { clearLocations() }
        }
    }
    @Published var downloadRetention: DownloadRetention {
        didSet { defaults.set(downloadRetention.rawValue, forKey: "settings.downloadRetention") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let sections = MyPageSection.allCases.map(\.rawValue)
        mySectionOrder = EntryOrder.normalized(defaults.stringArray(forKey: "settings.mySectionOrder") ?? [], allowed: sections)
        hiddenMySections = Set((defaults.stringArray(forKey: "settings.hiddenMySections") ?? []).filter(sections.contains))
        shortcutOrder = EntryOrder.normalized(defaults.stringArray(forKey: "settings.shortcutOrder") ?? [], allowed: CampusShortcut.all.map(\.id))
        let storedLead = defaults.integer(forKey: "settings.shuttleReminderLead")
        shuttleReminderLead = [5, 10, 15].contains(storedLead) ? storedLead : 10
        moodleUpcomingRange = MoodleUpcomingRange(rawValue: defaults.integer(forKey: "settings.moodleUpcomingRange")) ?? .ten
        moodleReminderLead = MoodleReminderLead(rawValue: defaults.integer(forKey: "settings.moodleReminderLead")) ?? .oneDay
        moodleDeadlineRemindersEnabled = defaults.object(forKey: "settings.moodleDeadlineRemindersEnabled") as? Bool ?? true
        privateShuttleReminders = defaults.bool(forKey: "settings.privateShuttleReminders")
        var initialShortcuts = defaults.stringArray(forKey: "settings.shortcutIDs").map(Set.init) ?? CampusShortcut.defaults
        if defaults.integer(forKey: "settings.shortcutDefaultsVersion") < 2 {
            initialShortcuts.remove("portal.enrollments")
            initialShortcuts.insert("native.mail")
            // Property observers do not run during init; persist the migrated set
            // now or it would come back from the old stored value next launch.
            defaults.set(initialShortcuts.sorted(), forKey: "settings.shortcutIDs")
            defaults.set(2, forKey: "settings.shortcutDefaultsVersion")
        }
        if defaults.integer(forKey: "settings.shortcutDefaultsVersion") < 3 {
            initialShortcuts.insert("servicehub.home")
            defaults.set(initialShortcuts.sorted(), forKey: "settings.shortcutIDs")
            defaults.set(3, forKey: "settings.shortcutDefaultsVersion")
        }
        shortcutIDs = initialShortcuts
        language = AppLanguage(rawValue: defaults.string(forKey: "settings.language") ?? "") ?? .chinese
        yilongUnlocked = defaults.bool(forKey: "settings.yilongUnlocked")
        webDarkMode = defaults.object(forKey: "settings.webDarkMode") as? Bool ?? true
        originalColorSites = Set((defaults.stringArray(forKey: "settings.originalColorSites") ?? []).compactMap(SiteID.init(rawValue:)))
        preloadSitesOnLaunch = defaults.object(forKey: "settings.preloadSitesOnLaunch") as? Bool ?? true
        nativeBookingEnabled = defaults.object(forKey: "settings.nativeBookingEnabled") as? Bool ?? true
        nativeMoodleEnabled = defaults.object(forKey: "settings.nativeMoodleEnabled") as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: "settings.hapticsEnabled") as? Bool ?? true
        loginEmail = defaults.string(forKey: "settings.loginEmail") ?? ""
        prefillLoginEmail = defaults.object(forKey: "settings.prefillLoginEmail") as? Bool ?? true
        followedMoodleCourseIDs = Set((defaults.array(forKey: "settings.followedMoodleCourseIDs") as? [Int] ?? []).filter { $0 > 0 })
        let allSections = ["currentCourses", "recent", "otherCourses", "historyCourses", "tools"]
        let defaultSections = ["currentCourses", "recent", "otherCourses", "historyCourses", "tools"]
        var storedSections = defaults.stringArray(forKey: "settings.moodleSectionOrder") ?? defaultSections
        // Migrate the alpha.12 single "courses" section to current + history.
        storedSections = storedSections.flatMap { $0 == "courses" ? ["currentCourses", "historyCourses"] : [$0] }
        var order = storedSections.filter(allSections.contains)
        order.removeAll { $0 == "currentCourses" }
        order.insert("currentCourses", at: 0)
        order += allSections.filter { !order.contains($0) }
        moodleSectionOrder = order
        var hidden = Set((defaults.stringArray(forKey: "settings.moodleHiddenSections") ?? []).filter(allSections.contains))
        if hidden.contains("courses") {
            hidden.remove("courses")
            hidden.insert("currentCourses")
            hidden.insert("historyCourses")
        }
        moodleHiddenSections = hidden
        shuttleTeachingWeek = defaults.object(forKey: "settings.shuttleTeachingWeek") as? Bool ?? true
        favoriteShuttleDirection = ShuttleDirection(rawValue: defaults.string(forKey: "settings.shuttleFavoriteDirection") ?? "")
            ?? ShuttleDirection(rawValue: AppGroup.defaults.string(forKey: AppGroup.Key.favoriteDirection) ?? "")
            ?? .southToNorth
        hasSeenWelcome = defaults.bool(forKey: "settings.hasSeenWelcome")
        biometricLockEnabled = defaults.bool(forKey: "settings.biometricLock")
        appearance = AppAppearance(rawValue: defaults.string(forKey: "settings.appearance") ?? "") ?? .system
        startupTab = AppTab(rawValue: defaults.string(forKey: "settings.startupTab") ?? "") ?? .shuttle
        defaultBooking =
            BookingSegment(rawValue: defaults.string(forKey: "settings.defaultBooking") ?? "") ?? .rooms
        externalLinks =
            ExternalLinkMode(rawValue: defaults.string(forKey: "settings.externalLinks") ?? "") ?? .webView
        lockDelay = LockDelay(rawValue: defaults.string(forKey: "settings.lockDelay") ?? "") ?? .immediately
        hideInAppSwitcher = defaults.object(forKey: "settings.hideInAppSwitcher") as? Bool ?? true
        restoreLastPage = defaults.bool(forKey: "settings.restoreLastPage")
        // 1.2 起默认保存为本机文件；迁移旧版的默认“会话缓存”策略。
        if !defaults.bool(forKey: "settings.persistentDownloadsV1") {
            defaults.set("forever", forKey: "settings.downloadRetention")
            defaults.set(true, forKey: "settings.persistentDownloadsV1")
        }
        downloadRetention = DownloadRetention(rawValue: defaults.string(forKey: "settings.downloadRetention") ?? "") ?? .forever
        L10n.language = language
    }
    func markWelcomeSeen() { hasSeenWelcome = true }
    func resetWelcome() { hasSeenWelcome = false }
    func initialURL(for site: SiteID) -> URL {
        guard restoreLastPage, let raw = defaults.string(forKey: "location.\(site.rawValue)"),
            let url = URL(string: raw), Self.restorable(url, site: site)
        else { return site.homeURL }
        return url
    }
    func remember(_ url: URL, for site: SiteID) {
        guard restoreLastPage, Self.restorable(url, site: site) else { return }
        defaults.set(url.absoluteString, forKey: "location.\(site.rawValue)")
    }
    static func restorable(_ url: URL, site: SiteID) -> Bool {
        guard url.scheme == "https", url.host == site.homeURL.host, url.user == nil, url.password == nil,
            url.query == nil, url.fragment == nil
        else { return false }
        let path = url.path.lowercased()
        return !["login", "logout", "oauth", "saml", "auth", "callback", "token", "submit", "delete"]
            .contains(where: path.contains)
    }
    func clearLocation(for site: SiteID) { defaults.removeObject(forKey: "location.\(site.rawValue)") }
    func clearLocations() { SiteID.allCases.forEach { clearLocation(for: $0) } }
}
