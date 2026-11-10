import WidgetKit
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
    @Published var nativePath: [CampusDetail] = []
    @Published private(set) var storageStates: [SiteID: Bool] = [:]
    @Published private(set) var tabReselectToken = 0
    @Published private(set) var tabReselectTarget: AppTab?

    @Published private(set) var contextMenuSource: String?
    func showContextMenu(_ source: String) { contextMenuSource = source }
    func hideContextMenu(_ source: String) { if contextMenuSource == source { contextMenuSource = nil } }

    let messages = CampusMessageStore()
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
    private var backgroundMoodleToken: UUID?
    private let summaryRouter = BackgroundMoodleRouter()
    @Published private(set) var summaryBrowser: BrowserModel?

    private var browsers: [SiteID: BrowserModel] = [:]
    private var toastTask: Task<Void, Never>?

    init(settings: AppSettings? = nil) {
        let settings = settings ?? AppSettings()
        self.settings = settings
        messages.connect(sync: campusSync)
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
        campusSync.onSignedIn = { [weak self] site in
            if site == .moodle { self?.moodleAutoLogin.sessionDidAuthenticate() }
        }
        exams.onReminderSnapshot = { [weak self] in self?.syncMoodleDeadlineReminders() }
        upcoming.onReminderSnapshot = { [weak self] in self?.syncMoodleDeadlineReminders() }
        upcoming.onClearReminders = { [weak self] in self?.summaryBrowser?.webView.stopLoading(); self?.summaryBrowser = nil; AppGroup.defaults.removeObject(forKey: StudyWidgetSnapshot.key); WidgetCenter.shared.reloadTimelines(ofKind: "StudyHomeWidget"); MoodleDeadlineReminders.shared.clear(); Task { @MainActor [weak self] in await Task.yield(); self?.syncMoodleDeadlineReminders() } }
        ShuttleNotificationCenter.shared.onMessage = { [weak self] in self?.messages.ingest($0) }
        ShuttleNotificationCenter.shared.onOpenStudy = { [weak self] examOnly in self?.openNativeDetail(examOnly ? .exams : .assignments) }
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
        #if DEBUG
        if url.host == "activity-review" {
            let kind = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "kind" }?.value ?? "course"
            Task { await ActivityReviewLauncher.run(kind: kind) }
            return
        }
        #endif
        if ["study", "assignments", "timetable", "exams"].contains(url.host ?? "") {
            let destination: CampusDetail = url.host == "timetable" ? .timetable : url.host == "exams" ? .exams : .assignments
            openNativeDetail(destination)
            return
        }
        guard url.host == "shuttle" else { return }
        select(tab: .shuttle)
        if let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "direction" })?.value,
            let direction = ShuttleDirection(rawValue: raw) {
            settings.favoriteShuttleDirection = direction
        }
    }

    func openMailAssistant() {
        guard let url = URL(string: "ms-outlook://") else { return }
        UIApplication.shared.open(url) { success in
            if !success, let web = URL(string: "https://outlook.office.com/mail/") { UIApplication.shared.open(web) }
        }
    }

    func openNativeDetail(_ destination: CampusDetail) {
        select(tab: .me)
        nativePath = [destination]
    }

    func refreshMessageEvents(now: Date = Date()) {
        messages.recordStudy(works: settings.moodleDeadlineRemindersEnabled ? upcoming.items : [],
            exams: settings.examRemindersEnabled ? exams.items : [], days: settings.moodleReminderLead.rawValue / 24,
            hour: settings.studyReminderHour, now: now)
        messages.recordReservations(campusSync.reservations, now: now)
    }
    func openMessage(_ message: CampusMessage) {
        switch message.destination {
        case .study: openNativeDetail(.assignments)
        case .exams: openNativeDetail(.exams)
        case .assignments:
            if let raw = message.value, let url = MoodleWork.safeURL(raw) { openWeb(url, site: .moodle) }
            else { openNativeDetail(.assignments) }
        case .reservation:
            if let raw = message.value, let url = CachedRoomReservation.safeURL(raw) { openWeb(url, site: .rooms) }
        case .login:
            if let raw = message.value, let site = SiteID(rawValue: raw) { openSite(site) }
        case .shuttle:
            select(tab: .shuttle)
            if let raw = message.value, let direction = ShuttleDirection(rawValue: raw) { settings.favoriteShuttleDirection = direction }
        }
    }
    func syncMoodleDeadlineReminders() {
        refreshMessageEvents()
        if AppGroup.isAvailable {
            AppGroup.defaults.set(settings.language.rawValue, forKey: AppGroup.Key.language)
            let snapshot = StudyWidgetSnapshot(items: upcoming.items.map {
                .init(id: $0.id, course: StudyWidgetSnapshot.courseName($0.course), title: $0.displayName,
                      due: $0.dueDate, pending: ["notSubmitted", "draft"].contains($0.status))
            }, updatedAt: upcoming.updatedAt, verified: upcoming.updatedAt != nil && !upcoming.loginRequired && !upcoming.partial && !upcoming.error && !upcoming.items.contains(where: { $0.status == "unknown" && $0.relevant(days: settings.moodleUpcomingRange.rawValue) }), days: settings.moodleUpcomingRange.rawValue)
            AppGroup.defaults.set(try? JSONEncoder().encode(snapshot), forKey: StudyWidgetSnapshot.key)
            WidgetCenter.shared.reloadTimelines(ofKind: "StudyHomeWidget")
        }
        var canRequest = settings.hasSeenWelcome && !showWelcome && !lock.isLocked && lock.isActive
            && !isClearingData && UIApplication.shared.applicationState == .active
        #if GTIIT_REGRESSION
        canRequest = false
        #endif
        StudyDailyReminders.shared.update(works: settings.moodleDeadlineRemindersEnabled ? upcoming.items : [],
            exams: settings.examRemindersEnabled ? exams.items : [], days: settings.moodleReminderLead.rawValue / 24, hour: settings.studyReminderHour, allowPermissionRequest: canRequest, allowEmptySummary: settings.moodleDeadlineRemindersEnabled && upcoming.status == .current)
        MoodleDeadlineReminders.shared.update(items: upcoming.items, updatedAt: upcoming.updatedAt,
            partial: upcoming.partial, enabled: false, allowPermissionRequest: canRequest, lead: settings.moodleReminderLead)
    }

    func restoreStudyCaches() {
        timetable.restoreCachedSnapshot()
        upcoming.restoreCachedSnapshot()
    }

    func refreshMoodleSummary(force: Bool = false, onOpen: Bool = false) {
        #if DEBUG
        if ProcessInfo.processInfo.environment["UI_REVIEW_INBOX"] == "1" || ProcessInfo.processInfo.environment["UI_REVIEW_MOODLE_CACHE"] == "1" { return }
        #endif
        restoreStudyCaches()
        upcoming.upcomingDays = settings.moodleUpcomingRange.rawValue
        upcoming.priorityCourseIDs = Set(upcoming.courseItems.filter { $0.matches(timetable.snapshot) }.map(\.id))
            .union(settings.followedMoodleCourseIDs)
        if summaryBrowser == nil { summaryBrowser = BrowserModel(site: .moodle, router: summaryRouter) }
        guard let reader = summaryBrowser else { return }
        if reader.hasLoadedOnce && !reader.isLoading,
           reader.currentURL?.host != SiteID.moodle.host || reader.currentURL?.path.contains("/login/") == true {
            reader.loadHome()
        }
        if upcoming.error && !reader.isLoading { reader.loadHome() }
        let started = upcoming.refresh(browser: reader, force: force || onOpen, refreshDetails: !onOpen) { [weak self] in
            guard let self else { return false }
            return !self.lock.isLocked && self.lock.isActive && !self.isClearingData
        }
        if force && started == nil && !upcoming.refreshing { toast(L10n.tr("请稍后重试更新")) }
    }

    /// A separate read-only WebKit host shares only Moodle's existing store.
    /// Never interact with login forms or the user's visible browser.
    func refreshMoodleInBackground() async -> Bool {
        let allowed: () -> Bool = { [weak self] in
            guard let self else { return false }
            return UIApplication.shared.applicationState == .background && UIApplication.shared.isProtectedDataAvailable
                && self.settings.hasSeenWelcome && !self.settings.biometricLockEnabled
                && !self.lock.isLocked && !self.isClearingData && !self.showWelcome
        }
        guard allowed(), !upcoming.refreshing, !Task.isCancelled else { return false }
        if let updatedAt = upcoming.updatedAt, upcoming.status == .current,
           Date().timeIntervalSince(updatedAt) < MoodleUpcomingStore.refreshInterval { return true }
        upcoming.upcomingDays = settings.moodleUpcomingRange.rawValue
        upcoming.priorityCourseIDs = Set(upcoming.courseItems.filter { $0.matches(timetable.snapshot) }.map(\.id))
            .union(settings.followedMoodleCourseIDs)
        let router = BackgroundMoodleRouter()
        let browser = BrowserModel(site: .moodle, router: router)
        // BrowserModel holds its router weakly; keep the read-only policy alive
        // until WebKit has stopped, including on cancellation.
        defer { browser.webView.stopLoading(); withExtendedLifetime(router) {} }
        guard let token = upcoming.refresh(browser: browser, background: true, allowed: allowed) else { return false }
        backgroundMoodleToken = token
        defer { if backgroundMoodleToken == token { backgroundMoodleToken = nil } }
        return await withTaskCancellationHandler {
            await upcoming.waitForRefresh(token)
        } onCancel: { [weak self] in
            Task { @MainActor in self?.upcoming.cancelRefresh(token) }
        }
    }
    func cancelBackgroundMoodleRefresh() {
        if let token = backgroundMoodleToken { upcoming.cancelRefresh(token); backgroundMoodleToken = nil }
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
        messages.clear()
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

@MainActor private final class BackgroundMoodleRouter: BrowserRouter {
    var externalLinkMode: ExternalLinkMode { .webView }
    var browserMayRecoverDocument: Bool { false }
    func browserWebDarkModeEnabled(for site: SiteID) -> Bool { false }
    func browserInitialURL(for site: SiteID) -> URL { site.homeURL }
    func browserDidFinish(url: URL, site: SiteID) {}
    func browserRouteToOtherSite(url: URL, from site: SiteID) {}
    func browserOpenExternal(url: URL) {}
    func browserOpenInAppSafari(url: URL) {}
    func browserPresentShare(items: [Any]) {}
    func browserPresent(viewController: UIViewController) -> Bool { false }
    func browserToast(_ message: String) {}
    func browserDownload(_ download: WKDownload, webView: WKWebView, site: SiteID) { download.cancel(nil) }
    func browserClearData(for site: SiteID) async {}
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
        if site == .portal && (url.host != site.host || url.path.contains("login") || url.path.contains("logout")) { exams.cancel(clear: url.path.contains("logout")) }
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
