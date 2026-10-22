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
    private var failureController: UIViewController?
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
        view.backgroundColor = Theme.pageUIColor
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        title = L10n.tr("网页窗口")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: L10n.tr("关闭"), style: .done, target: self, action: #selector(close))
        titleObservation = webView.observe(\.title) { [weak self] webView, _ in
            let title = webView.title
            Task { @MainActor in self?.title = title ?? L10n.tr("网页窗口") }
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
    func showFailure(site: SiteID, message: String, openSafari: @escaping () -> Void) {
        loadViewIfNeeded(); dismissFailure()
        let content = LoadErrorView(site: site, message: message,
            onRetry: { [weak self] in self?.dismissFailure(); self?.webView.reload() },
            onOpenSafari: openSafari,
            onOpenHome: { [weak self] in self?.dismissFailure(); self?.webView.load(URLRequest(url: site.homeURL)) })
            .environment(\.locale, L10n.locale)
        let controller = UIHostingController(rootView: content)
        addChild(controller); controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controller.didMove(toParent: self); failureController = controller
    }
    func dismissFailure() {
        failureController?.willMove(toParent: nil)
        failureController?.view.removeFromSuperview()
        failureController?.removeFromParent(); failureController = nil
    }
    @objc private func close() { onClose?() }
}
