import SwiftUI
import WebKit

/// WebView 的稳定宿主：SwiftUI 只管理这一层容器，
/// WKWebView 在容器内被重新挂载，避免同一 UIView 跨 representable 复用导致白屏。
final class WebViewHostView: UIView {
    private weak var hosted: WKWebView?

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

/// 把 BrowserModel 里长期持有的 WKWebView 挂进 SwiftUI 层级。
/// 切换 Tab / 分段只做重新挂载，不重建 WebView，滚动位置与页面状态都保留。
struct WebViewContainer: UIViewRepresentable {
    let model: BrowserModel

    func makeUIView(context: Context) -> WebViewHostView {
        let container = WebViewHostView()
        container.backgroundColor = .clear
        container.host(model.webView)
        return container
    }

    func updateUIView(_ uiView: WebViewHostView, context: Context) {
        uiView.host(model.webView)
    }
}
