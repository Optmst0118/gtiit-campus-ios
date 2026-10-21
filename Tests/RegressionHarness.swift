import Combine
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
            let value = try await webView.evaluateJavaScript(source)
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
        let output: [String: Any] = [
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
