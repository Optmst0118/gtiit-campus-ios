import Combine
import SafariServices
import SwiftUI
import UIKit
import WebKit

/// 应用级状态：Tab 选择、四个站点的网页内核、跨站路由、轻提示与外部呈现。
@MainActor
final class AppModel: ObservableObject {
    @Published var selectedTab: AppTab = .portal
    @Published var bookingSegment: BookingSegment = .rooms
    @Published var pendingWebRoute: CampusWebRoute?
    @Published var visitedTabs: Set<AppTab> = [.portal]
    @Published var toastText: String?
    @Published var showWelcome = false
    @Published var siteInfo: SiteID?
    @Published var showDownloads = false
    @Published private(set) var storageStates: [SiteID: Bool] = [:]
    @Published private(set) var tabReselectToken = 0
    @Published private(set) var tabReselectTarget: AppTab?

    @Published private(set) var contextMenuSource: String?
    func showContextMenu(_ source: String) { contextMenuSource = source }
    func hideContextMenu(_ source: String) { if contextMenuSource == source { contextMenuSource = nil } }

    let timetable = LocalTimetableStore()
    let upcoming = MoodleUpcomingStore()
    let campusSync = CampusSessionSync()
    let exams = StudentExamStore()
    let yilong = YilongController()
    let lock = AppLockController()
    let launch = LaunchPreparation()
    let downloads = DownloadCoordinator()
    let privacyShield = PrivacyShieldController()
    let moodleAutoLogin = MoodleAutoLogin()
    let settings: AppSettings
    @Published private(set) var isClearingData = false
    @Published private(set) var storageSummaries: [SiteID: SiteStorageSummary] = [:]
    private var lockSubscription: AnyCancellable?
    private var appearanceSubscription: AnyCancellable?
    private var launchSubscription: AnyCancellable?
    private var campusSubscription: AnyCancellable?
    private var didScheduleSummaryWarmup = false
    private var moodleAutoLoginStarted = false
    private var refreshAfterMoodleLogin = false

    private var browsers: [SiteID: BrowserModel] = [:]
    private var toastTask: Task<Void, Never>?

    init(settings: AppSettings? = nil) {
        let settings = settings ?? AppSettings()
        self.settings = settings
        selectedTab = settings.startupTab
        visitedTabs = [settings.startupTab]
        bookingSegment = settings.defaultBooking
        downloads.start(retention: settings.downloadRetention)
        downloads.presentController = { [weak self] controller in self?.browserPresent(viewController: controller) ?? false }
        downloads.onMessage = { [weak self] message in self?.toast(message) }
        // 下载的进度、成功与失败均由唯一的下载面板呈现，不再另叠 Toast。
        lockSubscription = lock.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.lock.isLocked || !self.lock.isActive { self.upcoming.cancel(); self.exams.cancel(); self.campusSync.cancel(); self.contextMenuSource = nil }
            }
        }
        campusSubscription = campusSync.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        launchSubscription = launch.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        appearanceSubscription = settings.$webDarkMode.combineLatest(settings.$originalColorSites).sink { [weak self] enabled, original in
            guard let self else { return }
            for (site, model) in self.browsers {
                // Publisher 在属性更新前发值；此处直接使用新值。
                WebAppearance.update(model.webView, enabled: enabled && !original.contains(site))
                Task { @MainActor [weak model] in model?.applyWebAppearance() }
            }
        }
        if settings.biometricLockEnabled { lock.lock() }
        upcoming.onReminderSnapshot = { [weak self] in self?.syncMoodleDeadlineReminders() }
        upcoming.onClearReminders = { MoodleDeadlineReminders.shared.clear() }
        ShuttleNotificationCenter.shared.onOpenMoodle = { [weak self] url in
            self?.openWeb(url, site: .moodle)
        }
        ShuttleNotificationCenter.shared.onOpen = { [weak self] direction in
            guard let self else { return }
            self.select(tab: .shuttle)
            if let direction { self.settings.favoriteShuttleDirection = direction }
        }
    }

    /// Handles gtiit-beta://shuttle[?direction=north|south] from a widget or notification.
    func handleShuttleURL(_ url: URL) {
        guard url.scheme == "gtiit-beta" else { return }
        if url.host == "timetable" { select(tab: .me); return }
        guard url.host == "shuttle" else { return }
        select(tab: .shuttle)
        if let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "direction" })?.value,
            let direction = ShuttleDirection(rawValue: raw) {
            settings.favoriteShuttleDirection = direction
        }
    }

    func syncMoodleDeadlineReminders() {
        var canRequest = settings.hasSeenWelcome && !showWelcome && !lock.isLocked && lock.isActive
            && !isClearingData && UIApplication.shared.applicationState == .active
        #if GTIIT_REGRESSION
        canRequest = false
        #endif
        MoodleDeadlineReminders.shared.update(items: upcoming.items, updatedAt: upcoming.updatedAt,
            partial: upcoming.partial, enabled: settings.moodleDeadlineRemindersEnabled, allowPermissionRequest: canRequest, lead: settings.moodleReminderLead)
    }

    func refreshMoodleSummary(force: Bool = false) {
        #if DEBUG
        if ProcessInfo.processInfo.environment["UI_REVIEW_INBOX"] == "1" || ProcessInfo.processInfo.environment["UI_REVIEW_MOODLE_CACHE"] == "1" { return }
        #endif
        upcoming.upcomingDays = settings.moodleUpcomingRange.rawValue
        upcoming.priorityCourseIDs = Set(upcoming.courseItems.filter { $0.matches(timetable.snapshot) }.map(\.id))
            .union(settings.followedMoodleCourseIDs)
        upcoming.refresh(browser: browser(for: .moodle), force: force) { [weak self] in
            guard let self else { return false }
            return !self.lock.isLocked && self.lock.isActive && !self.isClearingData
        }
    }

    private func warmUpCampusSummaries() {
        let allowed: () -> Bool = { [weak self] in
            guard let self else { return false }
            return !self.lock.isLocked && self.lock.isActive && !self.isClearingData
        }
        // Moodle's lightweight on-device summary starts first. The exam probe
        // uses a second hidden WebView, so give it a separate slot instead of
        // competing with the first portal/Moodle paint.
        refreshMoodleSummary()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard let self, allowed() else { return }
            self.exams.refresh(allowed: allowed)
        }
    }

    func refreshCampusSessions(force: Bool = false) {
        #if GTIIT_REGRESSION
        return
        #else
        #if DEBUG
        if ProcessInfo.processInfo.environment["UI_REVIEW_INBOX"] == "1" || ProcessInfo.processInfo.environment["UI_REVIEW_MOODLE_CACHE"] == "1" { return }
        #endif
        campusSync.start(force: force) { [weak self] in
            guard let self else { return false }
            return self.settings.hasSeenWelcome && !self.showWelcome && !self.lock.isLocked && self.lock.isActive && !self.isClearingData
        }
        #endif
    }

    func refreshRoomCacheIfAllowed(force: Bool = false) {
        #if !GTIIT_REGRESSION
        #if DEBUG
        if ProcessInfo.processInfo.environment["UI_REVIEW_INBOX"] == "1" || ProcessInfo.processInfo.environment["UI_REVIEW_MOODLE_CACHE"] == "1" { return }
        #endif
        campusSync.refreshRooms(force: force) { [weak self] in
            guard let self else { return false }
            return self.settings.hasSeenWelcome && !self.showWelcome && !self.lock.isLocked && self.lock.isActive && !self.isClearingData
        }
        #endif
    }

    func prepareLaunchIfAllowed() {
        guard settings.hasSeenWelcome, !showWelcome, !lock.isLocked, lock.isActive else { return }
        refreshCampusSessions()
        guard settings.preloadSitesOnLaunch else { launch.skip(); return }
        guard !launch.hasStarted, !launch.didFinish else { return }
        prepareMoodleAutoLogin()
        // Load all four real WebKit hosts in parallel behind the visible UI.
        // There is no launch overlay: first paint and page warming are independent.
        launch.start(models: SiteID.onboardingSites.map { browser(for: $0) }, canRestoreSession: { [weak self] in
            guard let self else { return false }
            return !self.lock.isLocked && self.lock.isActive && !self.isClearingData
        })
        scheduleSummaryWarmupIfNeeded()
    }

    func prepareMoodleAutoLogin() {
        guard !moodleAutoLoginStarted else { return }
        moodleAutoLoginStarted = true
        moodleAutoLogin.start(browser: browser(for: .moodle)) { [weak self] in
            guard let self else { return false }
            return !self.lock.isLocked && self.lock.isActive && !self.isClearingData
        }
    }

    private func scheduleSummaryWarmupIfNeeded() {
        guard !didScheduleSummaryWarmup, settings.preloadSitesOnLaunch else { return }
        didScheduleSummaryWarmup = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            while self.launch.isPreparing {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
            }
            guard !self.lock.isLocked, self.lock.isActive, !self.isClearingData else { return }
            self.warmUpCampusSummaries()
        }
    }

    // MARK: - 网页内核

    /// 同一站点始终复用同一个 WebView，切 Tab 不会重新加载页面。
    func browser(for site: SiteID) -> BrowserModel {
        if let existing = browsers[site] { return existing }
        let model = BrowserModel(site: site, router: self)
        browsers[site] = model
        return model
    }

    // MARK: - Tab 与入口

    func markVisited(_ tab: AppTab) {
        visitedTabs.insert(tab)
    }

    func select(tab: AppTab) {
        selectedTab = tab
        visitedTabs.insert(tab)
    }

    /// Re-tapping the current tab: wrapped sites return to their home URL (the
    /// native host animates the large title back), native tabs scroll to the top.
    func reselect(tab: AppTab) {
        guard selectedTab == tab else { return }
        tabReselectTarget = tab
        tabReselectToken &+= 1
        switch tab {
        case .portal:
            break
        case .learning:
            if !settings.nativeMoodleEnabled { browser(for: .moodle).returnHomeOrScrollToTop() }
        case .booking:
            if !settings.nativeBookingEnabled { browser(for: bookingSegment.site).returnHomeOrScrollToTop() }
        case .shuttle, .me:
            break
        }
    }

    func switchTo(_ site: SiteID) {
        if let segment = BookingSegment.segment(for: site) {
            bookingSegment = segment
        }
        select(tab: AppTab.tab(for: site))
    }

    func openSite(_ site: SiteID) {
        guard !isClearingData else { return }
        openWeb(site.homeURL, site: site)

    }

    func open(_ link: QuickLink) {
        guard let url = link.url else {
            toast(L10n.tr("链接无效"))
            return
        }
        openWeb(url, site: link.site, title: link.title)
    }

    /// One entry point for shortcuts, summaries and cross-site links.
    func openWeb(_ url: URL, site: SiteID, title: String? = nil) {
        guard !isClearingData, !lock.isLocked, url.scheme == "https",
              SiteID.site(for: url) == site else { return }
        Haptics.light()
        switchTo(site)
        if site == .portal || site == .serviceHub || (site == .moodle && settings.nativeMoodleEnabled) ||
            ((site == .rooms || site == .sports) && settings.nativeBookingEnabled) {
            pendingWebRoute = CampusWebRoute(site: site, url: url, title: title ?? site.displayName)
        } else { browser(for: site).load(url) }
    }

    // MARK: - 轻提示

    func toast(_ message: String) {
        toastText = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            self?.toastText = nil
        }
    }

    // MARK: - 网页数据

    func refreshStorageStates() async {
        var summaries: [SiteID: SiteStorageSummary] = [:]
        for site in SiteID.allCases { summaries[site] = await WebDataStoreRegistry.shared.summary(for: site) }
        storageSummaries = summaries
        storageStates = summaries.mapValues(\.hasData)
    }
    func clearData(for site: SiteID) async {
        campusSync.cancel()
        guard !isClearingData else { return }
        isClearingData = true
        defer { isClearingData = false }
        if site == .moodle { upcoming.cancel(clear: true); moodleAutoLogin.reset(); moodleAutoLoginStarted = false; pendingWebRoute = nil; settings.followedMoodleCourseIDs = [] }
        if site == .portal { exams.cancel(clear: true) }
        downloads.invalidateSession(for: site)
        if let browser = browsers[site], !(await browser.prepareForDataClear()) {
            browser.finishDataClear(dataCleared: false)
            toast(L10n.tr("网页尚未退出，数据清理未完成，请重试"))
            return
        }
        browsers[site]?.releaseDataStoreView()
        campusSync.clear(site)
        await WebDataStoreRegistry.shared.resetStore(for: site)
        settings.clearLocation(for: site)
        browsers[site]?.finishDataClear()
        await refreshStorageStates()
        if WebDataStoreRegistry.shared.pendingCleanupCount == 0 {
            toast(L10n.format("已清除「%@」的登录与网页数据", String(describing: site.displayName)))
        } else {
            toast(L10n.tr("登录数据已清除，旧缓存待释放后清理；可在存储空间中重试"))
        }
    }
    func clearAllData() async {
        guard !isClearingData else { return }
        isClearingData = true
        defer { isClearingData = false }
        campusSync.clear()
        upcoming.cancel(clear: true)
        moodleAutoLogin.reset(); moodleAutoLoginStarted = false; pendingWebRoute = nil; settings.followedMoodleCourseIDs = []
        exams.cancel(clear: true)
        var prepared: [BrowserModel] = []
        for site in SiteID.allCases {
            downloads.invalidateSession(for: site)
            if let browser = browsers[site] {
                prepared.append(browser)
                guard await browser.prepareForDataClear() else {
                    for browser in prepared { browser.finishDataClear(dataCleared: false) }
                    toast(L10n.tr("网页尚未退出，数据清理未完成，请重试"))
                    return
                }
            }
        }
        for browser in prepared { browser.releaseDataStoreView() }
        for site in SiteID.allCases {
            campusSync.clear(site)
        await WebDataStoreRegistry.shared.resetStore(for: site)
            browsers[site]?.finishDataClear()
        }
        settings.clearLocations()
        await refreshStorageStates()
        if WebDataStoreRegistry.shared.pendingCleanupCount == 0 {
            toast(L10n.tr("已清除全部站点的登录与网页数据"))
        } else {
            toast(L10n.tr("登录数据已清除，旧缓存待释放后清理；可在存储空间中重试"))
        }
    }
    func clearCaches() async {
        guard !isClearingData else { return }
        isClearingData = true
        defer { isClearingData = false }
        for site in SiteID.allCases {
            await WebDataStoreRegistry.shared.clearData(for: site, cacheOnly: true)
        }
        await refreshStorageStates()
        toast(L10n.tr("已清理现有缓存，登录数据保持不变"))
    }
}

// MARK: - BrowserRouter

extension AppModel: BrowserRouter {
    func browserWebDarkModeEnabled(for site: SiteID) -> Bool { settings.webDarkModeEnabled(for: site) }
    var browserDownloadCenter: DownloadCoordinator? { downloads }
    var externalLinkMode: ExternalLinkMode { settings.externalLinks }
    func browserInitialURL(for site: SiteID) -> URL { settings.initialURL(for: site) }
    var browserMayRecoverDocument: Bool { !lock.isLocked && lock.isActive && !isClearingData }
    func browserWillLogout(site: SiteID) {
        if site == .moodle {
            upcoming.cancel(clear: true); settings.followedMoodleCourseIDs = []
            refreshAfterMoodleLogin = true
        }
    }
    func browserDidFinish(url: URL, site: SiteID) {
        if let browser = browsers[site], !isClearingData { campusSync.observe(browser.webView, site: site) }
        if site == .rooms, url.host == site.host, ["/Web/reservation.php", "/Web/my-calendar.php"].contains(url.path) {
            refreshRoomCacheIfAllowed(force: true)
        }
        settings.remember(url, for: site)
        if site == .portal && (url.host != site.host || url.path.contains("login") || url.path.contains("logout")) { exams.cancel(clear: true) }
        if site == .moodle {
            if let browser = browsers[site] { upcoming.observeActivity(browser: browser) }
            if url.path.contains("/login/") {
                let loggingOut = url.path.contains("/logout.php")
                upcoming.cancel(clear: loggingOut)
                if loggingOut { settings.followedMoodleCourseIDs = [] }
                refreshAfterMoodleLogin = true
            } else if url.host == SiteID.moodle.host, !url.path.contains("/auth/"), refreshAfterMoodleLogin {
                refreshAfterMoodleLogin = false
                upcoming.sessionDidAuthenticate()
                refreshMoodleSummary()
            }
        }
    }
    func browserClearData(for site: SiteID) async { await clearData(for: site) }
    func browserDownload(_ download: WKDownload, webView: WKWebView, site: SiteID) {
        if site == .moodle { downloads.receiveForPreview(download, webView: webView, site: site) }
        else { downloads.track(download, webView: webView, site: site) }
    }
    func browserRouteToOtherSite(url: URL, from site: SiteID) {
        guard !isClearingData else { return }
        guard let target = SiteID.site(for: url), target != site else {
            browserOpenExternal(url: url)
            return
        }
        openWeb(url, site: target)
    }

    func browserOpenExternal(url: URL) {
        guard let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https" || NavigationPolicy.isExternalScheme(scheme), !lock.isLocked
        else { return }
        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            if !success { Task { @MainActor in self?.toast(L10n.tr("无法打开此链接，请确认已安装对应 App")) } }
        }
    }
    func browserOpenInAppSafari(url: URL) {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = UIColor(Theme.accent)
        _ = browserPresent(viewController: safari)
    }

    func browserPresentShare(items: [Any]) {
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activity.popoverPresentationController,
            let sourceView = TopViewController.current()?.view
        {
            popover.sourceView = sourceView
            popover.sourceRect = CGRect(
                x: sourceView.bounds.midX,
                y: sourceView.bounds.maxY - 60,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        _ = browserPresent(viewController: activity)
    }

    func browserPresent(viewController: UIViewController) -> Bool {
        guard !lock.isLocked, lock.isActive, !isClearingData, let top = TopViewController.current(),
            !top.isBeingDismissed,
            !top.isBeingPresented
        else { return false }
        top.present(viewController, animated: true)
        return true
    }

    func browserToast(_ message: String) {
        toast(message)
    }
}