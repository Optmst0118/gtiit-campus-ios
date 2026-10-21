import Foundation
import UIKit

/// 网页内核向外层（AppModel）回调的出口：
/// 跨站链接路由、外部链接、分享面板、轻提示。
@MainActor
protocol BrowserRouter: AnyObject {
    func browserRouteToOtherSite(url: URL, from site: SiteID)
    func browserOpenExternal(url: URL)
    func browserPresentShare(items: [Any])
    /// 返回是否成功呈现（没有可用的上层控制器时返回 false，让调用方补回调）。
    func browserPresent(viewController: UIViewController) -> Bool
    func browserToast(_ message: String)
}
