import UIKit
import WebKit
import SwiftUI

/// 使用 WebKit 提供的配置创建真实子窗口，保留 SSO 的 opener 与 postMessage。
@MainActor final class PopupBrowserController: UIViewController {
    let webView: WKWebView
    var onClose: (() -> Void)?
    private var titleObservation: NSKeyValueObservation?
    private let downloads: DownloadCoordinator?
    private let downloadPresenterID = UUID()
    init(webView: WKWebView, downloads: DownloadCoordinator? = nil) {
        self.webView = webView
        self.downloads = downloads
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        downloads?.setPopupPresenter(downloadPresenterID, visible: true)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        downloads?.setPopupPresenter(downloadPresenterID, visible: false)
    }
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
        if let downloads {
            let panel = UIHostingController(rootView: DownloadFloatingPanel(center: downloads))
            panel.view.backgroundColor = .clear
            panel.sizingOptions = [.intrinsicContentSize]
            addChild(panel)
            panel.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(panel.view)
            NSLayoutConstraint.activate([
                panel.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                panel.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            ])
            panel.didMove(toParent: self)
        }
    }
    @objc private func close() { onClose?() }
}
