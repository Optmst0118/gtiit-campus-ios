import Combine
import UIKit
import WebKit

@MainActor final class FrameCapture: NSObject, WKNavigationDelegate {
    var frame: WKFrameInfo?
    func webView(
        _ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        frame = action.targetFrame
        decisionHandler(.cancel)
    }
}
final class TestAction: WKNavigationAction {
    let value: URLRequest
    let type: WKNavigationType
    static var actualFrame: WKFrameInfo?
    init(_ request: URLRequest, type: WKNavigationType = .linkActivated) {
        value = request
        self.type = type
        super.init()
    }
    override var request: URLRequest { value }
    override var navigationType: WKNavigationType { type }
    override var targetFrame: WKFrameInfo? { Self.actualFrame }
    override var shouldPerformDownload: Bool { false }
}
@MainActor final class TestRouter: BrowserRouter {
    var externalLinkMode: ExternalLinkMode = .webView
    var routes: [URL] = []
    var externals: [URL] = []
    var safari: [URL] = []
    func browserInitialURL(for site: SiteID) -> URL { URL(string: "about:blank")! }
    func browserDidFinish(url: URL, site: SiteID) {}
    func browserRouteToOtherSite(url: URL, from site: SiteID) { routes.append(url) }
    func browserOpenExternal(url: URL) { externals.append(url) }
    func browserOpenInAppSafari(url: URL) { safari.append(url) }
    func browserPresentShare(items: [Any]) {}
    func browserPresent(viewController: UIViewController) -> Bool { false }
    func browserToast(_ message: String) {}
    func browserDownload(_ download: WKDownload, webView: WKWebView, site: SiteID) {}
    func browserClearData(for site: SiteID) async {}
}
@MainActor final class MockAuthenticator: LocalAuthenticating {
    var isAvailable = true
    var label = "测试认证"
    var success = false
    var throwsCancellation = false
    func authenticate() async throws -> Bool {
        if throwsCancellation { throw NSError(domain: "TestAuthentication", code: -2) }
        return success
    }
}
@main @MainActor final class RegressionApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var results: [[String: Any]] = []
    var keep: [AnyObject] = []
    let base = URL(string: "http://127.0.0.1:48173")!
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        setbuf(stdout, nil)
        return true
    }
    func application(
        _ application: UIApplication, configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Regression", sessionRole: session.role)
        configuration.delegateClass = RegressionSceneDelegate.self
        return configuration
    }
    func check(_ name: String, _ passed: Bool, _ detail: String = "") {
        results.append(["test": name, "passed": passed, "detail": detail])
        print("\(passed ? "PASS" : "FAIL") \(name) \(detail)")
    }
    func wait(_ seconds: Double = 8, until predicate: @MainActor () async -> Bool) async -> Bool {
        let end = Date().addingTimeInterval(seconds)
        repeat {
            if await predicate() { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        } while Date() < end
        return false
    }
    func load(_ model: BrowserModel, _ path: String) async -> Bool {
        model.load(base.appendingPathComponent(path))
        return await wait {
            !model.isLoading && model.webView.url?.path == "/" + path && model.webView.title == "Fixture"
        }
    }
    func js(_ webView: WKWebView, _ source: String) async -> String {
        do {
            let value = try await webView.evaluateJavaScript(source)
            return String(describing: value)
        } catch { return "ERROR \(error)" }
    }
    func run() async {
        let defaults = UserDefaults(suiteName: "regression.preferences")!
        defaults.removePersistentDomain(forName: "regression.preferences")
        let settings = AppSettings(defaults: defaults)
        settings.hasSeenWelcome = true
        settings.startupTab = .me
        settings.defaultBooking = .sports
        settings.appearance = .dark
        settings.externalLinks = .systemBrowser
        settings.lockDelay = .fiveMinutes
        settings.downloadRetention = .week
        settings.restoreLastPage = true
        let restored = AppSettings(defaults: defaults)
        check(
            "preferences_persist",
            restored.startupTab == .me && restored.defaultBooking == .sports && restored.appearance == .dark
                && restored.externalLinks == .systemBrowser && restored.lockDelay == .fiveMinutes
                && restored.downloadRetention == .week)
        let ordinary = URL(string: "https://students.gtiit.edu.cn/ordinary")!
        settings.remember(ordinary, for: .portal)
        check("restore_safe_location", settings.initialURL(for: .portal) == ordinary)
        for raw in [
            "https://students.gtiit.edu.cn/?token=secret", "https://students.gtiit.edu.cn/login",
            "https://moodle.gtiit.edu.cn/moodle/my/", "http://students.gtiit.edu.cn/",
        ] { settings.remember(URL(string: raw)!, for: .portal) }
        check("reject_auth_parameters_and_wrong_origin", settings.initialURL(for: .portal) == ordinary)
        settings.restoreLastPage = false
        check("disable_restore_removes_locations", settings.initialURL(for: .portal) == SiteID.portal.homeURL)
        let capture = FrameCapture()
        let frameWebView = WKWebView()
        frameWebView.navigationDelegate = capture
        frameWebView.load(URLRequest(url: base.appendingPathComponent("a")))
        check("real_main_frame_available", await wait { capture.frame?.isMainFrame == true })
        TestAction.actualFrame = capture.frame
        keep += [capture, frameWebView]
        let spy = TestRouter()
        let model = BrowserModel(site: .portal, router: spy)
        model.webView.stopLoading()
        keep += [spy, model]
        let cross = URL(string: "https://moodle.gtiit.edu.cn/moodle/my/")!
        var policies: [Int] = []
        for _ in 0..<2 {
            model.webView(model.webView, decidePolicyFor: TestAction(URLRequest(url: cross))) {
                policies.append($0.rawValue)
            }
        }
        check(
            "repeated_cross_site_link_cancelled", policies == [0, 0] && spy.routes.count == 2,
            "policies=\(policies), routes=\(spy.routes.count)")
        var post = URLRequest(url: cross)
        post.httpMethod = "POST"
        post.httpBody = Data("review=synthetic".utf8)
        let previous = spy.routes.count
        var postPolicy = -1
        model.webView(model.webView, decidePolicyFor: TestAction(post, type: .formSubmitted)) {
            postPolicy = $0.rawValue
        }
        check(
            "cross_site_post_keeps_request_context",
            postPolicy == 1 && spy.routes.count == previous && post.httpBody != nil)
        for raw in ["blob:https://students.gtiit.edu.cn/review", "data:text/html,review", "about:blank"] {
            var policy = -1
            model.webView(model.webView, decidePolicyFor: TestAction(URLRequest(url: URL(string: raw)!))) {
                policy = $0.rawValue
            }
            check("internal_scheme_\(raw.split(separator: ":")[0])", policy == 1 && spy.externals.isEmpty)
        }
        spy.externalLinkMode = .systemBrowser
        let outside = URL(string: "https://example.org/review")!
        model.webView(model.webView, decidePolicyFor: TestAction(URLRequest(url: outside))) { _ in }
        check("external_link_system_route", spy.externals == [outside] && spy.safari.isEmpty)
        spy.externalLinkMode = .safariView
        model.webView(model.webView, decidePolicyFor: TestAction(URLRequest(url: outside))) { _ in }
        check("external_link_safari_route", spy.safari == [outside])
        check(
            "other_mike_tenant_not_sports",
            SiteID.site(for: URL(string: "https://another-school.mike-x.com/")!) == nil)
        check(
            "filename_safe_utf8",
            DownloadCoordinator.sanitize(String(repeating: "学", count: 300) + "/../x").utf8.count <= 220)

        let app = AppModel(settings: settings)
        keep.append(app)
        check("startup_preferences_applied", app.selectedTab == .me && app.bookingSegment == .sports)
        let browser = app.browser(for: .portal)
        browser.webView.stopLoading()
        browser.webView.frame = window!.bounds
        window!.rootViewController!.view.addSubview(browser.webView)
        check("fixture_load_a", await load(browser, "a"))
        check("fixture_load_b", await load(browser, "b"))
        check("browser_has_history_before_clear", browser.webView.canGoBack)
        await app.clearCaches()
        let cookiesBefore = await WebDataStoreRegistry.shared.summary(for: .portal).cookies
        let storageBefore = await js(browser.webView, "localStorage.getItem('review')")
        check(
            "cache_clear_preserves_login_and_storage", cookiesBefore > 0 && storageBefore.contains("fixture"),
            "cookies=\(cookiesBefore)")
        _ = await load(browser, "a")
        _ = await js(browser.webView, "document.querySelector('form').submit(); 'submitted'")
        check("real_webkit_post_reaches_echo", await wait { browser.webView.title == "POST received" })
        _ = await load(browser, "a")
        _ = await js(
            browser.webView,
            "var b=new Blob(['<title>Blob review</title><p>fixture</p>'],{type:'text/html'});location.href=URL.createObjectURL(b);'blob'"
        )
        check("real_blob_preview", await wait { browser.webView.title == "Blob review" })
        _ = await load(browser, "a")
        _ = await js(browser.webView, "window.open('/child','review-child');'opened'")
        check(
            "real_popup_opener_postMessage",
            await wait { (await self.js(browser.webView, "window.reviewMessage")).contains("review-ok") })
        check(
            "popup_window_close",
            await wait { self.window?.rootViewController?.presentedViewController == nil })

        browser.load(base.appendingPathComponent("file"))
        check(
            "renderable_pdf_attachment_download",
            await wait { app.downloads.items.contains { $0.state == .completed } })
        browser.load(base.appendingPathComponent("file"))
        check(
            "same_filename_download_twice",
            await wait { app.downloads.items.filter { $0.state == .completed }.count >= 2 })
        let completed = app.downloads.items.filter { $0.state == .completed }
        let urls = completed.compactMap { app.downloads.fileURL(for: $0) }
        check(
            "download_destinations_unique",
            urls.count >= 2 && Set(urls).count == urls.count && app.downloads.totalBytes > 0)
        browser.load(base.appendingPathComponent("slow"))
        let gotSlow = await wait { app.downloads.items.contains { $0.state == .downloading && $0.bytes > 0 } }
        check("download_progress", gotSlow)
        if let slow = app.downloads.items.first(where: { $0.state == .downloading }) {
            app.downloads.cancel(slow.id)
            check("download_cancel", app.downloads.items.first { $0.id == slow.id }?.state == .cancelled)
            let resumable = await wait(2) { app.downloads.canRetry(slow.id) }
            if resumable {
                app.downloads.retry(slow.id)
                check(
                    "download_resume",
                    await wait(15) { app.downloads.items.first { $0.id == slow.id }?.state == .completed })
            } else {
                check(
                    "nonresumable_has_source_fallback",
                    app.downloads.items.first { $0.id == slow.id }?.site == .portal)
            }
        }
        _ = await load(browser, "a")
        let previousView = browser.webView
        await app.clearData(for: .portal)
        let after = await WebDataStoreRegistry.shared.summary(for: .portal)
        check(
            "clear_replaces_webview_and_history",
            browser.webView !== previousView && !browser.webView.canGoBack
                && browser.webView.backForwardList.backList.isEmpty && browser.needsReloadAfterClear)
        check(
            "clear_cookie_and_storage", after.cookies == 0 && !after.hasData,
            "cookies=\(after.cookies), records=\(after.records)")
        try? await Task.sleep(nanoseconds: 500_000_000)
        let afterTimer = await WebDataStoreRegistry.shared.summary(for: .portal)
        check(
            "old_document_cannot_repopulate_storage",
            !afterTimer.hasData && previousView.url?.absoluteString == "about:blank")
        check("clear_does_not_autoload", browser.webView.url == nil && !browser.isLoading)
        check(
            "clear_keeps_completed_downloads",
            completed.allSatisfy { item in
                app.downloads.items.contains { $0.id == item.id && $0.state == .completed }
            })
        app.downloads.clear()
        check("download_cleanup", app.downloads.items.isEmpty && app.downloads.totalBytes == 0)
        let retentionRoot = FileManager.default.temporaryDirectory.appendingPathComponent("retention-fixture-" + UUID().uuidString)
        try! FileManager.default.createDirectory(at: retentionRoot, withIntermediateDirectories: true)
        let retentionItems = [0.0, 172800.0, 691200.0].map { age in
            DownloadItem(id: UUID(), site: .portal, filename: "fixture.pdf", createdAt: Date().addingTimeInterval(-age), state: .completed)
        }
        for item in retentionItems {
            let folder = retentionRoot.appendingPathComponent(item.id.uuidString)
            try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try! Data("synthetic".utf8).write(to: folder.appendingPathComponent(item.filename))
        }
        try! JSONEncoder().encode(retentionItems).write(to: retentionRoot.appendingPathComponent("index.json"))
        let weekly = DownloadCoordinator(directory: retentionRoot); weekly.start(retention: .week)
        check("download_retention_week", weekly.items.count == 2)
        let daily = DownloadCoordinator(directory: retentionRoot); daily.start(retention: .day)
        check("download_retention_day", daily.items.count == 1)
        let nextLaunch = DownloadCoordinator(directory: retentionRoot); nextLaunch.start(retention: .session)
        check("download_retention_session", nextLaunch.items.isEmpty && retentionItems.allSatisfy { nextLaunch.fileURL(for: $0) == nil })
        try? FileManager.default.removeItem(at: retentionRoot)
        let endpoints = Dictionary(uniqueKeysWithValues: SiteID.allCases.map { ($0, base.appendingPathComponent("diagnostic")) })
        let diagnostic = NetworkDiagnostics(endpoints: endpoints)
        diagnostic.run()
        check("diagnostic_four_head_responses", await wait { !diagnostic.isRunning && diagnostic.results.count == 4 && diagnostic.results.allSatisfy { $0.message.contains("HTTP 302") } })
        let metrics = try? await URLSession.shared.data(from: base.appendingPathComponent("metrics"))
        let counters = metrics.flatMap { try? JSONSerialization.jsonObject(with: $0.0) as? [String: Int] }
        check("diagnostic_no_cookie_no_auth_no_redirect", counters?["heads"] == 4 && counters?["cookie_headers"] == 0 && counters?["redirect_followed"] == 0)
        check("diagnostic_report_redacted", !diagnostic.report.contains("127.0.0.1") && !diagnostic.report.contains("synthetic") && !diagnostic.report.contains("http://"))
        let now = Date()
        settings.biometricLockEnabled = true
        settings.lockDelay = .minute
        let delayed = AppLockController()
        delayed.setInactive(settings: settings, now: now)
        delayed.setActive(settings: settings, now: now.addingTimeInterval(59))
        check("lock_delay_before_threshold", !delayed.isLocked && !delayed.isPrivacyCovered)
        delayed.setInactive(settings: settings, now: now)
        delayed.setActive(settings: settings, now: now.addingTimeInterval(60))
        check("lock_delay_at_threshold", delayed.isLocked)
        settings.biometricLockEnabled = false
        settings.hideInAppSwitcher = true
        if let scene = window?.windowScene {
            let shield = PrivacyShieldController()
            let lock = AppLockController()
            keep += [shield, lock]
            shield.attach(to: scene, lock: lock, settings: settings)
            let modal = UIViewController()
            window?.rootViewController?.present(modal, animated: false)
            lock.setInactive(settings: settings)
            check(
                "privacy_shield_over_modal",
                shield.isVisible && scene.windows.contains { !$0.isHidden && $0.windowLevel > .alert })
            lock.setActive(settings: settings)
            check("privacy_shield_removed_on_return", !shield.isVisible)
            modal.dismiss(animated: false)
        }
        let authentication = MockAuthenticator()
        let guarded = AppLockController(authenticator: authentication)
        guarded.lock(); authentication.throwsCancellation = true
        await guarded.unlock()
        check("authentication_cancel_keeps_locked", guarded.isLocked && !guarded.isAuthenticating)
        authentication.throwsCancellation = false; authentication.success = false
        await guarded.unlock()
        check("authentication_failure_keeps_locked", guarded.isLocked)
        authentication.success = true
        await guarded.unlock()
        check("authentication_success_unlocks", !guarded.isLocked && !guarded.isAuthenticating)
        authentication.isAvailable = false; guarded.lock()
        await guarded.unlock()
        check("authentication_unavailable_keeps_locked", guarded.isLocked && guarded.lastMessage != nil)
        let output: [String: Any] = [
            "completed": true, "checks": results,
            "passed": results.allSatisfy { $0["passed"] as? Bool == true },
            "date": ISO8601DateFormatter().string(from: Date()),
        ]
        let data = try! JSONSerialization.data(
            withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("regression-results.json")
        try! data.write(to: url)
        print(String(data: data, encoding: .utf8)!)
        exit(results.allSatisfy { $0["passed"] as? Bool == true } ? 0 : 1)
    }
}

@MainActor final class RegressionSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(
        _ scene: UIScene, willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let scene = scene as? UIWindowScene, let app = UIApplication.shared.delegate as? RegressionApp
        else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        self.window = window
        app.window = window
        Task { await app.run() }
    }
}
