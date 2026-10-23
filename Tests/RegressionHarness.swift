import SwiftUI
import Combine
import CoreFoundation
import PDFKit
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
private final class RetiredViewReference {
    weak var value: WKWebView?
    init(_ value: WKWebView) { self.value = value }
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
            guard let value = try await webView.evaluateJavaScript(source) else { return "undefined" }
            if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue ? "true" : "false" }
            return String(describing: value)
        } catch { return "ERROR \(error)" }
    }
    func metrics() async -> [String: Int]? {
        var request = URLRequest(
            url: base.appendingPathComponent("metrics").appending(queryItems: [
                URLQueryItem(name: "nonce", value: UUID().uuidString)
            ]))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Int]
    }
    func cachedFetch(_ webView: WKWebView, url: URL) async -> String {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                webView.callAsyncJavaScript(
                    "return await fetch(url, {cache:'force-cache'}).then(r => r.text())",
                    arguments: ["url": url.absoluteString], in: nil, in: .page
                ) { result in
                    switch result {
                    case .success(let value): continuation.resume(returning: String(describing: value))
                    case .failure(let error): continuation.resume(throwing: error)
                    }
                }
            }
        } catch { return "ERROR \(error)" }
    }
    func run() async {
        Theme.configureNavigationAppearance()
        if ProcessInfo.processInfo.environment["REGRESSION_FOCUS"] == "layout" {
            await verifyGlassWebLayout(); finish(); return
        }
        if ProcessInfo.processInfo.environment["REGRESSION_FOCUS"] == "download" {
            await downloadSmoke()
            finish()
            return
        }
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
        await verifyLaunchPreparation()
        await verifyWebAppearance()
        await verifyCampusFeatures()
        await verifyUpcomingReader()
        await verifyGlassWebLayout()
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
        check("download_policy_interruption_is_expected", NavigationPolicy.isExpectedInterruption(NSError(domain: "WebKitErrorDomain", code: 102)))
        check("network_failure_not_suppressed", !NavigationPolicy.isExpectedInterruption(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)))
        check("certificate_failure_not_suppressed", !NavigationPolicy.isExpectedInterruption(NSError(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateUntrusted)))
        model.webView(model.webView, didFailProvisionalNavigation: nil, withError: NSError(domain: "WebKitErrorDomain", code: 102))
        check("download_interruption_no_error_overlay", model.errorText == nil && !model.isLoading)
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

        _ = await model.prepareForDataClear()
        model.releaseDataStoreView()
        let app = AppModel(settings: settings)
        // Loopback fixtures stay inside this test's WebView; external routing is tested above.
        settings.externalLinks = .webView
        let popupOwner = UUID()
        app.downloads.setPopupPresenter(popupOwner, visible: true)
        check("popup_owns_only_download_surface", !app.downloads.presentsOnRoot)
        app.downloads.setPopupPresenter(popupOwner, visible: false)
        check("root_download_surface_restored", app.downloads.presentsOnRoot)
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
        check("popup_restores_browser_window", await wait { browser.webView.window != nil })

        app.toastText = nil
        browser.load(base.appendingPathComponent("file"))
        let initialDownloadFinished = await wait { app.downloads.items.contains { $0.state == .completed } }
        check(
            "renderable_pdf_attachment_download",
            initialDownloadFinished, "\(app.downloads.items)")
        check("real_pdf_download_has_no_error_overlay", browser.errorText == nil)
        check("download_completion_no_duplicate_toast", app.toastText == nil)
        check("completed_download_auto_dismiss", await wait(6) { app.downloads.presentedID == nil })
        check("auto_dismiss_keeps_file", app.downloads.items.contains { $0.state == .completed && app.downloads.fileURL(for: $0) != nil })
        browser.load(base.appendingPathComponent("file"))
        check(
            "same_filename_download_twice",
            await wait { app.downloads.items.filter { $0.state == .completed }.count >= 2 })
        app.downloads.dismissCompletedPresentation()
        check("page_change_dismisses_completed_panel", app.downloads.presentedID == nil && app.downloads.items.filter { $0.state == .completed }.count >= 2)
        let completed = app.downloads.items.filter { $0.state == .completed }
        let urls = completed.compactMap { app.downloads.fileURL(for: $0) }
        check(
            "download_destinations_unique",
            urls.count >= 2 && Set(urls).count == urls.count && app.downloads.totalBytes > 0)
        let beforeInline = app.downloads.items.count
        browser.load(base.appendingPathComponent("inline-pdf"))
        check("inline_pdf_auto_download", await wait {
            app.downloads.items.count > beforeInline && app.downloads.items.first?.state == .completed
        })
        check("download_panel_presented", app.downloads.presentedID != nil && app.downloads.presentedID == app.downloads.items.first?.id)
        if let item = app.downloads.items.first, let url = app.downloads.fileURL(for: item) {
            check("downloads_persist_in_documents", url.path.contains("/Documents/Downloads/"))
        }
        _ = await load(browser, "a")
        let beforePostPDF = app.downloads.items.count
        _ = await js(browser.webView, "document.querySelector('form').action='/post-pdf';document.querySelector('form').submit();'submitted'")
        check("post_pdf_response_downloaded", await wait {
            app.downloads.items.count > beforePostPDF && app.downloads.items.first?.state == .completed
        })
        let pdfMetrics = await metrics()
        check("pdf_no_get_refetch", pdfMetrics?["pdf_posts"] == 1 && pdfMetrics?["pdf_gets"] == 0)
        await verifyPreviewAndLocations(app)
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
        let privatePath = "private-cache/" + UUID().uuidString
        let privateURL = base.appendingPathComponent(privatePath)
        _ = await load(browser, "a")
        _ = await cachedFetch(browser.webView, url: privateURL)
        try? await Task.sleep(nanoseconds: 500_000_000)
        let firstCached = await cachedFetch(browser.webView, url: privateURL)
        let primedBefore = await metrics()
        let secondCached = await cachedFetch(browser.webView, url: privateURL)
        let primed = await metrics()
        let primedHits = primed?["private_cache_hits"] ?? -1
        check(
            "private_response_is_actually_cached",
            primedHits > 0 && primed?["private_cache_hits"] == primedBefore?["private_cache_hits"]
                && firstCached == secondCached, "hits=\(primedHits)")
        _ = await load(browser, "a")
        let previousView = RetiredViewReference(browser.webView)
        await app.clearData(for: .portal)
        let after = await WebDataStoreRegistry.shared.summary(for: .portal)
        check(
            "clear_replaces_webview_and_history",
            browser.webView !== previousView.value && !browser.webView.canGoBack
                && browser.webView.backForwardList.backList.isEmpty && browser.needsReloadAfterClear)
        check(
            "clear_cookie_and_storage",
            after.cookies == 0 && Set(after.types).isSubset(of: WebDataStoreRegistry.cacheTypes),
            "cookies=\(after.cookies), records=\(after.records), types=\(after.types), oldURL=\(previousView.value?.url?.absoluteString ?? "nil")"
        )
        try? await Task.sleep(nanoseconds: 500_000_000)
        let afterTimer = await WebDataStoreRegistry.shared.summary(for: .portal)
        check(
            "old_document_cannot_repopulate_storage",
            afterTimer.cookies == 0 && Set(afterTimer.types).isSubset(of: WebDataStoreRegistry.cacheTypes)
                && (previousView.value == nil || previousView.value?.url?.absoluteString == "about:blank"),
            "types=\(afterTimer.types), oldURL=\(previousView.value?.url?.absoluteString ?? "nil")")
        check("clear_does_not_autoload", browser.webView.url == nil && !browser.isLoading)
        browser.load(base.appendingPathComponent("inspect"))
        _ = await wait { browser.webView.title == "Storage inspector" && !browser.isLoading }
        let afterCached = await cachedFetch(browser.webView, url: privateURL)
        let refetched = await metrics()
        check(
            "clear_removes_actual_cached_response",
            refetched?["private_cache_hits"] == primedHits + 1 && afterCached != firstCached,
            "hits=\(String(describing: refetched?["private_cache_hits"])), before=\(firstCached), after=\(afterCached)"
        )
        let actualStorage = await js(
            browser.webView,
            "JSON.stringify({review:localStorage.getItem('review'),timer:localStorage.getItem('timer'),cookies:document.cookie})"
        )
        check(
            "cleared_origin_storage_is_empty",
            actualStorage.contains("\"review\":null") && actualStorage.contains("\"timer\":null")
                && actualStorage.contains("\"cookies\":\"\""), actualStorage)
        check(
            "clear_keeps_completed_downloads",
            completed.allSatisfy { item in
                app.downloads.items.contains { $0.id == item.id && $0.state == .completed }
            })
        app.downloads.clear()
        check("download_cleanup", app.downloads.items.isEmpty && app.downloads.totalBytes == 0)
        check("retired_store_deleted", WebDataStoreRegistry.shared.pendingCleanupCount == 0)

        for site in SiteID.allCases {
            let cookie = HTTPCookie(properties: [
                .domain: site.host, .path: "/", .name: "scope_fixture", .value: site.rawValue,
                .secure: "TRUE",
            ])!
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                WebDataStoreRegistry.shared.store(for: site).httpCookieStore.setCookie(cookie) {
                    continuation.resume()
                }
            }
        }
        var independent = true
        for site in SiteID.allCases {
            let cookies: [HTTPCookie] = await withCheckedContinuation { continuation in
                WebDataStoreRegistry.shared.store(for: site).httpCookieStore.getAllCookies {
                    continuation.resume(returning: $0)
                }
            }
            independent = independent && cookies.count == 1 && cookies.first?.value == site.rawValue
        }
        check("four_site_data_stores_are_independent", independent)
        await app.clearData(for: .portal)
        var otherSitesPreserved = true
        for site in SiteID.allCases {
            let count = await WebDataStoreRegistry.shared.summary(for: site).cookies
            otherSitesPreserved = otherSitesPreserved && count == (site == .portal ? 0 : 1)
        }
        check("single_clear_preserves_other_sites", otherSitesPreserved)
        await app.clearAllData()
        var allCleared = true
        for site in SiteID.allCases {
            let count = await WebDataStoreRegistry.shared.summary(for: site).cookies
            allCleared = allCleared && count == 0
        }
        check("all_sites_clear_accounts", allCleared && WebDataStoreRegistry.shared.pendingCleanupCount == 0)
        let retentionRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "retention-fixture-" + UUID().uuidString)
        try! FileManager.default.createDirectory(at: retentionRoot, withIntermediateDirectories: true)
        let retentionItems = [0.0, 172800.0, 691200.0].map { age in
            DownloadItem(
                id: UUID(), site: .portal, filename: "fixture.pdf",
                createdAt: Date().addingTimeInterval(-age), state: .completed)
        }
        for item in retentionItems {
            let folder = retentionRoot.appendingPathComponent(item.id.uuidString)
            try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try! Data("synthetic".utf8).write(to: folder.appendingPathComponent(item.filename))
        }
        try! JSONEncoder().encode(retentionItems).write(
            to: retentionRoot.appendingPathComponent("index.json"))
        let weekly = DownloadCoordinator(directory: retentionRoot)
        weekly.start(retention: .week)
        check("download_retention_week", weekly.items.count == 2)
        let daily = DownloadCoordinator(directory: retentionRoot)
        daily.start(retention: .day)
        check("download_retention_day", daily.items.count == 1)
        let nextLaunch = DownloadCoordinator(directory: retentionRoot)
        nextLaunch.start(retention: .session)
        check(
            "download_retention_session",
            nextLaunch.items.isEmpty && retentionItems.allSatisfy { nextLaunch.fileURL(for: $0) == nil })
        try? FileManager.default.removeItem(at: retentionRoot)
        let endpoints = Dictionary(
            uniqueKeysWithValues: SiteID.allCases.map { ($0, base.appendingPathComponent("diagnostic")) })
        let diagnostic = NetworkDiagnostics(endpoints: endpoints)
        diagnostic.run()
        check(
            "diagnostic_four_head_responses",
            await wait {
                !diagnostic.isRunning && diagnostic.results.count == 4
                    && diagnostic.results.allSatisfy { $0.message.contains("HTTP 302") }
            })
        let counters = await metrics()
        check(
            "diagnostic_no_cookie_no_auth_no_redirect",
            counters?["heads"] == 4 && counters?["cookie_headers"] == 0 && counters?["redirect_followed"] == 0
        )
        check(
            "diagnostic_report_redacted",
            !diagnostic.report.contains("127.0.0.1") && !diagnostic.report.contains("synthetic")
                && !diagnostic.report.contains("http://"))
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
        guarded.lock()
        authentication.throwsCancellation = true
        await guarded.unlock()
        check("authentication_cancel_keeps_locked", guarded.isLocked && !guarded.isAuthenticating)
        authentication.throwsCancellation = false
        authentication.success = false
        await guarded.unlock()
        check("authentication_failure_keeps_locked", guarded.isLocked)
        authentication.success = true
        await guarded.unlock()
        check("authentication_success_unlocks", !guarded.isLocked && !guarded.isAuthenticating)
        authentication.isAvailable = false
        guarded.lock()
        await guarded.unlock()
        check("authentication_unavailable_keeps_locked", guarded.isLocked && guarded.lastMessage != nil)
        await studentExamChecks()
        finish()
    }
    func finish() {
        let output: [String: Any] = [
            "focus": ProcessInfo.processInfo.environment["REGRESSION_FOCUS"] ?? "full",
            "completed": true, "runID": ProcessInfo.processInfo.environment["REGRESSION_RUN_ID"] ?? "",
            "checks": results,
            "passed": results.allSatisfy { $0["passed"] as? Bool == true },
            "date": ISO8601DateFormatter().string(from: Date()),
        ]
        let data = try! JSONSerialization.data(
            withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("regression-results.json")
        try! data.write(to: url)
        // 大块控制台 JSON 会阻塞部分 simctl --console 版本；证据已写入文件。
        print("Regression complete:", results.count, "checks; passed:", results.allSatisfy { $0["passed"] as? Bool == true })
        exit(results.allSatisfy { $0["passed"] as? Bool == true } ? 0 : 1)
    }

    private func clientJS(_ webView: WKWebView, _ source: String) async -> String {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(source, in: nil, in: .defaultClient) { result in
                switch result {
                case .success(let value): continuation.resume(returning: String(describing: value))
                case .failure(let error): continuation.resume(returning: "ERROR \(error)")
                }
            }
        }
    }
    private func verifyWebAppearance() async {
        check("appearance_engine_bundled", WebAppearance.script(enabled: true).contains("Dark Reader v4.9.133") && WebAppearance.script(enabled: true).contains("disableProxyInjection: true"))
        check("appearance_exact_school_hosts", SiteID.allCases.allSatisfy { WebAppearance.allows($0.homeURL) } && !WebAppearance.allows(URL(string: "https://login.microsoftonline.com/")!) && !WebAppearance.allows(URL(string: "https://moodle.gtiit.edu.cn.evil.example/")!))
        let portrait = PDFDownloadPlacement(bottomSafeArea: 34, trailingSafeArea: 0)
        let landscape = PDFDownloadPlacement(bottomSafeArea: 21, trailingSafeArea: 62)
        check("pdf_button_larger_and_concentric_portrait", PDFDownloadPlacement.diameter == 60 && portrait.trailingPadding + 30 == portrait.bottomPadding + 34 + 30)
        check("pdf_button_concentric_landscape", landscape.trailingPadding + 62 == landscape.bottomPadding + 21 && landscape.bottomPadding >= 0)
        let suite = "regression.webappearance." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let settings = AppSettings(defaults: defaults)
        settings.hasSeenWelcome = true
        settings.preloadSitesOnLaunch = false
        check("web_dark_default_enabled", settings.webDarkMode && SiteID.allCases.allSatisfy(settings.webDarkModeEnabled))
        settings.originalColorSites.insert(.rooms)
        let restored = AppSettings(defaults: defaults)
        check("per_site_original_colors_persist", !restored.webDarkModeEnabled(for: .rooms) && restored.webDarkModeEnabled(for: .moodle))
        settings.originalColorSites = []
        let app = AppModel(settings: settings)
        let darkBackground = "(() => {const c=getComputedStyle(document.body).backgroundColor.match(/[0-9.]+/g);return c && Number(c[0])<80 && Number(c[1])<80 && Number(c[2])<80})()"
        for site in SiteID.allCases {
            let model = app.browser(for: site)
            model.webView.stopLoading(); model.webView.overrideUserInterfaceStyle = .dark
            model.webView.frame = window!.bounds
            window!.rootViewController!.view.addSubview(model.webView)
            model.load(base.appendingPathComponent("dark-fixture"))
            let loaded = await wait { model.webView.title == "Dark fixture" && !model.isLoading }
            check("\(site.rawValue)_dark_fixture_loaded", loaded)
            let dark = await wait { (await self.js(model.webView, darkBackground)) == "true" }
            check("\(site.rawValue)_dark_background", dark)
            check("\(site.rawValue)_canvas_matches_native_me", await wait { await self.js(model.webView, "getComputedStyle(document.body).backgroundColor==='rgb(14, 20, 28)' && getComputedStyle(document.documentElement).backgroundColor==='rgb(14, 20, 28)'") == "true" })
            check("\(site.rawValue)_page_prototypes_untouched", (await js(model.webView, "window.originalInsertRule===CSSStyleSheet.prototype.insertRule && window.originalDefine===customElements.define")) == "true")
            let geometry = await js(model.webView, "JSON.stringify(Array.from(document.querySelectorAll('#panel,input,select,button')).map(e=>{const r=e.getBoundingClientRect();return [r.x,r.y,r.width,r.height]}))")
            let functional = await js(model.webView, "document.getElementById('name').value==='synthetic' && document.getElementById('password').value==='synthetic-password' && document.getElementById('form').checkValidity() && document.getElementById('disabled').disabled")
            check("\(site.rawValue)_form_values_and_validation_unchanged", functional == "true")
            check("\(site.rawValue)_no_media_or_page_inversion", (await js(model.webView, "['html','body','#qr','#canvas'].every(s=>getComputedStyle(document.querySelector(s)).filter==='none')")) == "true")
            check("\(site.rawValue)_duplicate_brand_logo_hidden", (await js(model.webView, "getComputedStyle(document.getElementById('brand-logo')).display==='none'")) == "true")
            let roles = await js(model.webView, "(() => {const r=getComputedStyle(document.querySelector('.reserved')).backgroundColor.match(/\\d+/g).map(Number),g=getComputedStyle(document.querySelector('.available')).backgroundColor.match(/\\d+/g).map(Number);return r[0]>r[1]*1.3&&g[1]>g[0]*1.3})()")
            check("\(site.rawValue)_availability_color_meaning_preserved", roles == "true")
            _ = await js(model.webView, "document.getElementById('check').click();document.getElementById('dialogButton').click();'clicked'")
            check("\(site.rawValue)_checkbox_and_dialog_work", (await js(model.webView, "document.getElementById('check').checked && window.fixtureClicks===1 && document.getElementById('dialog').open")) == "true")
            _ = await js(model.webView, "document.getElementById('dialog').close(); const s=document.createElement('style');s.textContent='#dynamic{background:#fafafa;color:#111}';document.head.appendChild(s);'dynamic'")
            check("\(site.rawValue)_dynamic_style_adapts", await wait { (await self.js(model.webView, "Number(getComputedStyle(document.getElementById('dynamic')).backgroundColor.match(/\\d+/g)[0])<80")) == "true" })
            if site == .moodle {
                _ = await js(model.webView, "const f=document.createElement('iframe');f.id='theme-frame';f.src='/dark-fixture';document.body.appendChild(f);'frame'")
                check("same_origin_iframe_adapts", await wait { (await self.js(model.webView, "(() => {const b=document.getElementById('theme-frame')?.contentDocument?.body;return b && Number(getComputedStyle(b).backgroundColor.match(/\\d+/g)[0])<80})()")) == "true" })
            }
            settings.originalColorSites.insert(site)
            check("\(site.rawValue)_live_disable_restores_original", await wait { (await self.js(model.webView, "getComputedStyle(document.body).backgroundColor==='rgb(255, 255, 255)'")) == "true" })
            if site == .moodle {
                check("existing_iframe_live_disable", await wait { (await self.js(model.webView, "document.getElementById('theme-frame')?.contentDocument?.body && getComputedStyle(document.getElementById('theme-frame').contentDocument.body).backgroundColor==='rgb(255, 255, 255)'")) == "true" })
            }
            check("\(site.rawValue)_layout_dimensions_unchanged", (await js(model.webView, "JSON.stringify(Array.from(document.querySelectorAll('#panel,input,select,button')).map(e=>{const r=e.getBoundingClientRect();return [r.x,r.y,r.width,r.height]}))")) == geometry)
            check("\(site.rawValue)_isolated_api_hidden_from_page", (await js(model.webView, "typeof globalThis.__gtiitAppearance")) == "undefined")
            settings.originalColorSites.remove(site)
            _ = await wait { (await self.js(model.webView, darkBackground)) == "true" }
            model.webView.overrideUserInterfaceStyle = .light
            check("\(site.rawValue)_light_mode_restores_original", await wait { (await self.js(model.webView, "getComputedStyle(document.body).backgroundColor==='rgb(255, 255, 255)'")) == "true" })
            _ = await model.prepareForDataClear(); model.releaseDataStoreView()
        }
        let externalRouter = TestRouter()
        let excluded = BrowserModel(site: .moodle, router: externalRouter)
        excluded.webView.stopLoading()
        excluded.webView.frame = window!.bounds
        window!.rootViewController!.view.addSubview(excluded.webView)
        excluded.webView.overrideUserInterfaceStyle = .dark
        excluded.webView.loadHTMLString("<title>External auth fixture</title><style>body{background:white;color:black}</style><p>No injected theme</p>", baseURL: URL(string: "https://login.microsoftonline.com/"))
        _ = await wait { excluded.webView.title == "External auth fixture" && !excluded.isLoading }
        check("external_auth_page_no_dark_theme_or_js_proxy", (await js(excluded.webView, "getComputedStyle(document.body).backgroundColor==='rgb(255, 255, 255)' && !document.querySelector('style.darkreader')")) == "true")
        _ = await excluded.prepareForDataClear(); excluded.releaseDataStoreView()
        defaults.removePersistentDomain(forName: suite)
    }

    private func verifyPreviewAndLocations(_ app: AppModel) async {
        let moodle = app.browser(for: .moodle)
        moodle.webView.stopLoading()
        moodle.webView.frame = window!.bounds
        window!.rootViewController!.view.addSubview(moodle.webView)
        let before = app.downloads.items.count
        moodle.load(base.appendingPathComponent("preview-inline"))
        check("moodle_inline_enters_pdfkit", await wait { app.downloads.activePreview?.state == .readable && app.downloads.activePreview?.document?.pageCount == 1 })
        check("preview_not_in_download_records", app.downloads.items.count == before && app.downloads.activePreview?.url?.path.contains("/tmp/") == true)
        check("preview_original_content", app.downloads.activePreview?.document?.string?.contains("Preview fixture") == true)
        if let preview = app.downloads.activePreview {
            let temporary = preview.url
            app.downloads.dismissPresentation()
            check("preview_survives_float_dismissal", preview.document != nil && window?.rootViewController?.presentedViewController != nil)
            preview.saveAction?(); preview.saveAction?()
            check("preview_explicit_save_once", await wait { preview.state == .saved && app.downloads.items.count == before + 1 })
            preview.closeAction?()
            check("preview_closes_and_cleans_temporary", await wait { app.downloads.activePreview == nil && temporary.map { !FileManager.default.fileExists(atPath: $0.path) } == true })
        }
        for path in ["preview-attachment", "preview-once"] {
            let count = app.downloads.items.count
            moodle.load(base.appendingPathComponent(path))
            check("moodle_\(path)_preview", await wait { app.downloads.activePreview?.state == .readable })
            app.downloads.activePreview?.closeAction?()
            _ = await wait { app.downloads.activePreview == nil }
            check("\(path)_close_without_save", app.downloads.items.count == count)
        }
        _ = await load(moodle, "a")
        _ = await js(moodle.webView, "document.querySelector('form').action='/preview-post';document.querySelector('form').submit();'submitted'")
        check("moodle_post_pdf_preview", await wait { app.downloads.activePreview?.state == .readable })
        app.downloads.activePreview?.saveAction?()
        _ = await wait { app.downloads.activePreview?.state == .saved }
        app.downloads.activePreview?.closeAction?()
        _ = await wait { app.downloads.activePreview == nil }
        let counters = await metrics()
        check("preview_no_refetch_for_post_or_once", counters?["preview_posts"] == 1 && counters?["preview_gets"] == 0 && counters?["once_gets"] == 1)
        let chosen = FileManager.default.temporaryDirectory.appendingPathComponent("inflight-location-" + UUID().uuidString)
        try! FileManager.default.createDirectory(at: chosen, withIntermediateDirectories: true)
        try! app.downloads.selectDefaultFolder(chosen)
        let portal = app.browser(for: .portal)
        portal.load(base.appendingPathComponent("slow"))
        check("custom_download_begins_with_captured_location", await wait { app.downloads.items.first?.state == .downloading && app.downloads.items.first?.destinationBookmark != nil })
        let inflightID = app.downloads.items.first?.id
        app.downloads.resetDefaultFolder()
        check("inflight_uses_original_location", await wait(15) {
            app.downloads.items.first(where: { $0.id == inflightID })?.state == .completed
        })
        if let item = app.downloads.items.first(where: { $0.id == inflightID }) {
            check("inflight_external_file_saved_after_default_change", item.destinationBookmark != nil && FileManager.default.fileExists(atPath: chosen.appendingPathComponent(item.filename).path))
            await app.downloads.removeFile(item.id)
        }
        try? FileManager.default.removeItem(at: chosen)
        let count = app.downloads.items.count
        moodle.load(base.appendingPathComponent("preview-invalid"))
        check("invalid_pdf_reports_preview_failure", await wait { app.downloads.activePreview?.state == .failed && app.downloads.activePreview?.document == nil })
        check("invalid_pdf_not_saved", app.downloads.items.count == count)
        app.downloads.activePreview?.closeAction?()
        _ = await wait { app.downloads.activePreview == nil }
        if let item = app.downloads.items.first(where: { $0.site == .moodle && $0.state == .completed }) {
            let originalPresenter = app.downloads.presentController
            var attempts = 0
            app.downloads.presentController = { controller in
                attempts += 1
                if attempts < 3 { return false }
                return originalPresenter?(controller) ?? false
            }
            app.downloads.open(item)
            app.downloads.open(item)
            check("saved_pdf_stable_preview", await wait { app.downloads.activePreview?.state == .saved && app.downloads.activePreview?.document?.pageCount == 1 })
            check("saved_preview_waits_for_transition_and_coalesces_taps", attempts == 3)
            app.downloads.presentController = originalPresenter
            app.downloads.dismissPresentation()
            check("saved_preview_independent_of_popup", app.downloads.activePreview?.document != nil)
            app.downloads.activePreview?.closeAction?()
            _ = await wait { app.downloads.activePreview == nil }
        }
        _ = await load(moodle, "a")
        _ = await js(moodle.webView, "window.open('/preview-attachment','pdf-preview-test');'opened'")
        check("moodle_new_window_pdf_preview", await wait { app.downloads.activePreview?.state == .readable })
        app.downloads.activePreview?.closeAction?()
        _ = await wait { app.downloads.activePreview == nil }
        // 同时清理该测试创建的原生网页子窗口。
        await app.clearData(for: .moodle)
        _ = await wait { window?.rootViewController?.presentedViewController == nil }
        moodle.releaseDataStoreView()
        if let saved = app.downloads.items.first(where: { $0.site == .moodle }), let source = app.downloads.fileURL(for: saved) {
            await verifyDownloadLocation(source)
        }
    }
    private func verifyDownloadLocation(_ source: URL) async {
        let suite = "regression.downloads." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let local = root.appendingPathComponent("local")
        let external = root.appendingPathComponent("chosen")
        try! FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        let center = DownloadCoordinator(directory: local, defaults: defaults)
        center.start(retention: .forever)
        do {
            let original = try await center.savePreview(source, filename: "File 2.pdf", site: .moodle)
            let originalURL = center.fileURL(for: original)
            try center.selectDefaultFolder(external)
            let one = try await center.savePreview(source, filename: "File 10.pdf", site: .moodle)
            let two = try await center.savePreview(source, filename: "File 10.pdf", site: .moodle)
            check("new_location_only_new_downloads", center.fileURL(for: original) == originalURL && originalURL?.path.contains("/local/") == true && center.fileURL(for: one)?.deletingLastPathComponent().resolvingSymlinksInPath().path == external.resolvingSymlinksInPath().path)
            check("external_filename_collision_numbered", one.filename == "File 10.pdf" && two.filename == "File 10 (2).pdf")
            let restored = DownloadCoordinator(directory: local, defaults: defaults)
            restored.start(retention: .forever)
            check("download_location_and_records_survive_relaunch", restored.defaultFolderBookmark != nil && restored.items.count == 3 && restored.fileURL(for: one) == center.fileURL(for: one))
            check("sort_name_natural", DownloadSort.name.ordered([one, original], ascending: true).first?.id == original.id)
            check("sort_name_reverse", DownloadSort.name.ordered([one, original], ascending: false).first?.id == one.id)
            var big = one; big.bytes = 1000
            var small = original; small.bytes = 10
            check("sort_size_bidirectional", DownloadSort.size.ordered([small, big], ascending: false).first?.id == big.id && DownloadSort.size.ordered([small, big], ascending: true).first?.id == small.id)
            check("sort_time_bidirectional", DownloadSort.time.ordered([one, original], ascending: false).first?.id == one.id && DownloadSort.time.ordered([one, original], ascending: true).first?.id == original.id)
            restored.clear()
            check("bulk_cleanup_keeps_external_files", restored.items.count == 2 && FileManager.default.fileExists(atPath: external.appendingPathComponent(one.filename).path))
            let next = DownloadCoordinator(directory: local, defaults: defaults); next.start(retention: .session)
            check("retention_does_not_delete_external", next.items.count == 2)
            await next.removeFile(two.id)
            check("explicit_external_delete_targets_one_file", next.items.count == 1 && !FileManager.default.fileExists(atPath: external.appendingPathComponent(two.filename).path) && FileManager.default.fileExists(atPath: external.appendingPathComponent(one.filename).path))
            try FileManager.default.removeItem(at: external)
            let previousCount = next.items.count
            do { _ = try await next.savePreview(source, filename: "unavailable.pdf", site: .moodle); check("unavailable_location_no_silent_fallback", false) }
            catch { check("unavailable_location_no_silent_fallback", next.items.count == previousCount) }
            next.resetDefaultFolder()
            let back = try await next.savePreview(source, filename: "default.pdf", site: .moodle)
            check("restore_default_download_folder", back.destinationBookmark == nil && next.fileURL(for: back)?.path.contains("/local/") == true)
        } catch { check("download_location_fixture_success", false, "\(error)") }
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }

    private func verifyLaunchPreparation() async {
        let defaults = UserDefaults(suiteName: "regression.launch")!
        defaults.removePersistentDomain(forName: "regression.launch")
        let preferences = AppSettings(defaults: defaults)
        let guarded = AppModel(settings: preferences)
        guarded.prepareLaunchIfAllowed()
        check("preload_waits_for_welcome", !guarded.launch.hasStarted && guarded.launch.models.isEmpty)
        preferences.hasSeenWelcome = true
        guarded.lock.lock()
        guarded.prepareLaunchIfAllowed()
        check("preload_waits_for_unlock", !guarded.launch.hasStarted && guarded.launch.models.isEmpty)
        preferences.preloadSitesOnLaunch = false
        let disabled = AppModel(settings: preferences)
        disabled.prepareLaunchIfAllowed()
        check("preload_setting_skips_network", disabled.launch.didFinish && disabled.launch.models.isEmpty)
        check("preload_setting_persists", !AppSettings(defaults: defaults).preloadSitesOnLaunch)
        check("preload_sso_preserves_school_link", LaunchPreparation.allowedMoodleSSO("https://moodle.gtiit.edu.cn/moodle/auth/saml2/login.php?wants&idp=fixture")?.query?.contains("idp=fixture") == true)
        check("preload_sso_rejects_other_origin", LaunchPreparation.allowedMoodleSSO("https://moodle.gtiit.edu.cn.example.com/moodle/auth/saml2/login.php") == nil)
        check("preload_sso_rejects_cleartext_or_action", LaunchPreparation.allowedMoodleSSO("http://moodle.gtiit.edu.cn/moodle/auth/saml2/login.php") == nil && LaunchPreparation.allowedMoodleSSO("https://moodle.gtiit.edu.cn/moodle/mod/assign/view.php") == nil)

        let router = TestRouter()
        let models = SiteID.allCases.map { BrowserModel(site: $0, router: router) }
        for model in models {
            model.webView.stopLoading()
            model.webView.frame = window!.bounds
            window!.rootViewController!.view.addSubview(model.webView)
            model.webView.loadHTMLString(model.site == .moodle ? "<title>Login</title><input type='password'>" : "<title>Ready</title><p>ready</p>", baseURL: nil)
        }
        check("preload_real_pages_loaded", await wait { models.allSatisfy { $0.hasLoadedOnce && !$0.isLoading && $0.webView.title == ($0.site == .moodle ? "Login" : "Ready") } })
        let identities = models.map { ObjectIdentifier($0.webView) }
        let preparation = LaunchPreparation()
        preparation.start(models: models, timeout: 4)
        check("preload_completes_all_four", await wait(5) { preparation.didFinish && preparation.settledCount == 4 })
        check("preload_marks_login_without_claiming_success", preparation.states[.moodle] == .needsLogin, "\(String(describing: preparation.states[.moodle]))")
        check("preload_other_pages_ready", models.filter { $0.site != .moodle }.allSatisfy { preparation.states[$0.site] == .ready })
        check("preload_reuses_exact_webviews", identities == preparation.models.map { ObjectIdentifier($0.webView) })
        preparation.start(models: [], timeout: 0)
        check("preload_only_once_per_process", preparation.models.count == 4 && preparation.didFinish)
        for model in models { _ = await model.prepareForDataClear(); model.releaseDataStoreView() }

        let slow = BrowserModel(site: .sports, router: router)
        slow.webView.stopLoading()
        slow.webView.frame = window!.bounds
        window!.rootViewController!.view.addSubview(slow.webView)
        slow.load(base.appendingPathComponent("slow-page"))
        _ = await wait { slow.isLoading }
        let deadline = LaunchPreparation()
        let began = Date()
        deadline.start(models: [slow], timeout: 0.2)
        check("preload_deadline_does_not_block_app", await wait(1) { deadline.didFinish } && Date().timeIntervalSince(began) < 1)
        check("preload_timeout_defers_pending_page", deadline.states[.sports] == .deferred)
        let skip = LaunchPreparation()
        skip.start(models: [slow])
        skip.skip()
        check("preload_skip_keeps_navigation_running", skip.didFinish && slow.isLoading)
        _ = await slow.prepareForDataClear()
        slow.releaseDataStoreView()
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

extension RegressionApp {
    func verifyCampusFeatures() async {
        let events = AcademicCalendarStore.events
        check("calendar_both_years_and_bundled_originals", events.count == 85 && AcademicCalendarStore.years.allSatisfy { AcademicCalendarStore.pdfURL(year: $0) != nil })
        check("calendar_all_dates_valid_inclusive", events.allSatisfy { $0.startDate != nil && ($0.end == nil || $0.endDate != nil) && ($0.endDate ?? $0.startDate!) >= $0.startDate! })
        check("calendar_june31_never_normalized", events.filter { $0.end == nil && !$0.verified && $0.raw.contains("31") }.count == 2 && CampusDate.parse("2027-06-31") == nil)
        check("calendar_current_academic_year", AcademicCalendarStore.defaultYear(now: CampusDate.parse("2026-10-22")!) == "2026-2027" && AcademicCalendarStore.defaultYear(now: CampusDate.parse("2026-03-02")!) == "2025-2026")
        check("calendar_festivals_separate_from_holidays", events.contains { $0.en == "Hanukkah" && $0.kind == "festival" } && events.contains { $0.en == "Passover holidays" && $0.kind == "holiday" })
        let course = LocalCourse(name: "Synthetic Physics", code: "S001", group: "L1", weekday: 1, start: "08:00", end: "10:00", room: "TEST-101", building: "Synthetic Building")
        var snapshot = TimetableSnapshot(semester: "2026-27 WINTER", validFrom: "2026-10-12", validUntil: "2027-01-11", courses: [course])
        check("local_timetable_monday_with_room", snapshot.courses(on: CampusDate.parse("2026-10-19")!).first?.room == "TEST-101")
        check("local_timetable_validity_not_indefinite", snapshot.courses(on: CampusDate.parse("2026-10-05")!).isEmpty && snapshot.courses(on: CampusDate.parse("2027-01-18")!).isEmpty)
        var friday = course; friday.id = UUID(); friday.weekday = 5; friday.name = "Synthetic Friday"
        snapshot.courses.append(friday)
        check("local_timetable_verified_makeup_day", snapshot.courses(on: CampusDate.parse("2027-01-11")!).first?.name == "Synthetic Friday")
        check("local_timetable_verified_holiday", snapshot.courses(on: CampusDate.parse("2027-01-01")!).isEmpty)
        check("local_timetable_festival_is_not_day_off", snapshot.courses(on: CampusDate.parse("2026-12-07")!).first?.name == "Synthetic Physics")
        let after = CampusDate.parse("2026-10-19")!.addingTimeInterval(9 * 3600)
        check("local_timetable_next_after_class_start", snapshot.next(after: after)?.0.name == "Synthetic Friday")
        check("local_timetable_time_validation", LocalCourse.minutes("24:00") == nil && LocalCourse.minutes("08:60") == nil && LocalCourse.minutes("8:00") == nil && LocalCourse.minutes("09:15") == 555)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalTimetableStore(directory: folder)
        do {
            try store.save(snapshot)
            let restored = LocalTimetableStore(directory: folder)
            check("local_timetable_persist_and_restore", restored.snapshot?.courses == snapshot.courses)
            let flags = try folder.resourceValues(forKeys: [.isExcludedFromBackupKey])
            check("local_timetable_excluded_from_backup", flags.isExcludedFromBackup == true)
            var invalid = snapshot; invalid.validUntil = "2026-06-31"
            do { try store.save(invalid); check("local_timetable_invalid_save_rejected", false) }
            catch { check("local_timetable_invalid_save_keeps_existing", LocalTimetableStore(directory: folder).snapshot?.courses == snapshot.courses) }
            try store.clear()
            check("local_timetable_clear", store.snapshot == nil && LocalTimetableStore(directory: folder).snapshot == nil)
            try? FileManager.default.removeItem(at: folder)
        } catch { check("local_timetable_storage", false, error.localizedDescription) }
        let suite = "campus.localization.tests"; let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let prefs = AppSettings(defaults: defaults)
        _ = QuickLinkCatalog.highlights
        prefs.language = .english
        check("quick_links_switch_language_live", QuickLinkCatalog.link(for: "moodle.home")?.title == "My courses")
        check("native_language_translation", L10n.tr("设置") == "Settings" && AppTab.me.title == "Me" && L10n.format("还有 %@ 天", "7") == "In 7 days")
        check("native_language_literal_percent", L10n.format("下载中 %@%", "50") == "Downloading 50%")
        check("native_language_persist", AppSettings(defaults: defaults).language == .english)
        let keys = L10n.translations
        check("native_language_dictionary_complete", keys.count >= 505 && keys.values.allSatisfy { !$0.isEmpty })
        let model = AppModel(settings: prefs)
        let browser = model.browser(for: .portal); let original = browser.webView
        prefs.language = .chinese
        check("native_language_preserves_webview_identity", model.browser(for: .portal).webView === original && L10n.tr("设置") == "设置")
        let egg = YilongController(), origin = CGPoint(x: 120, y: 220), time = Date()
        for offset in 0..<5 { egg.tap(at: origin, settings: prefs, now: time.addingTimeInterval(Double(offset) * 0.2)) }
        check("yilong_hidden_before_six_taps", !egg.visible && !prefs.yilongUnlocked)
        egg.tap(at: origin, settings: prefs, now: time.addingTimeInterval(1))
        check("yilong_six_taps_unlock_at_touch", egg.visible && prefs.yilongUnlocked && egg.origin == origin)
        check("yilong_unlock_persist", AppSettings(defaults: defaults).yilongUnlocked)
        egg.close(); check("yilong_dismiss", !egg.visible)
        let interrupted = YilongController()
        for offset in 0..<5 { interrupted.tap(at: origin, settings: prefs, now: time.addingTimeInterval(Double(offset) * 0.2)) }
        interrupted.tap(at: origin, settings: prefs, now: time.addingTimeInterval(5))
        check("yilong_interrupted_taps_do_not_unlock", !interrupted.visible)
        check("yilong_three_view_asset_exists", Bundle.main.url(forResource: "yilong", withExtension: "png", subdirectory: "CampusData") != nil)
        defaults.removePersistentDomain(forName: suite); L10n.language = .chinese
        // Exact product extraction script on synthetic page with the verified school field shape.
        let web = WKWebView(); window?.rootViewController?.view.addSubview(web)
        keep.append(web)
        let fixture = #"""
        <html><head><title>Timetable fixture</title></head><body>
        <select><option>2026-27 WINTER</option></select><div id="host"><div class="konvajs-content"></div></div>
        <input id="guard" value="DO_NOT_CHANGE">
        <script>
        const c={courseCode:'S001',courseName:'Synthetic Mechanics',groupId:'10',type:'L',day:'2',startTime:'08:00:00',endTime:'10:00:00',classNumber:'TEST-101',building:'Synthetic Building',enrolled:true,postPending:false,deletePending:false};
        document.getElementById('host')['__reactFiber$test']={memoizedProps:{},return:{memoizedProps:{groups:[c,{...c,isPreview:true},{...c,enrolled:false},{...c,deletePending:true}]},return:null}};
        </script></body></html>
        """#
        web.loadHTMLString(fixture, baseURL: URL(string: "https://students.gtiit.edu.cn/enrollments")!)
        check("timetable_fixture_ready", await wait { web.title == "Timetable fixture" && !web.isLoading })
        do {
            let result = try await TimetableExtractor.extract(from: web)
            check("timetable_extractor_registered_only", result.courses.count == 1 && result.courses[0].weekday == 2 && result.courses[0].room == "TEST-101" && result.semester == "2026-27 WINTER")
            check("timetable_extractor_read_only", await js(web, "document.getElementById('guard').value") == "DO_NOT_CHANGE")
        } catch { check("timetable_extractor", false, error.localizedDescription) }
        web.loadHTMLString(fixture, baseURL: URL(string: "https://login.microsoftonline.com/enrollments")!)
        _ = await wait { web.url?.host == "login.microsoftonline.com" && !web.isLoading }
        do { _ = try await TimetableExtractor.extract(from: web); check("timetable_rejects_auth_origin", false) }
        catch { check("timetable_rejects_auth_origin", true) }
        web.removeFromSuperview()
    }
}

extension RegressionApp {
    func verifyUpcomingReader() async {
        let web = WKWebView(); keep.append(web)
        window?.rootViewController?.view.addSubview(web)
        let fixture = #"""
        <html><head><title>Upcoming fixture</title></head><body><input id="guard" value="UNCHANGED"><script>
        window.M={cfg:{wwwroot:'https://moodle.gtiit.edu.cn/moodle',sesskey:'SYNTHETIC_ONLY'}};
        window.calls=[];window.testFail=false;window.classifications=[];window.noActive=false;
        window.fetch=async function(url,options={}){
          calls.push({url,method:options.method||'GET'});
          let body=''; const u=new URL(url,location.href);
          if(u.pathname.endsWith('service.php')){
            const q=JSON.parse(options.body)[0];let data;
            if(q.methodname.includes('enrolled_courses')){
              classifications.push(q.args.classification);
              data=noActive?{courses:[],nextoffset:0}:q.args.offset===0?{courses:[{id:1,fullname:'Synthetic Robotics',shortname:'2026Winter_Robotics'},
                {id:9,fullname:'2025Winter Old Course'},{id:10,fullname:'2026Spring Old Course'},
                {id:11,fullname:'2026Winter Future Course',startdate:1792706400},
                {id:12,fullname:'2026Winter Hidden Course',visible:false}],nextoffset:100}:{courses:[{id:2,fullname:'Synthetic Physics',shortname:'2026Winter_Physics'}],nextoffset:0};
            }else data={events:[{name:'Open quiz',modulename:'quiz',eventtype:'open',timestart:1792620000,url:'https://moodle.gtiit.edu.cn/moodle/mod/quiz/view.php?id=77',course:{fullname:'Synthetic Physics'}},{name:'Unsafe',modulename:'assign',eventtype:'due',timestart:1792943940,url:'https://evil.test/moodle/mod/assign/view.php?id=3'}]};
            body=JSON.stringify([{error:false,data}]);
          }else if(u.pathname.endsWith('index.php')){
            if(testFail&&u.searchParams.get('id')==='2')throw Error('UNAVAILABLE');
            body='<a href="https://moodle.gtiit.edu.cn/moodle/mod/assign/view.php?id='+u.searchParams.get('id')+'">Synthetic assignment '+u.searchParams.get('id')+'</a>';
          }else{
            const submitted=u.searchParams.get('id')==='2';
            body='<div class="submissionstatustable"><table><tr><td>Submission status</td><td>'+(submitted?'Submitted for grading':'No attempt')+'</td></tr><tr><td>Due date</td><td>'+(submitted?'2026年10月25日 23:59':'Sunday, 25 October 2026, 11:59 PM')+'</td></tr></table></div>';
          }
          return {ok:true,url:u.href,text:async()=>body};
        };
        </script></body></html>
        """#
        web.loadHTMLString(fixture, baseURL: URL(string: "https://moodle.gtiit.edu.cn/moodle/my/")!)
        check("upcoming_fixture_ready", await wait { web.title == "Upcoming fixture" && !web.isLoading })
        do {
            let script = try String(contentsOf: Bundle.main.url(forResource: "moodle-upcoming", withExtension: "js", subdirectory: "CampusData")!, encoding: .utf8)
            func read() async throws -> MoodleUpcomingResult {
                let raw = try await web.callAsyncJavaScript(script, arguments: ["now": 1792620000, "jobID": "fixture"], in: nil, contentWorld: .page)
                return try JSONDecoder().decode(MoodleUpcomingResult.self, from: Data((raw as! String).utf8))
            }
            let result = try await read()
            check("upcoming_reads_active_course_pages_and_pagination", result.courses == 2 && result.checked == 2 && result.failed == 0)
            check("upcoming_skips_old_terms_future_and_hidden_courses", await js(web, "calls.filter(c=>new URL(c.url).pathname.endsWith('index.php')).every(c=>['1','2'].includes(new URL(c.url).searchParams.get('id')))") == "true")
            check("upcoming_requests_only_inprogress_classification", await js(web, "classifications.length===2&&classifications.every(c=>c==='inprogress')") == "true")
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("upcoming-cache-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: folder) }
            let cache = MoodleUpcomingStore(directory: folder)
            cache.accept(result)
            let restored = MoodleUpcomingStore(directory: folder)
            check("upcoming_summary_survives_store_restart", restored.items.count == 3 && restored.checked == 2 && restored.updatedAt != nil)
            let cachedFile = folder.appendingPathComponent("summary.json")
            #if !targetEnvironment(simulator)
            let protected = (try? FileManager.default.attributesOfItem(atPath: cachedFile.path)[.protectionKey]) as? String
            #endif
            let excluded = (try? folder.resourceValues(forKeys: [.isExcludedFromBackupKey]))?.isExcludedFromBackup
            #if targetEnvironment(simulator)
            // Simulator does not expose iOS Data Protection file attributes.
            check("upcoming_cache_excluded_from_backup", excluded == true)
            #else
            check("upcoming_cache_protected_and_excluded_from_backup", protected == FileProtectionType.complete.rawValue && excluded == true)
            #endif
            let cachedRouter = TestRouter()
            let cachedBrowser = BrowserModel(site: .moodle, router: cachedRouter)
            restored.refresh(browser: cachedBrowser, allowed: { true })
            check("upcoming_recent_cache_does_not_trigger_scan", !restored.refreshing && restored.items.count == 3 && MoodleUpcomingStore.refreshInterval == 1800)
            restored.cancel(clear: true)
            check("upcoming_clear_removes_persistent_summary", !FileManager.default.fileExists(atPath: cachedFile.path) && MoodleUpcomingStore(directory: folder).items.isEmpty)
            let suite = "regression.shortcuts." + UUID().uuidString
            let prefs = UserDefaults(suiteName: suite)!
            defer { prefs.removePersistentDomain(forName: suite) }
            let choices = AppSettings(defaults: prefs)
            check("shortcut_default_entries_preserved", choices.shortcutIDs == CampusShortcut.defaults)
            choices.shortcutIDs.remove("native.calendar"); choices.shortcutIDs.insert("portal.apps")
            check("shortcut_changes_survive_restart", !AppSettings(defaults: prefs).shortcutIDs.contains("native.calendar") && AppSettings(defaults: prefs).shortcutIDs.contains("portal.apps"))
            choices.shortcutIDs = []
            check("shortcut_empty_selection_is_preserved", AppSettings(defaults: prefs).shortcutIDs.isEmpty)
            let robotics = result.items.first { $0.course == "Synthetic Robotics" }
            check("upcoming_assignment_missing_from_timeline_found", robotics?.due == 1792943940 && robotics?.status == "notSubmitted" && robotics?.source == "assignment")
            check("upcoming_chinese_date_and_submitted_status", result.items.first { $0.url.hasSuffix("id=2") }?.due == 1792943940 && result.items.first { $0.url.hasSuffix("id=2") }?.isSubmitted == true)
            check("upcoming_calendar_open_and_dedup", result.items.filter { $0.kind == "quiz" }.count == 1 && result.items.count == 3)
            check("upcoming_unsafe_links_rejected", result.items.allSatisfy { MoodleWork.safeURL($0.url) != nil })
            let safeRequests = await js(web,"calls.every(c=>c.method==='GET'||new URL(c.url).pathname==='/moodle/lib/ajax/service.php')")
            let guardValue = await js(web,"document.getElementById('guard').value")
            check("upcoming_read_only_requests", safeRequests == "true" && guardValue == "UNCHANGED")
            check("upcoming_submitted_not_in_todo", result.items.filter { $0.relevant(now: Date(timeIntervalSince1970: 1792620000)) }.count == 2)
            _ = await js(web,"testFail=true")
            let partial = try await read()
            check("upcoming_failed_course_reports_partial_retains_other_course", partial.failed > 0 && partial.checked == 1 && partial.items.contains { $0.course == "Synthetic Robotics" })
            _ = await js(web,"noActive=true;calls=[]")
            let empty = try await read()
            let noAssignmentRequests = await js(web,"calls.every(c=>!new URL(c.url).pathname.endsWith('index.php'))")
            check("upcoming_empty_active_set_never_falls_back_to_all_courses", empty.courses == 0 && empty.checked == 0 && noAssignmentRequests == "true")
            _ = await js(web,"delete M.cfg.sesskey")
            let loggedOut = try await read()
            check("upcoming_login_required_no_data", loggedOut.loginRequired && loggedOut.items.isEmpty)
        } catch { check("upcoming_reader", false, error.localizedDescription) }
        check("upcoming_url_rejects_actions_and_other_hosts", MoodleWork.safeURL("https://moodle.gtiit.edu.cn/moodle/mod/assign/view.php?id=1&action=editsubmission") == nil && MoodleWork.safeURL("https://evil.test/moodle/mod/assign/view.php?id=1") == nil)
        web.removeFromSuperview()
    }
}

extension RegressionApp {
    func verifyGlassWebLayout() async {
        let suite = "regression.glass." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = AppSettings(defaults: defaults)
        settings.hasSeenWelcome = true; settings.preloadSitesOnLaunch = false; settings.startupTab = .portal
        let app = AppModel(settings: settings)
        let original = window!.rootViewController
        let host = UIHostingController(rootView: RootTabView().environmentObject(app).environmentObject(settings))
        window!.rootViewController = host; window!.makeKeyAndVisible()
        func tabBar(in view: UIView) -> UITabBar? {
            if let bar = view as? UITabBar { return bar }
            for child in view.subviews { if let bar = tabBar(in: child) { return bar } }
            return nil
        }
        for site in SiteID.allCases {
            let browser = app.browser(for: site)
            app.openSite(site)
            browser.webView.loadHTMLString("<title>Glass fixture</title><meta name='viewport' content='width=device-width,initial-scale=1'><style>body{margin:0}#content{height:1800px}button{height:50px}</style><div id='content'>Synthetic long content</div><button id='tail'>Last action</button>", baseURL: site.homeURL)
            let ready = await wait { browser.webView.window != nil && browser.webView.title == "Glass fixture" && !browser.webView.isLoading && tabBar(in: host.view) != nil }
            check("\(site.rawValue)_glass_host_ready", ready)
            guard ready, let bar = tabBar(in: host.view) else { continue }
            host.view.layoutIfNeeded()
            let web = browser.webView, frame = web.convert(web.bounds, to: window), barFrame = bar.convert(bar.bounds, to: window)
            check("\(site.rawValue)_web_extends_under_tab_bar", frame.maxY >= barFrame.maxY - 1 && frame.maxY >= window!.bounds.maxY - 1, "web=\(frame), tab=\(barFrame)")
            let scroll = web.scrollView
            _ = await wait { scroll.contentSize.height > 1800 && web.bounds.height > 0 }
            func hostController(_ controller: UIViewController) -> WebViewHostController? {
                if let value = controller as? WebViewHostController, value.view.window != nil, value.view.subviews.contains(where: { $0 === web }) { return value }
                for child in controller.children { if let value = hostController(child) { return value } }
                return nil
            }
            let tracker = hostController(host)?.navigationScrollView
            scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top), animated: false)
            _ = await wait { tracker?.contentOffset.y == 0 }
            try? await Task.sleep(for: .milliseconds(350))
            let expandedTop = web.convert(web.bounds, to: window).minY
            scroll.setContentOffset(CGPoint(x: 0, y: -80 - scroll.adjustedContentInset.top), animated: false)
            try? await Task.sleep(for: .milliseconds(150))
            check("\(site.rawValue)_pull_keeps_title_stationary", tracker?.contentOffset.y == 0 && abs(web.convert(web.bounds, to: window).minY - expandedTop) < 1)
            scroll.setContentOffset(CGPoint(x: 0, y: 150), animated: false)
            let collapsed = await wait { web.convert(web.bounds, to: self.window).minY < expandedTop - 15 }
            check("\(site.rawValue)_native_title_collapses", collapsed && (tracker?.contentOffset.y ?? 0) > 0, "expanded=\(expandedTop), compact=\(web.convert(web.bounds, to: window).minY)")
            let y = max(-scroll.adjustedContentInset.top, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            scroll.setContentOffset(CGPoint(x: 0, y: y), animated: false)
            try? await Task.sleep(for: .milliseconds(300))
            let bottom = Double(await js(web, "document.getElementById('tail').getBoundingClientRect().bottom")) ?? .infinity
            check("\(site.rawValue)_last_action_scrolls_above_bar", web.convert(web.bounds, to: window).minY + bottom <= barFrame.minY + 1, "tail=\(web.convert(web.bounds, to: window).minY + bottom), bar=\(barFrame.minY), inset=\(scroll.adjustedContentInset.bottom)")
            if site == .portal {
                web.loadHTMLString("<title>Nested glass fixture</title><meta name='viewport' content='width=device-width,initial-scale=1'><style>html,body{margin:0;height:100%;overflow:hidden}main{position:fixed;inset:0;overflow-y:auto;background:linear-gradient(#318fe8,#f2a04e)}section{height:1800px}#fixed{position:fixed;bottom:0;left:10px;height:44px}</style><main><section>Inner scrolling content</section></main><nav aria-label='Checklist steps' id='fixed'>Fixed page action</nav>", baseURL: site.homeURL)
                let nestedReady = await wait { web.title == "Nested glass fixture" && !web.isLoading }
                host.view.layoutIfNeeded()
                try? await Task.sleep(for: .milliseconds(300))
                let fixedBottom = Double(await js(web, "document.getElementById('fixed').getBoundingClientRect().bottom")) ?? .infinity
                check("portal_inner_scroll_fixed_action_above_glass", nestedReady && web.convert(web.bounds, to: window).minY + fixedBottom <= barFrame.minY + 1, "fixed=\(web.convert(web.bounds, to: window).minY+fixedBottom), bar=\(barFrame.minY)")
                scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top), animated: false)
                _ = await js(web, "document.querySelector('main').scrollTop=200; 'done'")
                check("portal_nested_scroll_drives_title", await wait { (tracker?.contentOffset.y ?? 0) > 0 })
                _ = await js(web, "document.querySelector('main').scrollTop=0; 'done'")
                check("portal_nested_scroll_restores_title", await wait { tracker?.contentOffset.y == 0 })
                if #available(iOS 26.0, *) {
                    let clearance = Double((await js(web, "getComputedStyle(document.documentElement).getPropertyValue('--gtiit-bottom-obstruction').trim().replace('px','')"))) ?? 0
                    check("portal_full_viewport_with_inner_scroll_clearance", web.obscuredContentInsets.bottom == 0 && clearance >= barFrame.height - 1)
                }
            }
            // Every site's transport errors share the VPN-capable error view.
            browser.webView(web, didFailProvisionalNavigation: nil, withError: NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost))
            check("\(site.rawValue)_network_error_available", browser.errorText != nil)
            browser.load(base.appendingPathComponent("status-503"))
            check("\(site.rawValue)_http_error_available", await wait { browser.errorText?.contains("503") == true })
        }
        let shared = app.browser(for: .portal).webView
        let first = WebViewHostController(); first.display(shared)
        window!.rootViewController = first; window!.makeKeyAndVisible()
        let firstHost = shared.superview
        let second = WebViewHostController(); second.display(shared)
        first.present(second, animated: false)
        _ = await wait { shared.superview !== firstHost }
        first.display(shared)
        check("shared_webview_background_updates_do_not_steal_modal", shared.superview !== firstHost)
        second.release()
        check("shared_webview_restored_after_modal_release", shared.superview === firstHost)
        second.dismiss(animated: false)
        try? await Task.sleep(for: .milliseconds(150))
        shared.scrollView.setContentOffset(CGPoint(x: 0, y: -shared.scrollView.adjustedContentInset.top), animated: false)
        let delivered: Bool = await withCheckedContinuation { continuation in
            shared.evaluateJavaScript("window.webkit.messageHandlers.gtiitNavigationScroll.postMessage(90); 'sent'", in: nil, in: .defaultClient) { result in
                if case .success = result { continuation.resume(returning: true) }
                else { continuation.resume(returning: false) }
            }
        }
        let rebound = await wait { first.navigationScrollView.contentOffset.y == 90 }
        check("restored_host_rebinds_navigation_scroll", delivered && rebound, "offset=\(first.navigationScrollView.contentOffset.y), delivered=\(delivered)")
        first.release()
        window!.rootViewController = original; window!.makeKeyAndVisible()
        for site in SiteID.allCases {
            let browser = app.browser(for: site)
            _ = await browser.prepareForDataClear(); browser.releaseDataStoreView()
        }
        defaults.removePersistentDomain(forName: suite)
    }
    func downloadSmoke() async {
        let defaults = UserDefaults(suiteName: "regression.download-smoke")!
        defaults.removePersistentDomain(forName: "regression.download-smoke")
        let settings = AppSettings(defaults: defaults)
        settings.hasSeenWelcome = true; settings.preloadSitesOnLaunch = false; settings.externalLinks = .webView
        let app = AppModel(settings: settings)
        keep.append(app)
        let browser = app.browser(for: .portal)
        browser.webView.stopLoading()
        browser.webView.frame = window!.bounds
        window!.rootViewController!.view.addSubview(browser.webView)
        check("download_smoke_page_ready", await load(browser, "a"))
        browser.load(base.appendingPathComponent("file"))
        let completed = await wait(10) { app.downloads.items.contains { $0.state == .completed } }
        check("download_smoke_completed", completed, "url=\(browser.webView.url?.absoluteString ?? "nil") error=\(browser.errorText ?? "none") records=\(app.downloads.items.count)")
    }
    func studentExamChecks() async {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("exam-cache-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = StudentExamStore(directory: folder)
        let item = StudentExam(course: "Synthetic Physics", code: "TEST1001", session: "A", date: "2027-01-20", time: "09:00", duration: 3, venue: "TEST-101")
        do {
            try store.accept(semester: "2026-27 WINTER", items: [item, item])
            let restored = StudentExamStore(directory: folder)
            check("exam_cache_restart_deduplicates", restored.items.count == 1 && restored.items.first == item)
            check("exam_time_uses_beijing", item.start == CampusDate.parse("2027-01-20")?.addingTimeInterval(9 * 3600))
            let values = try folder.resourceValues(forKeys: [.isExcludedFromBackupKey])
            #if targetEnvironment(simulator)
            check("exam_cache_excluded_from_backup", values.isExcludedFromBackup == true)
            #else
            let attrs = try FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent("summary.json").path)
            check("exam_cache_protected_not_backed_up", values.isExcludedFromBackup == true && attrs[.protectionKey] as? String == FileProtectionType.complete.rawValue)
            #endif
            restored.refresh(allowed: { true })
            check("exam_cache_throttles_thirty_minutes", !restored.refreshing && StudentExamStore.refreshInterval == 1800)
            restored.cancel(clear: true)
            check("exam_clear_removes_cache", StudentExamStore(directory: folder).items.isEmpty)
            let invalid = StudentExam(course: "Invalid", code: "TEST", session: "A", date: "2027-02-30", time: "25:00", duration: -1, venue: "")
            do { try store.accept(semester: "Test", items: [invalid]); check("exam_invalid_date_rejected", false) }
            catch { check("exam_invalid_date_rejected", true) }
        } catch { check("exam_cache", false, error.localizedDescription) }
        let config = WKWebViewConfiguration()
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        web.loadHTMLString("<title>Exam fixture</title><select><option selected>2026-27 WINTER</option></select><section id='Exams'>Scheduled Exams 12</section>", baseURL: SiteID.portal.homeURL)
        guard await wait(until: { web.title == "Exam fixture" && !web.isLoading }) else { check("exam_fixture_ready", false); return }
        do {
            let script = try String(contentsOf: Bundle.main.url(forResource: "student-exams", withExtension: "js", subdirectory: "CampusData")!, encoding: .utf8)
            _ = try await web.evaluateJavaScript("""
                const exams=Array.from({length:12},(_,i)=>({courseCode:'TEST'+i,courseName:'Synthetic course '+i,examSession:'A',date:'2027-01-20T00:00:00',time:'09:00:00',duration:2,venues:[{classNumber:'TEST-101'}]}));
                document.getElementById('Exams').__reactFiber$fixture={memoizedState:{memoizedState:[exams,[]],next:null},return:null};
                window.fetch=()=>{throw Error('NO_NETWORK_ALLOWED')};
                true;
                """)
            let result = try await web.callAsyncJavaScript(script, arguments: [:], in: nil, contentWorld: .page) as? String ?? ""
            let decoded = try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any]
            let rows = decoded?["items"] as? [[String: Any]] ?? []
            check("exam_reads_full_pre_pagination_list", decoded?["state"] as? String == "ready" && rows.count == 12)
            check("exam_exports_only_allowlisted_fields", rows.allSatisfy { Set($0.keys) == Set(["course","code","session","date","time","duration","venue"]) })
            _ = try await web.evaluateJavaScript("document.getElementById('Exams').remove()")
            let missing = try await web.callAsyncJavaScript(script, arguments: [:], in: nil, contentWorld: .page) as? String ?? ""
            check("exam_missing_component_not_empty_success", missing.contains("loading"))
        } catch { check("exam_reader", false, error.localizedDescription) }
        web.stopLoading()
        check("native_site_titles_fixed", SiteID.allCases.map(\.nativeTitle) == ["Student", "Moodle dashboard", "GTIT room booking service", "GTIT sports center"])
    }

}
