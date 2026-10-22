import SwiftUI
import WebKit

/// A stable UIKit host lets the system tab bar track the real WebKit scroll view.
/// Content extends under the bar; UIKit adjusts its scrollable end above controls.
final class WebViewHostView: UIView {
    private(set) weak var hosted: WKWebView?
    private weak var previousHost: WebViewHostView?

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
    override func loadView() { host.backgroundColor = Theme.pageUIColor; view = host }
    func display(_ webView: WKWebView) {
        pendingWebView = webView
        loadViewIfNeeded()
        if visible && (host.hosted == nil || host.hosted?.superview === host) { attach() }
    }
    func release() { visible = false; host.release(); pendingWebView = nil }
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
        setContentScrollView(webView.scrollView, for: .bottom)
        view.setNeedsLayout()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard visible, let webView = host.hosted, webView.superview === host else { return }
        if #available(iOS 26.0, *) {
            // Unlike ordinary scroll insets, WebKit's obscured insets also account
            // for viewport-height layouts, inner scrolling and fixed elements.
            let bottom = max(0, view.safeAreaInsets.bottom)
            let insets = UIEdgeInsets(top: 0, left: 0, bottom: bottom, right: 0)
            if webView.obscuredContentInsets != insets { webView.obscuredContentInsets = insets }
        }
    }
}

/// Reuses BrowserModel's existing WKWebView, retaining login, scroll and forms.
struct WebViewContainer: UIViewControllerRepresentable {
    let model: BrowserModel
    func makeUIViewController(context: Context) -> WebViewHostController {
        let controller = WebViewHostController()
        controller.display(model.webView)
        return controller
    }
    func updateUIViewController(_ controller: WebViewHostController, context: Context) {
        controller.display(model.webView)
    }
    static func dismantleUIViewController(_ controller: WebViewHostController, coordinator: ()) {
        controller.release()
    }
}
