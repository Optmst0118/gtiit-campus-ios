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
    var startsLargeTitle = false
    var inlineTitle = false
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
    private var homeObserver: NSObjectProtocol?
    private lazy var scrollMessages = NavigationScrollMessages(owner: self)
    private static let navigationOwners = NSMapTable<WKWebView, WebViewHostController>(keyOptions: .weakMemory, valueOptions: .weakMemory)
    static func resetForCourse(_ webView: WKWebView) {
        navigationOwners.object(forKey: webView)?.resetNavigationForCourse()
    }
    private func resetNavigationForCourse() {
        innerScrollOffset = 0
        navigationScrollView.setContentOffset(.zero, animated: false)
        navigationController?.navigationBar.sizeToFit()
        navigationController?.navigationBar.setNeedsLayout()
    }
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
                if (!target || target === document || target === document.scrollingElement) {
                    // The WebView itself is scrolling; the native contentOffset owns
                    // the title now, so a stale inner value must not pin it open.
                    inner = null;
                } else if (target.clientHeight >= innerHeight * 0.45) {
                    inner = target;
                }
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
        if let homeObserver { NotificationCenter.default.removeObserver(homeObserver) }
        homeObserver = nil
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
        if startsLargeTitle { resetNavigationForCourse() }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        visible = false
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        attach()
        // Switching tabs can inherit a collapsed navigation bar even when the
        // tracked offset is already zero; force the expanded layout once.
        if !inlineTitle && (startsLargeTitle || navigationScrollView.contentOffset.y <= 0.5) {
            navigationScrollView.setContentOffset(CGPoint(x: 0, y: -1), animated: false)
            navigationScrollView.setContentOffset(.zero, animated: false)
            navigationController?.navigationBar.sizeToFit()
        }
    }
    private func attach() {
        guard let webView = pendingWebView else { return }
        host.host(webView)
        trackNavigation(webView)
        if startsLargeTitle {
            webView.scrollView.setContentOffset(.zero, animated: false)
            resetNavigationForCourse()
        }
        // Student scrolls a nested <main>, so its title is driven by the proxy
        // offset. The other three sites scroll the WebKit scroll view itself;
        // handing that real scroll view to UIKit gives native collapse, the
        // system animation and reliable expansion when returning to the top.
        let topScrollView: UIScrollView = fullPortalViewport ? navigationScrollView : webView.scrollView
        setContentScrollView(topScrollView, for: .top)
        setContentScrollView(webView.scrollView, for: .bottom)
        // The booking segment sits above this child host. Register explicitly
        // on the navigation content controller so that extra sibling cannot
        // prevent UIKit from finding the intended top scroll view.
        navigationController?.topViewController?.setContentScrollView(topScrollView, for: .top)
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
        if let homeObserver { NotificationCenter.default.removeObserver(homeObserver) }
        homeObserver = NotificationCenter.default.addObserver(
            forName: .browserDidRequestHome, object: webView, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.scrollToTop(animated: true) }
        }
        scrollObservation = webView.scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] _, _ in
            self?.updateNavigationOffset()
        }
    }
    fileprivate func receiveInnerScroll(_ value: CGFloat) {
        guard value.isFinite else { return }
        innerScrollOffset = max(0, value)
        updateNavigationOffset()
    }

    /// Expanding the large title again is animated by UIKit when the tracked
    /// offset returns to zero; an explicit animated reset also covers reloads
    /// and tab re-selection, where WebKit may keep the previous offset briefly.
    fileprivate func scrollToTop(animated: Bool) {
        innerScrollOffset = 0
        guard let webView = trackedWebView else { return }
        let animate = animated && !UIAccessibility.isReduceMotionEnabled
        let move = {
            let inset = webView.scrollView.adjustedContentInset
            webView.scrollView.setContentOffset(CGPoint(x: -inset.left, y: -inset.top), animated: false)
            self.navigationScrollView.setContentOffset(.zero, animated: false)
        }
        if animate {
            UIView.animate(withDuration: PrimaryNavigationMotion.duration, delay: 0,
                options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction], animations: move)
        } else { move() }
        webView.evaluateJavaScript("""
            (() => {
                cancelAnimationFrame(globalThis.__gtiitTopFrame || 0);
                const nodes = [...new Set([document.scrollingElement, document.querySelector('main')])].filter(Boolean);
                const starts = nodes.map(node => node.scrollTop), began = performance.now();
                const tick = now => {
                    const t = \(animate ? "Math.min(1,(now-began)/300)" : "1");
                    const eased = t*t*(3-2*t);
                    nodes.forEach((node,index) => node.scrollTop = starts[index]*(1-eased));
                    if(t<1)globalThis.__gtiitTopFrame=requestAnimationFrame(tick);
                };
                globalThis.__gtiitTopFrame=requestAnimationFrame(tick);
            })();
            """, in: nil, in: .defaultClient) { _ in }
        navigationController?.navigationBar.setNeedsLayout()
    }

    private func updateNavigationOffset() {
        guard visible, let scroll = trackedWebView?.scrollView else { return }
        let outer = max(0, scroll.contentOffset.y + scroll.adjustedContentInset.top)
        let y = min(120, max(0, max(outer, innerScrollOffset)))
        let previous = navigationScrollView.contentOffset.y
        if abs(previous - y) > 0.25 {
            navigationScrollView.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        }
        // At the very top make sure UIKit re-lays out the large title even when
        // WebKit reports the final offset in one jump at the end of a gesture.
        if y == 0 && previous > 0.5 {
            // Nudging through the top edge and re-applying the large-title mode
            // makes UINavigationBar rebuild its expanded layout; a bare
            // programmatic zero can leave it collapsed.
            navigationScrollView.setContentOffset(CGPoint(x: 0, y: -1), animated: false)
            navigationScrollView.setContentOffset(.zero, animated: true)
            if let nav = navigationController {
                nav.navigationBar.sizeToFit()
                nav.view.setNeedsLayout()
                nav.view.layoutIfNeeded()
            }
        }
    }
    /// SwiftUI can replace the registered content scroll view while it builds
    /// the NavigationStack. Re-register on layout so every tab's title follows
    /// its own WebKit scroll view (or the proxy for the nested Student page).
    private func registerContentScrollView(_ webView: WKWebView) {
        guard let navigationController else { return }
        let topScrollView: UIScrollView = fullPortalViewport ? navigationScrollView : webView.scrollView
        setContentScrollView(topScrollView, for: .top)
        navigationController.topViewController?.setContentScrollView(topScrollView, for: .top)
        navigationController.viewControllers.last?.setContentScrollView(topScrollView, for: .top)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard visible, let webView = host.hosted, webView.superview === host else { return }
        registerContentScrollView(webView)
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
    var startsLargeTitle = false
    var inlineTitle = false

    func makeUIViewController(context: Context) -> WebViewHostController {
        let controller = WebViewHostController()
        controller.startsLargeTitle = startsLargeTitle
        controller.inlineTitle = inlineTitle
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
