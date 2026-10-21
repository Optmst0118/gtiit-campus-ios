import SwiftUI
import SafariServices
import UIKit

/// 应用级状态：Tab 选择、四个站点的网页内核、跨站路由、轻提示与外部呈现。
@MainActor
final class AppModel: ObservableObject {
    @Published var selectedTab: AppTab = .portal
    @Published var bookingSegment: BookingSegment = .rooms
    @Published var visitedTabs: Set<AppTab> = [.portal]
    @Published var toastText: String?
    @Published var showWelcome = false
    @Published var siteInfo: SiteID?
    @Published private(set) var storageStates: [SiteID: Bool] = [:]

    let lock = AppLockController()

    private var browsers: [SiteID: BrowserModel] = [:]
    private var toastTask: Task<Void, Never>?

    init() {
        Self.resetTemporaryDownloads()
    }

    /// 下载文件只在当次分享时使用；每次启动清掉上一次的临时文件，避免占用空间。
    private static func resetTemporaryDownloads() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GTIITDownloads", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
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

    func switchTo(_ site: SiteID) {
        if let segment = BookingSegment.segment(for: site) {
            bookingSegment = segment
        }
        select(tab: AppTab.tab(for: site))
    }

    func openSite(_ site: SiteID) {
        switchTo(site)
        let browser = self.browser(for: site)
        if browser.webView.url == nil {
            browser.loadHome()
        }
        toast("已打开「\(site.displayName)」")
    }

    func open(_ link: QuickLink) {
        guard let url = link.url else {
            toast("链接无效")
            return
        }
        switchTo(link.site)
        browser(for: link.site).load(url)
        toast("正在打开「\(link.title)」")
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
        var result: [SiteID: Bool] = [:]
        for site in SiteID.allCases {
            result[site] = await WebDataStoreRegistry.shared.hasStoredData(for: site)
        }
        storageStates = result
    }

    func clearData(for site: SiteID) async {
        await WebDataStoreRegistry.shared.clearData(for: site)
        browsers[site]?.loadHome()
        await refreshStorageStates()
        toast("已清除「\(site.displayName)」的网页数据")
    }

    func clearAllData() async {
        for site in SiteID.allCases {
            await WebDataStoreRegistry.shared.clearData(for: site)
            browsers[site]?.loadHome()
        }
        await refreshStorageStates()
        toast("已清除全部站点的网页数据")
    }
}

// MARK: - BrowserRouter

extension AppModel: BrowserRouter {
    func browserRouteToOtherSite(url: URL, from site: SiteID) {
        guard let target = SiteID.site(for: url), target != site else {
            browserOpenExternal(url: url)
            return
        }
        switchTo(target)
        browser(for: target).load(url)
        toast("已跳转到「\(target.displayName)」")
    }

    func browserOpenExternal(url: URL) {
        guard let scheme = url.scheme?.lowercased() else { return }
        if scheme == "http" || scheme == "https" {
            let safari = SFSafariViewController(url: url)
            safari.preferredControlTintColor = UIColor(Theme.accent)
            _ = browserPresent(viewController: safari)
        } else {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    func browserPresentShare(items: [Any]) {
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activity.popoverPresentationController, let sourceView = TopViewController.current()?.view {
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
        guard let top = TopViewController.current() else { return false }
        top.present(viewController, animated: true)
        return true
    }

    func browserToast(_ message: String) {
        toast(message)
    }
}