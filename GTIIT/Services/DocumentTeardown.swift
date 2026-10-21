import WebKit

/// 在清除存储前销毁活动文档；只接收本次空白导航的回调，忽略旧页面的取消事件。
@MainActor final class DocumentTeardown: NSObject, WKNavigationDelegate {
    private var completion: ((Bool) -> Void)?
    private var blankNavigation: WKNavigation?
    func blank(_ webView: WKWebView) async -> Bool {
        let finished = await withCheckedContinuation { continuation in
            completion = { continuation.resume(returning: $0) }
            webView.stopLoading()
            webView.navigationDelegate = self
            webView.uiDelegate = nil
            blankNavigation = webView.load(URLRequest(url: URL(string: "about:blank")!))
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.finish(false) }
        }
        webView.stopLoading()
        webView.navigationDelegate = nil
        return finished
    }
    private func finish(_ success: Bool) {
        let done = completion
        completion = nil
        blankNavigation = nil
        done?(success)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation === blankNavigation else { return }
        finish(webView.url?.absoluteString == "about:blank")
    }
    func webView(
        _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error
    ) {
        guard navigation === blankNavigation else { return }
        finish(false)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard navigation === blankNavigation else { return }
        finish(false)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { finish(true) }
}
