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
    /// Booking shortcuts target an exact official page; the native booking home
    /// picks this up and presents it in the in-app web sheet.
    @Published var pendingBookingLink: QuickLink?
    @Published var pendingMoodleURL: URL?
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
    let exams = StudentExamStore()
    let yilong = YilongController()
    let lock = AppLockController()
    let launch = LaunchPreparation()
    let downloads = DownloadCoordinator()
    let privacyShield = PrivacyShieldController()
    let settings: AppSettings
    @Published private(set) var isClearingData = false
    @Published private(set) var storageSummaries: [SiteID: SiteStorageSummary] = [:]
    private var lockSubscription: AnyCancellable?
    private var appearanceSubscription: AnyCancellable?
    private var launchSubscription: AnyCancellable?

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
                if self.lock.isLocked || !self.lock.isActive { self.upcoming.cancel(); self.exams.cancel(); self.contextMenuSource = nil }
            }
        }
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
        ShuttleNotificationCenter.shared.onOpen = { [weak self] direction in
            guard let self else { return }
            self.select(tab: .shuttle)
            if let direction { self.settings.favoriteShuttleDirection = direction }
        }
    }

    /// Handles gtiit://shuttle[?direction=north|south] from a widget or notification.
    func handleShuttleURL(_ url: URL) {
        guard url.scheme == "gtiit", url.host == "shuttle" else { return }
        select(tab: .shuttle)
        if let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "direction" })?.value,
            let direction = ShuttleDirection(rawValue: raw) {
            settings.favoriteShuttleDirection = direction
        }
    }

    private func warmUpCampusSummaries() {
        let allowed: () -> Bool = { [weak self] in
            guard let self else { return false }
            return !self.lock.isLocked && self.lock.isActive && !self.isClearingData
        }
        upcoming.refresh(browser: browser(for: .moodle), allowed: allowed)
        exams.refresh(allowed: allowed)
    }

    func prepareLaunchIfAllowed() {
        guard settings.hasSeenWelcome, !showWelcome, !lock.isLocked, lock.isActive else { return }
        // Kick both campus summaries off with launch, not only when My appears;
        // their progress is then already visible on the first visit.
        warmUpCampusSummaries()
        guard settings.preloadSitesOnLaunch else { launch.skip(); return }
        guard !launch.hasStarted, !launch.didFinish else { return }
        launch.start(models: SiteID.allCases.map { browser(for: $0) }, canRestoreSession: { [weak self] in
            guard let self else { return false }
            return !self.lock.isLocked && self.lock.isActive && !self.isClearingData
        })
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
            browser(for: .portal).loadHome()
        case .learning:
            browser(for: .moodle).loadHome()
        case .booking:
            browser(for: bookingSegment.site).loadHome()
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
        switchTo(site)
        let browser = self.browser(for: site)
        if browser.webView.url == nil {
            browser.loadHome()
        }
        toast(L10n.format("已打开「%@」", String(describing: site.displayName)))
    }

    func open(_ link: QuickLink) {
        guard let url = link.url else {
            toast(L10n.tr("链接无效"))
            return
        }
        switchTo(link.site)
        if link.site == .moodle, settings.nativeMoodleEnabled {
            pendingMoodleURL = url
        } else if (link.site == .rooms || link.site == .sports), settings.nativeBookingEnabled {
            pendingBookingLink = link
        } else {
            browser(for: link.site).load(url)
        }
        toast(L10n.format("正在打开「%@」", String(describing: link.title)))
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
        guard !isClearingData else { return }
        isClearingData = true
        defer { isClearingData = false }
        if site == .moodle { upcoming.cancel(clear: true) }
        if site == .portal { exams.cancel(clear: true) }
        downloads.invalidateSession(for: site)
        if let browser = browsers[site], !(await browser.prepareForDataClear()) {
            browser.finishDataClear(dataCleared: false)
            toast(L10n.tr("网页尚未退出，数据清理未完成，请重试"))
            return
        }
        browsers[site]?.releaseDataStoreView()
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
        upcoming.cancel(clear: true)
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
    func browserDidFinish(url: URL, site: SiteID) {
        settings.remember(url, for: site)
        if site == .portal && (url.host != site.host || url.path.contains("login") || url.path.contains("logout")) { exams.cancel(clear: true) }
        if site == .moodle {
            if url.path.contains("/login/") || url.path.contains("/auth/") { upcoming.cancel(clear: true) }

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
        switchTo(target)
        browser(for: target).load(url)
        toast(L10n.format("已跳转到「%@」", String(describing: target.displayName)))
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