import WebKit

/// 仅在四个校园域名的隔离脚本世界增补配色，不改页面 JS 原型或业务事件。
@MainActor enum WebAppearance {
    private static let marker = "/* GTIIT_WEB_APPEARANCE */"
    private static let world = WKContentWorld.defaultClient
    private static let insetMarker = "/* GTIIT_PORTAL_BOTTOM_INSET */"
    private static let insets = NSMapTable<WKWebView, NSNumber>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    static func setPortalBottomInset(_ bottom: CGFloat, on webView: WKWebView) {
        let pixels = max(0, Int(bottom.rounded(.up)))
        let script = insetMarker + """
        (() => {
            let host=location.hostname;
            if (!host && location.href==='about:blank') { try { host=new URL(document.baseURI).hostname; } catch (_) {} }
            if(host!=='students.gtiit.edu.cn') return;
            const root=document.documentElement, value='\(pixels)px';
            if(root.style.getPropertyValue('--gtiit-bottom-obstruction')!==value)
                root.style.setProperty('--gtiit-bottom-obstruction',value);
        })();
        """
        if insets.object(forKey: webView)?.intValue != pixels {
            insets.setObject(NSNumber(value: pixels), forKey: webView)
            let controller = webView.configuration.userContentController
            let other = controller.userScripts.filter { !$0.source.hasPrefix(insetMarker) }
            controller.removeAllUserScripts(); other.forEach(controller.addUserScript)
            controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: world))
        }
        webView.evaluateJavaScript(script, in: nil, in: world) { _ in }
    }
    static let officialHosts = SiteID.allCases.map(\.host)
    /// 登录页等也需要清理校徽的域名（只清理，不启用 Dark Reader）。
    static let cleanupHosts = officialHosts + [
        "login.microsoftonline.com", "login.microsoft.com", "microsoftonline.com"
    ]
    static func allows(_ url: URL) -> Bool {
        ["https", "http"].contains(url.scheme?.lowercased() ?? "") && officialHosts.contains(url.host?.lowercased() ?? "")
    }
    private static let engine = resource("darkreader")
    private static let adapter = resource("appearance")
    private static func resource(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js", subdirectory: "WebAppearance") else { return "" }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
    static func script(enabled: Bool) -> String {
        var hosts = officialHosts
        #if DEBUG || GTIIT_REGRESSION
        hosts += ["127.0.0.1", "localhost"]
        #endif
        guard !engine.isEmpty, !adapter.isEmpty,
            let data = try? JSONEncoder().encode(hosts),
            let cleanupData = try? JSONEncoder().encode(cleanupHosts),
            let json = String(data: data, encoding: .utf8),
            let cleanupJSON = String(data: cleanupData, encoding: .utf8) else { return "" }
        let email = UserDefaults.standard.string(forKey: "settings.loginEmail") ?? ""
        let prefill = UserDefaults.standard.object(forKey: "settings.prefillLoginEmail") as? Bool ?? true
        let emailData = try? JSONEncoder().encode(email)
        let emailJSON = emailData.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        let body = adapter.replacingOccurrences(of: "GTIIT_INITIAL_ENABLED", with: enabled ? "true" : "false")
            .replacingOccurrences(of: "GTIIT_DARK_CANVAS", with: Theme.darkCanvasHex)
            .replacingOccurrences(of: "GTIIT_ALLOWED_HOSTS", with: json)
            .replacingOccurrences(of: "GTIIT_CLEANUP_HOSTS", with: cleanupJSON)
            .replacingOccurrences(of: "GTIIT_LOGIN_EMAIL", with: emailJSON)
            .replacingOccurrences(of: "GTIIT_PREFILL_EMAIL", with: prefill ? "true" : "false")
        return marker + """
        (() => {
            const allowed = \(json);
            const cleanup = \(cleanupJSON);
            let host = location.hostname;
            try { if (!host && location.href === 'about:blank') host = new URL(document.baseURI).hostname; } catch (_) {}
            try { if (!host && location.href === 'about:blank' && parent !== self) host = parent.location.hostname; } catch (_) {}
            if (!cleanup.includes(host) && !allowed.includes(host)) return;
            \(engine)
            \(body)
        })();
        """
    }
    static func install(on configuration: WKWebViewConfiguration, enabled: Bool) {
        let controller = configuration.userContentController
        let other = controller.userScripts.filter { !$0.source.hasPrefix(marker) }
        controller.removeAllUserScripts()
        other.forEach(controller.addUserScript)
        let source = script(enabled: enabled)
        guard !source.isEmpty else { return }
        controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: world))
    }
    static func update(_ webView: WKWebView, enabled: Bool) {
        install(on: webView.configuration, enabled: enabled)
        webView.evaluateJavaScript("globalThis.__gtiitAppearance?.setEnabled(\(enabled ? "true" : "false"))", in: nil, in: world) { _ in }
    }

    private static let courseChromeMarker = "/* GTIIT_MOODLE_COURSE_CHROME */"

    /// Course detail pages supply their own native title; strip Moodle's site chrome
    /// while keeping the course content and activity controls intact.
    static func setMoodleCourseChrome(hidden: Bool, on webView: WKWebView, pageHex: String = "#f2f7fa") {
        let source = courseChromeMarker + """
        (() => {
            const id = 'gtiit-moodle-course-chrome';
            let style = document.getElementById(id);
            if (!style) {
                style = document.createElement('style');
                style.id = id;
                (document.head || document.documentElement).appendChild(style);
            }
            style.textContent = 'nav.navbar, .navbar, #page-navbar, .breadcrumb, .drawer, .drawer-toggles, #page-header, #page-footer, .secondary-navigation, .tertiary-navigation, .page-context-header, .activity-header { display: none !important; } body, #page-wrapper, #page { padding-top: 0 !important; margin-top: 0 !important; } html, body, #page, #page-wrapper, #page-content, #region-main, .course-content, .main-inner, .course-content-item, .coursebox { background-color: \(pageHex) !important; }';
        })();
        """
        let controller = webView.configuration.userContentController
        let other = controller.userScripts.filter { !$0.source.hasPrefix(courseChromeMarker) }
        controller.removeAllUserScripts()
        other.forEach(controller.addUserScript)
        if hidden {
            controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: world))
        }
        let immediate = hidden ? source : "document.getElementById('gtiit-moodle-course-chrome')?.remove();"
        webView.evaluateJavaScript(immediate, in: nil, in: world) { _ in }
    }
}