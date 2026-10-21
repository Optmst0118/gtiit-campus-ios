import Foundation
import WebKit

/// 只有用户点击的普通 GET 链接跨容器。认证、表单、重定向保留 WebKit 上下文。
enum NavigationPolicy {
    /// WebKit 转下载/策略取消不是网络失败；真实连接、证书等错误仍正常显示。
    static func isExpectedInterruption(_ error: NSError) -> Bool {
        error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled
            || error.domain == "WebKitErrorDomain" && error.code == 102
    }
    static func canRoute(_ action: WKNavigationAction) -> Bool {
        action.navigationType == .linkActivated
            && (action.request.httpMethod ?? "GET").uppercased() == "GET"
            && action.request.httpBody == nil && action.request.httpBodyStream == nil
            && action.targetFrame?.isMainFrame != false
    }
    static func isInternalScheme(_ scheme: String) -> Bool {
        ["http", "https", "about", "blob", "data"].contains(scheme)
    }
    static func isExternalScheme(_ scheme: String) -> Bool {
        ["tel", "mailto", "sms", "msteams", "weixin", "alipays", "itms-apps", "maps"].contains(scheme)
    }
    static func isAuthentication(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        return ["microsoftonline.com", "microsoft.com", "live.com"].contains {
            host == $0 || host.hasSuffix("." + $0)
        }
            || ["login", "logout", "saml", "oauth", "callback", "auth"].contains(where: path.contains)
    }
}
