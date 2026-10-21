import UIKit
import WebKit

@MainActor protocol BrowserRouter: AnyObject {
    var browserDownloadCenter: DownloadCoordinator? { get }
    var externalLinkMode: ExternalLinkMode { get }
    func browserInitialURL(for site: SiteID) -> URL
    func browserDidFinish(url: URL, site: SiteID)
    func browserRouteToOtherSite(url: URL, from site: SiteID)
    func browserOpenExternal(url: URL)
    func browserOpenInAppSafari(url: URL)
    func browserPresentShare(items: [Any])
    func browserPresent(viewController: UIViewController) -> Bool
    func browserToast(_ message: String)
    func browserDownload(_ download: WKDownload, webView: WKWebView, site: SiteID)
    func browserClearData(for site: SiteID) async
}

extension BrowserRouter {
    var browserDownloadCenter: DownloadCoordinator? { nil }
}
