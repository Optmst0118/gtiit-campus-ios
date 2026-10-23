import SwiftUI
import WebKit

/// A stable UIKit host lets the system tab bar track the real WebKit scroll view.
/// Content extends under the bar; UIKit adjusts its scrollable end above controls.
final class WebViewHostView: UIView {
    private(set) weak var hosted: WKWebView?
    private weak var previousHost: WebViewHostView?
    var didRestore: (() -> Void)?

    func host(_ webView: WKWebView) {
        guard hosted !== webView || webView.superview !== self else { return }
        if hosted?.superview === self { hosted?.removeFromSuperview() }
        if let previous = webView.superview as? WebViewHostView, previous !== self { previousHost = previous }
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        hosted = webView
    }
    func release() {
        guard let webView = hosted, webView.superview === self else { return }
        webView.removeFromSuperview()
        if let previousHost, previousHost.window != nil {
            previousHost.host(webView)
            previousHost.didRestore?()
            previousHost.setNeedsLayout()
        }
        previousHost = nil
        hosted = nil
    }
}

final class WebViewHostController: UIViewController {
    private let host = WebViewHostView()
    private weak var pendingWebView: WKWebView?
    private var visible = false
    private var fullPortalViewport = false
    private weak var bottomBar: UITabBar?
    // The navigation bar observes a clamped offset rather than WebKit's rubber
    // band. This keeps its large title stationary during pull-to-refresh and
    // also lets nested HTML scrollers drive the same native collapse.
    let navigationScrollView = UIScrollView()
    private weak var trackedWebView: WKWebView?
    private var scrollObservation: NSKeyValueObservation?
    private var innerScrollOffset: CGFloat = 0
    private lazy var scrollMessages = NavigationScrollMessages(owner: self)
    private static let navigationOwners = NSMapTable<WKWebView, WebViewHostController>(keyOptions: .weakMemory, valueOptions: .weakMemory)
    private static let scrollHandler = "gtiitNavigationScroll"
    private static let scrollScript = """
        /* GTIIT_NAVIGATION_SCROLL */
        (() => {
            if (window.__gtiitNavigationScroll) return;
            window.__gtiitNavigationScroll = true;
            let queued = false, inner = null;
            const report = () => {
                queued = false;
                const y = inner && inner.isConnected ? Math.max(0, inner.scrollTop || 0) : 0;
                try { window.webkit.messageHandlers.gtiitNavigationScroll.postMessage(y); } catch (_) {}
            };
            document.addEventListener('scroll', event => {
                const target = event.target;
                if (target && target !== document && target !== document.scrollingElement && target.clientHeight >= innerHeight * 0.45) inner = target;
                if (!queued) { queued = true; requestAnimationFrame(report); }
            }, {capture:true, passive:true});
            addEventListener('pageshow', report);
            report();
        })();
        """
    override func loadView() {
        host.backgroundColor = Theme.pageUIColor; view = host
        host.didRestore = { [weak self] in
            guard let self else { return }
            self.visible = true
            self.attach()
        }
        navigationScrollView.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        navigationScrollView.contentSize = CGSize(width: 1, height: 1000)
        navigationScrollView.contentInsetAdjustmentBehavior = .never
        navigationScrollView.isUserInteractionEnabled = false
        navigationScrollView.isAccessibilityElement = false
        navigationScrollView.alpha = 0
        host.addSubview(navigationScrollView)
    }
    func display(_ webView: WKWebView, portal: Bool = false) {
        fullPortalViewport = portal
        pendingWebView = webView
        loadViewIfNeeded()
        if visible && (host.hosted == nil || host.hosted?.superview === host) { attach() }
    }
    func release() {
        visible = false
        scrollObservation = nil
        if let trackedWebView, Self.navigationOwners.object(forKey: trackedWebView) === self {
            trackedWebView.configuration.userContentController.removeScriptMessageHandler(forName: Self.scrollHandler, contentWorld: .defaultClient)
            Self.navigationOwners.removeObject(forKey: trackedWebView)
        }
        trackedWebView = nil
        host.release(); pendingWebView = nil
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        visible = true
        attach()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        visible = false
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        attach()
    }
    private func attach() {
        guard let webView = pendingWebView else { return }
        host.host(webView)
        trackNavigation(webView)
        setContentScrollView(navigationScrollView, for: .top)
        setContentScrollView(webView.scrollView, for: .bottom)
        // The booking segment sits above this child host. Register explicitly
        // on the navigation content controller so that extra sibling cannot
        // prevent UIKit from finding the intended top scroll view.
        navigationController?.topViewController?.setContentScrollView(navigationScrollView, for: .top)
        view.setNeedsLayout()
    }
    private func trackNavigation(_ webView: WKWebView) {
        guard trackedWebView !== webView || Self.navigationOwners.object(forKey: webView) !== self else { return }
        if let previous = trackedWebView, Self.navigationOwners.object(forKey: previous) === self {
            previous.configuration.userContentController.removeScriptMessageHandler(forName: Self.scrollHandler, contentWorld: .defaultClient)
            Self.navigationOwners.removeObject(forKey: previous)
        }
        Self.navigationOwners.setObject(self, forKey: webView)
        trackedWebView = webView; innerScrollOffset = 0
        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: Self.scrollHandler, contentWorld: .defaultClient)
        controller.add(scrollMessages, contentWorld: .defaultClient, name: Self.scrollHandler)
        if !controller.userScripts.contains(where: { $0.source.contains("GTIIT_NAVIGATION_SCROLL") }) {
            controller.addUserScript(WKUserScript(source: Self.scrollScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: .defaultClient))
        }
        webView.evaluateJavaScript(Self.scrollScript, in: nil, in: .defaultClient) { _ in }
        scrollObservation = webView.scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] _, _ in
            self?.updateNavigationOffset()
        }
    }
    fileprivate func receiveInnerScroll(_ value: CGFloat) {
        guard value.isFinite else { return }
        innerScrollOffset = max(0, value); updateNavigationOffset()
    }
    private func updateNavigationOffset() {
        guard visible, let scroll = trackedWebView?.scrollView else { return }
        let outer = max(0, scroll.contentOffset.y + scroll.adjustedContentInset.top)
        let y = min(120, max(outer, innerScrollOffset))
        if abs(navigationScrollView.contentOffset.y - y) > 0.25 {
            navigationScrollView.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard visible, let webView = host.hosted, webView.superview === host else { return }
        var bottom = max(0, view.safeAreaInsets.bottom)
        if bottomBar?.window !== view.window, let window = view.window {
            func findBar(_ view: UIView) -> UITabBar? {
                if let bar = view as? UITabBar { return bar }
                for child in view.subviews { if let bar = findBar(child) { return bar } }
                return nil
            }
            bottomBar = findBar(window)
        }
        if let window = view.window, let bar = bottomBar, !bar.isHidden {
            let webFrame = webView.convert(webView.bounds, to: window)
            let barFrame = bar.convert(bar.bounds, to: window)
            bottom = max(bottom, webFrame.maxY - barFrame.minY)
        }
        if fullPortalViewport {
            // Student scrolls an inner <main> inside a height:100% React root.
            // Obscuring/insetting WebKit shrinks that viewport above the glass.
            // Keep its viewport full-height and give only the inner scroll end
            // clearance, so real page pixels continue beneath the tab bar.
            webView.scrollView.contentInsetAdjustmentBehavior = .never
            webView.scrollView.contentInset = .zero
            webView.scrollView.verticalScrollIndicatorInsets.bottom = bottom
            if #available(iOS 26.0, *) { webView.obscuredContentInsets = .zero }
            WebAppearance.setPortalBottomInset(bottom, on: webView)
        } else if #available(iOS 26.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .automatic
            let insets = UIEdgeInsets(top: 0, left: 0, bottom: bottom, right: 0)
            if webView.obscuredContentInsets != insets { webView.obscuredContentInsets = insets }
        }
    }
}

/// Weak owner avoids a WebKit → handler → host retention cycle. Only a numeric
/// scroll offset from the main frame is accepted; no page content is read.
@MainActor private final class NavigationScrollMessages: NSObject, WKScriptMessageHandler {
    weak var owner: WebViewHostController?
    init(owner: WebViewHostController) { self.owner = owner }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let offset = message.body as? NSNumber else { return }
        owner?.receiveInnerScroll(CGFloat(offset.doubleValue))
    }
}

/// Reuses BrowserModel's existing WKWebView, retaining login, scroll and forms.
struct WebViewContainer: UIViewControllerRepresentable {
    let model: BrowserModel
    func makeUIViewController(context: Context) -> WebViewHostController {
        let controller = WebViewHostController()
        controller.display(model.webView, portal: model.site == .portal)
        return controller
    }
    func updateUIViewController(_ controller: WebViewHostController, context: Context) {
        controller.display(model.webView, portal: model.site == .portal)
    }
    static func dismantleUIViewController(_ controller: WebViewHostController, coordinator: ()) {
        controller.release()
    }
}
