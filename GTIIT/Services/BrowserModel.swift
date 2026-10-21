import Foundation
import UIKit
import WebKit

/// 单个站点的网页内核：WebView、状态、导航策略、下载与脚本面板。
///
/// 设计要点（对应研究结论）：
/// - 每站独立持久化数据容器，会话互不串；
/// - 新窗口（target=_blank）在主框架内打开，保证学校 SSO 流程可用；
/// - 跨站链接（门户 / Moodle / Booked / 体育 之间）交给 App 路由到对应 Tab；
/// - 非 http(s) scheme 交给系统 App；
/// - 下载型导航交给系统文件分享，App 不做持久化资料库。
@MainActor
final class BrowserModel: NSObject, ObservableObject {
    let site: SiteID
    @Published private(set) var webView: WKWebView

    @Published private(set) var pageTitle: String
    @Published private(set) var currentHost: String
    @Published private(set) var currentURLString: String
    @Published private(set) var progress: Double = 0
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var hasLoadedOnce = false
    @Published private(set) var errorText: String?

    private weak var router: BrowserRouter?
    private var observations: [NSKeyValueObservation] = []
    @Published private(set) var needsReloadAfterClear = false
    private var popups: [WKWebView] = []
    private var popupControllers: [ObjectIdentifier: UIViewController] = [:]
    private var mayRememberLocation = true
    private var isResetting = false

    init(site: SiteID, router: BrowserRouter) {
        self.site = site
        self.router = router
        self.pageTitle = site.displayName
        self.currentHost = site.host
        self.currentURLString = site.homeURLString

        self.webView = Self.makeWebView(site: site)
        super.init()

        configureWebView()
        load(router.browserInitialURL(for: site))
    }

    private static func makeWebView(site: SiteID) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WebDataStoreRegistry.shared.store(for: site)
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .audio
        configuration.preferences.isFraudulentWebsiteWarningEnabled = true
        return WKWebView(frame: .zero, configuration: configuration)
    }
    private func configureWebView() {
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.alwaysBounceVertical = true
        #if DEBUG
            webView.isInspectable = true
        #endif
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
        observeWebView()
    }
    /// 停止活动文档和弹窗；清空后替换内核，移除 BackForwardList 与页面内存。
    func prepareForDataClear() async {
        isResetting = true
        observations.removeAll()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.isHidden = true
        await DocumentTeardown().blank(webView)
        for popup in popups {
            await DocumentTeardown().blank(popup)
            popupControllers[ObjectIdentifier(popup)]?.dismiss(animated: false)
        }
        popups.removeAll()
        popupControllers.removeAll()
    }
    func finishDataClear() {
        webView.removeFromSuperview()
        webView = Self.makeWebView(site: site)
        pageTitle = site.displayName
        currentHost = site.host
        currentURLString = site.homeURLString
        progress = 0
        isLoading = false
        canGoBack = false
        canGoForward = false
        hasLoadedOnce = false
        errorText = nil
        needsReloadAfterClear = true
        isResetting = false
        configureWebView()
    }

    // MARK: - 对外操作

    var displayTitle: String {
        pageTitle.isEmpty ? site.displayName : pageTitle
    }

    var currentURL: URL? {
        webView.url ?? URL(string: currentURLString)
    }

    func loadHome() {
        load(site.homeURL)
    }

    func load(_ url: URL) {
        guard !isResetting else { return }
        needsReloadAfterClear = false
        mayRememberLocation = true
        errorText = nil
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.cachePolicy = .useProtocolCachePolicy
        webView.load(request)
    }

    func reload() {
        errorText = nil
        webView.reload()
    }

    func reloadFromOrigin() {
        errorText = nil
        webView.reloadFromOrigin()
    }

    func goBack() {
        if webView.canGoBack { webView.goBack() }
    }

    func goForward() {
        if webView.canGoForward { webView.goForward() }
    }

    func shareCurrentPage() {
        guard let url = currentURL else { return }
        router?.browserPresentShare(items: [url, displayTitle])
    }

    func openInSystemBrowser() {
        guard let url = currentURL else { return }
        router?.browserOpenExternal(url: url)
    }

    func openInAppSafari() {
        guard let url = currentURL, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        router?.browserOpenInAppSafari(url: url)
    }
    func clearSiteData() async { await router?.browserClearData(for: site) }

    @objc private func handlePullToRefresh() {
        webView.reload()
    }

    // MARK: - KVO

    private func observeWebView() {
        observations.append(
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] view, _ in
                let value = view.estimatedProgress
                self?.onMain { [weak self] in self?.progress = value }
            })

        observations.append(
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] view, _ in
                let value = view.isLoading
                self?.onMain { [weak self] in self?.isLoading = value }
            })

        observations.append(
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] view, _ in
                let value = view.canGoBack
                self?.onMain { [weak self] in self?.canGoBack = value }
            })

        observations.append(
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] view, _ in
                let value = view.canGoForward
                self?.onMain { [weak self] in self?.canGoForward = value }
            })

        observations.append(
            webView.observe(\.title, options: [.initial, .new]) { [weak self] view, _ in
                let title = view.title ?? ""
                self?.onMain { [weak self] in
                    guard let self else { return }
                    self.pageTitle = title.isEmpty ? self.site.displayName : title
                }
            })

        observations.append(
            webView.observe(\.url, options: [.initial, .new]) { [weak self] view, _ in
                let absoluteString = view.url?.absoluteString
                let host = view.url?.host
                self?.onMain { [weak self] in
                    guard let self else { return }
                    self.currentURLString = absoluteString ?? self.site.homeURLString
                    self.currentHost = host ?? self.site.host
                }
            })
    }

    /// WebKit 的 KVO 通常在主线投递，但没有 API 契约保证。
    /// 主线程同步写回；万一不在主线程就异步回主队列，避免 `assumeIsolated` 直接崩溃。
    nonisolated private func onMain(_ body: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { body() }
        } else {
            Task { @MainActor in body() }
        }
    }

    // MARK: - 错误文案

    private func handleNavigationError(_ error: Error) {
        isLoading = false
        webView.scrollView.refreshControl?.endRefreshing()

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        errorText = Self.friendlyMessage(for: nsError, site: site)
    }

    static func friendlyMessage(for error: NSError, site: SiteID) -> String {
        guard error.domain == NSURLErrorDomain else {
            return "页面加载失败：\(error.localizedDescription)"
        }
        switch error.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return "没有可用的网络连接。请确认已连接校园网或蜂窝网络后重试。"
        case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
            return "无法解析 \(site.host)。校园站点需要校内网络或学校的访问方式，公共网络下可能解析失败。"
        case NSURLErrorTimedOut:
            return "连接超时。校园站点在校外可能需要较长时间，请稍后重试。"
        case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted:
            return "安全连接未建立（证书校验失败）。App 不会绕过证书校验，请检查网络环境。"
        case NSURLErrorCannotConnectToHost:
            return "无法连接到 \(site.host)。请确认是否需要校园网或学校 VPN。"
        default:
            return "页面加载失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - WKNavigationDelegate

extension BrowserModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard webView === self.webView else { return }
        isLoading = true
        errorText = nil
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard webView === self.webView else { return }
        errorText = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === self.webView else { return }
        isLoading = false
        hasLoadedOnce = true
        if webView === self.webView, mayRememberLocation, let url = webView.url {
            router?.browserDidFinish(url: url, site: site)
        }
        webView.scrollView.refreshControl?.endRefreshing()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if webView === self.webView { handleNavigationError(error) }
    }

    func webView(
        _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error
    ) {
        if webView === self.webView { handleNavigationError(error) }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard webView === self.webView else {
            closePopup(webView)
            return
        }
        isLoading = false
        errorText = "页面进程已被系统回收。请重新载入；尚未提交的内容可能需要重新填写。"
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard !isResetting else {
            decisionHandler(.cancel)
            return
        }
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "http" || scheme == "https" {
            if navigationAction.targetFrame?.isMainFrame != false {
                let method = (navigationAction.request.httpMethod ?? "GET").uppercased()
                if method != "GET" {
                    mayRememberLocation = false
                } else if navigationAction.navigationType == .linkActivated {
                    mayRememberLocation = true
                }
            }
            // 弹窗必须保留 opener、window 引用和配置；交给 createWebView 实际创建。
            if webView === self.webView, navigationAction.targetFrame != nil,
                NavigationPolicy.canRoute(navigationAction), !NavigationPolicy.isAuthentication(url)
            {
                if let target = SiteID.site(for: url), target != site {
                    router?.browserRouteToOtherSite(url: url, from: site)
                    decisionHandler(.cancel)
                    return
                }
                if SiteID.site(for: url) == nil {
                    switch router?.externalLinkMode ?? .webView {
                    case .webView: break
                    case .safariView:
                        router?.browserOpenInAppSafari(url: url)
                        decisionHandler(.cancel)
                        return
                    case .systemBrowser:
                        router?.browserOpenExternal(url: url)
                        decisionHandler(.cancel)
                        return
                    }
                }
            }
            decisionHandler(.allow)
            return
        }
        if NavigationPolicy.isInternalScheme(scheme) {
            decisionHandler(.allow)
            return
        }
        if NavigationPolicy.isExternalScheme(scheme), navigationAction.navigationType == .linkActivated {
            router?.browserOpenExternal(url: url)
        } else {
            router?.browserToast("此链接类型暂不支持，请使用默认浏览器打开原页面")
        }
        decisionHandler(.cancel)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        let response = navigationResponse.response as? HTTPURLResponse
        let disposition = response?.value(forHTTPHeaderField: "Content-Disposition")?.lowercased() ?? ""
        if navigationResponse.isForMainFrame
            && (!navigationResponse.canShowMIMEType || disposition.hasPrefix("attachment"))
        {
            decisionHandler(.download)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        router?.browserDownload(download, webView: webView, site: site)
    }

    func webView(
        _ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload
    ) {
        router?.browserDownload(download, webView: webView, site: site)
    }
}

// MARK: - WKUIDelegate（新窗口、JS 面板、文件选择）

extension BrowserModel: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard !isResetting, popups.count < 4 else {
            router?.browserToast("请先关闭已打开的网页窗口")
            return nil
        }
        let popup = WKWebView(frame: .zero, configuration: configuration)
        popup.navigationDelegate = self
        popup.uiDelegate = self
        popup.allowsBackForwardNavigationGestures = true
        let controller = PopupBrowserController(webView: popup)
        controller.onClose = { [weak self, weak popup] in
            guard let popup else { return }
            self?.closePopup(popup)
        }
        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .fullScreen
        guard present(navigation) else { return nil }
        popups.append(popup)
        popupControllers[ObjectIdentifier(popup)] = navigation
        return popup
    }
    func webViewDidClose(_ webView: WKWebView) { closePopup(webView) }
    private func closePopup(_ webView: WKWebView) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        popupControllers.removeValue(forKey: ObjectIdentifier(webView))?.dismiss(animated: true)
        popups.removeAll { $0 === webView }
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let kind: String
        switch type {
        case .camera: kind = "摄像头"
        case .microphone: kind = "麦克风"
        case .cameraAndMicrophone: kind = "摄像头和麦克风"
        @unknown default: kind = "录制设备"
        }
        router?.browserToast("网页请求使用\(kind)；本 App 不开放该权限")
        decisionHandler(.deny)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: displayTitle, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
        guard present(alert) else {
            completionHandler()
            return
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: displayTitle, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler(true) })
        guard present(alert) else {
            completionHandler(false)
            return
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = UIAlertController(title: displayTitle, message: prompt, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = defaultText
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(
            UIAlertAction(title: "确定", style: .default) { [weak alert] _ in
                completionHandler(alert?.textFields?.first?.text)
            })
        guard present(alert) else {
            completionHandler(nil)
            return
        }
    }

    @discardableResult
    private func present(_ controller: UIViewController) -> Bool {
        guard let router else { return false }
        return router.browserPresent(viewController: controller)
    }
}
