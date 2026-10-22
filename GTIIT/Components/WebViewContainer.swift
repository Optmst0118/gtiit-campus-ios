import SwiftUI
import WebKit

/// A stable UIKit host lets the system tab bar track the real WebKit scroll view.
/// Content extends under the bar; UIKit adjusts its scrollable end above controls.
final class WebViewHostView: UIView {
    private(set) weak var hosted: WKWebView?

    func host(_ webView: WKWebView) {
        guard hosted !== webView else { return }
        hosted?.removeFromSuperview()
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
}

final class WebViewHostController: UIViewController {
    private let host = WebViewHostView()
    override func loadView() { host.backgroundColor = Theme.pageUIColor; view = host }
    func display(_ webView: WKWebView) {
        loadViewIfNeeded()
        host.host(webView)
        setContentScrollView(webView.scrollView, for: .bottom)
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
}
