import UIKit
import WebKit

final class ReviewAction: WKNavigationAction {
    let reviewRequest: URLRequest
    let kind: WKNavigationType
    init(_ request: URLRequest, kind: WKNavigationType = .linkActivated) { self.reviewRequest = request; self.kind = kind; super.init() }
    override var request: URLRequest { reviewRequest }
    override var navigationType: WKNavigationType { kind }
    override var targetFrame: WKFrameInfo? { nil }
    override var shouldPerformDownload: Bool { false }
}
@MainActor final class ReviewRouter: BrowserRouter {
    var routes: [String] = []; var externals: [String] = []
    func browserRouteToOtherSite(url: URL, from site: SiteID) { routes.append(url.absoluteString) }
    func browserOpenExternal(url: URL) { externals.append(url.absoluteString) }
    func browserPresentShare(items: [Any]) {}
    func browserPresent(viewController: UIViewController) -> Bool { false }
    func browserToast(_ message: String) {}
}
@MainActor final class CaptureDelegate: NSObject, WKNavigationDelegate {
    var methods: [String] = []
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.request.url?.query == "independent_review=post" { methods.append(navigationAction.request.httpMethod ?? "nil") }
        decisionHandler(.cancel)
    }
}
@main @MainActor final class ReviewApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var keep: [AnyObject] = []
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds); window?.rootViewController = UIViewController(); window?.makeKeyAndVisible()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.runReview() }
        return true
    }
    func runReview() {
        let spy = ReviewRouter(); let source = BrowserModel(site: .portal, router: spy); source.webView.stopLoading()
        let targetURL = URL(string: "https://moodle.gtiit.edu.cn/moodle/my/?independent_review=post")!
        var policies: [Int] = []
        let click = ReviewAction(URLRequest(url: targetURL))
        source.webView(source.webView, decidePolicyFor: click) { policies.append($0.rawValue) }
        source.webView(source.webView, decidePolicyFor: click) { policies.append($0.rawValue) }
        let blob = ReviewAction(URLRequest(url: URL(string: "blob:https://students.gtiit.edu.cn/review")!))
        var blobPolicy = -1
        source.webView(source.webView, decidePolicyFor: blob) { blobPolicy = $0.rawValue }
        let app = AppModel(); let destination = app.browser(for: .moodle); destination.webView.stopLoading()
        let capture = CaptureDelegate(); destination.webView.navigationDelegate = capture
        let postSource = BrowserModel(site: .portal, router: app); postSource.webView.stopLoading()
        var request = URLRequest(url: targetURL); request.httpMethod = "POST"; request.httpBody = Data("review=non_sensitive_test".utf8)
        let post = ReviewAction(request, kind: .formSubmitted)
        var postPolicy = -1
        postSource.webView(postSource.webView, decidePolicyFor: post) { postPolicy = $0.rawValue }
        keep = [spy, source, app, destination, capture, postSource]
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            let result: [String: Any] = ["same_link_policies_cancel0_allow1": policies, "routed_count": spy.routes.count, "blob_policy_cancel0": blobPolicy, "blob_sent_to_system": spy.externals, "cross_site_form_input_method": "POST", "cross_site_form_source_policy": postPolicy, "destination_actual_request_methods": capture.methods]
            let data = try! JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("results.json")
            try! data.write(to: output)
            print(String(data: data, encoding: .utf8)!)
            exit(0)
        }
    }
}
