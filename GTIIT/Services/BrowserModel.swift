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
    private var processTerminated = false
    private var canRecoverReadOnlyDocument = false
    private var documentEdited = false
    private var lastAutomaticRecovery: Date?
    private var navigationGeneration = UUID()

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
        configuration.userContentController.addUserScript(
            WKUserScript(source: Self.viewportLockScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        return WKWebView(frame: .zero, configuration: configuration)
    }
    func applyWebAppearance() {
        let enabled = router?.browserWebDarkModeEnabled(for: site) ?? true
        WebAppearance.update(webView, enabled: enabled)
        for popup in popups { WebAppearance.update(popup, enabled: enabled) }
    }
    private func configureWebView() {
        WebAppearance.install(on: webView.configuration, enabled: router?.browserWebDarkModeEnabled(for: site) ?? true)
        webView.isOpaque = false
        webView.backgroundColor = Theme.pageUIColor
        webView.scrollView.backgroundColor = Theme.pageUIColor
        webView.navigationDelegate = self
        webView.uiDelegate = self
        let edits = BrowserEditObserver(owner: self)
        webView.configuration.userContentController.add(edits, contentWorld: .defaultClient, name: "gtiitDocumentEdited")
        webView.configuration.userContentController.addUserScript(WKUserScript(source: """
            (() => {
                let reported = false;
                const edited = event => {
                    if (!event.isTrusted || reported) return;
                    reported = true;
                    window.webkit.messageHandlers.gtiitDocumentEdited.postMessage(true);
                };
                document.addEventListener('input', edited, true);
                document.addEventListener('change', edited, true);
            })();
            """, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .defaultClient))
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.alwaysBounceVertical = true
        Self.restrictScrolling(webView)
        #if DEBUG
            webView.isInspectable = true
        #endif
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
        observeWebView()
    }
    // MARK: - 缩放与滚动限制

    /// 只允许上下滚动：禁用双指捏合、双击缩放与缩放回弹，并锁定横向拖动。
    static func restrictScrolling(_ webView: WKWebView) {
        let scrollView = webView.scrollView
        scrollView.isDirectionalLockEnabled = true
        scrollView.bouncesZoom = false
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 1
        if scrollView.zoomScale != 1 { scrollView.zoomScale = 1 }
        scrollView.pinchGestureRecognizer?.isEnabled = false
        disableZoomGestures(in: scrollView)
        disableZoomGestures(in: webView)
    }

    private static func disableZoomGestures(in view: UIView) {
        for recognizer in view.gestureRecognizers ?? [] {
            if let tap = recognizer as? UITapGestureRecognizer, tap.numberOfTapsRequired >= 2 {
                tap.isEnabled = false
            }
            if recognizer is UIPinchGestureRecognizer { recognizer.isEnabled = false }
        }
        for subview in view.subviews { disableZoomGestures(in: subview) }
    }

    /// 覆盖网页 viewport，避免页面自行声明可缩放。
    static let viewportLockScript = """
    (() => {
        const content = 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no';
        let meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
            meta = document.createElement('meta');
            meta.name = 'viewport';
            document.head.appendChild(meta);
        }
        meta.setAttribute('content', content);
    })();
    """

    /// 停止活动文档和弹窗；清空后替换内核，移除 BackForwardList 与页面内存。
    func prepareForDataClear() async -> Bool {
        isResetting = true
        observations.removeAll()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.isHidden = true
        let mainFinished = await DocumentTeardown().blank(webView)
        var popupsFinished = true
        for popup in popups {
            let finished = await DocumentTeardown().blank(popup)
            popupsFinished = popupsFinished && finished
            popupControllers[ObjectIdentifier(popup)]?.dismiss(animated: false)
        }
        popups.removeAll()
        popupControllers.removeAll()
        return mainFinished && popupsFinished
    }
    /// 移除对旧持久化容器的最后一个视图引用，允许 WebKit 删除整个旧容器。
    func releaseDataStoreView() {
        webView.removeFromSuperview()
        let placeholder = WKWebViewConfiguration()
        placeholder.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: placeholder)
    }
    func finishDataClear(dataCleared: Bool = true) {
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
        needsReloadAfterClear = dataCleared
        if !dataCleared { errorText = L10n.tr("未能安全退出旧页面，网页数据尚未清除。请在设置中重试。") }
        isResetting = false
        configureWebView()
    }

    // MARK: - 对外操作

    var displayTitle: String {
        pageTitle.isEmpty ? site.displayName : pageTitle
    }

    var canOpenInExternalBrowser: Bool { ["http", "https"].contains(currentURL?.scheme?.lowercased() ?? "") }
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
        if processTerminated {
            processTerminated = false
            // Do not replay a POST, one-time link or form submission after a crash.
            if mayRememberLocation, let url = currentURL, AppSettings.restorable(url, site: site) { load(url) }
            else { loadHome() }
            return
        }
        errorText = nil
        if webView.url == nil { loadHome() } else { webView.reload() }
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

    private func popupController(for webView: WKWebView) -> PopupBrowserController? {
        (popupControllers[ObjectIdentifier(webView)] as? UINavigationController)?.viewControllers.first as? PopupBrowserController
    }
    private func showLoadFailure(_ message: String, in failedView: WKWebView) {
        if failedView === webView {
            isLoading = false
            errorText = message
            failedView.scrollView.refreshControl?.endRefreshing()
        } else {
            popupController(for: failedView)?.showFailure(site: site, message: message,
                openSafari: { [weak self, weak failedView] in
                    guard let self else { return }
                    self.router?.browserOpenExternal(url: failedView?.url ?? self.site.homeURL)
                })
        }
    }
    private func handleNavigationError(_ error: Error, in failedView: WKWebView) {
        if failedView === webView {
            isLoading = false
            failedView.scrollView.refreshControl?.endRefreshing()
        }
        // A deliberate policy cancellation must not erase an HTTP error already shown.
        let nsError = error as NSError
        guard !NavigationPolicy.isExpectedInterruption(nsError) else { return }
        showLoadFailure(Self.friendlyMessage(for: nsError, site: site), in: failedView)
    }

    static func friendlyMessage(for error: NSError, site: SiteID) -> String {
        guard error.domain == NSURLErrorDomain else {
            return L10n.format("页面加载失败：%@", String(describing: error.localizedDescription))
        }
        switch error.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return L10n.tr("没有可用的网络连接。请确认已连接校园网或蜂窝网络后重试。")
        case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
            return L10n.format("无法解析 %@。校园站点需要校内网络或学校的访问方式，公共网络下可能解析失败。", String(describing: site.host))
        case NSURLErrorTimedOut:
            return L10n.tr("连接超时。校园站点在校外可能需要较长时间，请稍后重试。")
        case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted:
            return L10n.tr("安全连接未建立（证书校验失败）。App 不会绕过证书校验，请检查网络环境。")
        case NSURLErrorCannotConnectToHost:
            return L10n.format("无法连接到 %@。请确认是否需要校园网或学校 VPN。", String(describing: site.host))
        default:
            return L10n.format("页面加载失败：%@", String(describing: error.localizedDescription))
        }
    }
}

// MARK: - WKNavigationDelegate

extension BrowserModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        router?.browserDownloadCenter?.dismissCompletedPresentation()
        guard webView === self.webView else { popupController(for: webView)?.dismissFailure(); return }
        isLoading = true
        errorText = nil
        navigationGeneration = UUID()
        documentEdited = false
        canRecoverReadOnlyDocument = false
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard webView === self.webView else { return }
        errorText = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Self.restrictScrolling(webView)
        guard webView === self.webView else { return }
        isLoading = false
        hasLoadedOnce = true
        processTerminated = false
        let generation = navigationGeneration
        webView.evaluateJavaScript("!document.querySelector('form,input:not([type=hidden]),textarea,select,[contenteditable=true]')", in: nil, in: .defaultClient) { [weak self] result in
            guard let self, self.navigationGeneration == generation else { return }
            if case .success(let value) = result { self.canRecoverReadOnlyDocument = value as? Bool == true && !self.documentEdited }
        }
        if webView === self.webView, mayRememberLocation, let url = webView.url {
            router?.browserDidFinish(url: url, site: site)
        }
        webView.scrollView.refreshControl?.endRefreshing()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error, in: webView)
    }

    func webView(
        _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error
    ) {
        handleNavigationError(error, in: webView)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard !isResetting else { return }
        if webView === self.webView { processTerminated = true }
        showLoadFailure(L10n.tr("页面进程已被系统回收。请重新载入；尚未提交的内容可能需要重新填写。"), in: webView)
        recoverReadOnlyDocumentIfNeeded()
    }

    func documentWasEdited() { documentEdited = true; canRecoverReadOnlyDocument = false }

    func recoverReadOnlyDocumentIfNeeded() {
        guard processTerminated, canRecoverReadOnlyDocument, !isResetting,
              router?.browserMayRecoverDocument == true,
              UIApplication.shared.applicationState == .active, webView.window != nil,
              lastAutomaticRecovery.map({ Date().timeIntervalSince($0) >= 60 }) != false,
              mayRememberLocation, let url = currentURL, AppSettings.restorable(url, site: site) else { return }
        lastAutomaticRecovery = Date()
        reload()
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
        if navigationAction.navigationType == .linkActivated || navigationAction.navigationType == .formSubmitted {
            router?.browserDownloadCenter?.dismissCompletedPresentation()
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
            router?.browserToast(L10n.tr("此链接类型暂不支持，请使用默认浏览器打开原页面"))
        }
        decisionHandler(.cancel)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        let response = navigationResponse.response as? HTTPURLResponse
        if navigationResponse.isForMainFrame, let status = response?.statusCode, status >= 400 {
            showLoadFailure(L10n.format("网站返回 HTTP %@，请检查校园网络或稍后重试。", String(status)), in: webView)
            decisionHandler(.cancel)
            return
        }
        let disposition = response?.value(forHTTPHeaderField: "Content-Disposition")?.lowercased() ?? ""
        let isPDF = navigationResponse.response.mimeType?.lowercased() == "application/pdf"
        // 使用当前响应直接下载，保留 POST、一次性链接、Cookie 及 blob 的原始内容；不额外发 GET。
        if isPDF || navigationResponse.isForMainFrame
            && (!navigationResponse.canShowMIMEType || disposition.hasPrefix("attachment"))
        {
            decisionHandler(.download)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        finishDownloadNavigation(webView)
        router?.browserDownload(download, webView: webView, site: site)
    }

    func webView(
        _ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload
    ) {
        finishDownloadNavigation(webView)
        router?.browserDownload(download, webView: webView, site: site)
    }
    private func finishDownloadNavigation(_ webView: WKWebView) {
        guard webView === self.webView else { return }
        isLoading = false
        errorText = nil
        hasLoadedOnce = true
        webView.scrollView.refreshControl?.endRefreshing()
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
            router?.browserToast(L10n.tr("请先关闭已打开的网页窗口"))
            return nil
        }
        configuration.userContentController.addUserScript(
            WKUserScript(source: Self.viewportLockScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let popup = WKWebView(frame: .zero, configuration: configuration)
        Self.restrictScrolling(popup)
        popup.isOpaque = false
        popup.backgroundColor = Theme.pageUIColor
        popup.scrollView.backgroundColor = Theme.pageUIColor
        WebAppearance.install(on: configuration, enabled: router?.browserWebDarkModeEnabled(for: site) ?? true)
        popup.navigationDelegate = self
        popup.uiDelegate = self
        popup.allowsBackForwardNavigationGestures = true
        let controller = PopupBrowserController(webView: popup, downloads: router?.browserDownloadCenter)
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
        case .camera: kind = L10n.tr("摄像头")
        case .microphone: kind = L10n.tr("麦克风")
        case .cameraAndMicrophone: kind = L10n.tr("摄像头和麦克风")
        @unknown default: kind = L10n.tr("录制设备")
        }
        router?.browserToast(L10n.format("网页请求使用%@；本 App 不开放该权限", String(describing: kind)))
        decisionHandler(.deny)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: displayTitle, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("好"), style: .default) { _ in completionHandler() })
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
        alert.addAction(UIAlertAction(title: L10n.tr("取消"), style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: L10n.tr("确定"), style: .default) { _ in completionHandler(true) })
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
        alert.addAction(UIAlertAction(title: L10n.tr("取消"), style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(
            UIAlertAction(title: L10n.tr("确定"), style: .default) { [weak alert] _ in
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

/// A boolean interaction signal only; never receives input values or page HTML.
@MainActor private final class BrowserEditObserver: NSObject, WKScriptMessageHandler {
    private weak var owner: BrowserModel?
    init(owner: BrowserModel) { self.owner = owner }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "gtiitDocumentEdited", message.body as? Bool == true else { return }
        owner?.documentWasEdited()
    }
}
