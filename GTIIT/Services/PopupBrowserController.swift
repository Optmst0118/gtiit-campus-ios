import UIKit
import WebKit

/// 使用 WebKit 提供的配置创建真实子窗口，保留 SSO 的 opener 与 postMessage。
@MainActor final class PopupBrowserController: UIViewController {
    let webView: WKWebView
    var onClose: (() -> Void)?
    private var titleObservation: NSKeyValueObservation?
    init(webView: WKWebView) {
        self.webView = webView
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        title = "网页窗口"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "关闭", style: .done, target: self, action: #selector(close))
        titleObservation = webView.observe(\.title) { [weak self] webView, _ in
            let title = webView.title
            Task { @MainActor in self?.title = title ?? "网页窗口" }
        }
    }
    @objc private func close() { onClose?() }
}
