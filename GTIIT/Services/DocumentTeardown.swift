import WebKit

/// 在清除存储前销毁活动文档，避免旧页面的定时脚本重新写入 Cookie/LocalStorage。
@MainActor final class DocumentTeardown: NSObject, WKNavigationDelegate {
    private var completion: (() -> Void)?
    func blank(_ webView: WKWebView) async {
        await withCheckedContinuation { continuation in
            completion = { continuation.resume() }
            webView.stopLoading()
            webView.navigationDelegate = self
            webView.uiDelegate = nil
            webView.load(URLRequest(url: URL(string: "about:blank")!))
            // 被系统回收的网页进程也必须让清理完成；新内核仍会替换旧内核。
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.finish() }
        }
        webView.stopLoading()
        webView.navigationDelegate = nil
    }
    private func finish() {
        let done = completion
        completion = nil
        done?()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish() }
    func webView(
        _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error
    ) { finish() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish() }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { finish() }
}
