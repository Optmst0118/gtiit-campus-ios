import WebKit

/// 仅在四个校园域名的隔离脚本世界增补配色，不改页面 JS 原型或业务事件。
@MainActor enum WebAppearance {
    private static let marker = "/* GTIIT_WEB_APPEARANCE */"
    private static let world = WKContentWorld.defaultClient
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
        let body = adapter.replacingOccurrences(of: "GTIIT_INITIAL_ENABLED", with: enabled ? "true" : "false")
            .replacingOccurrences(of: "GTIIT_ALLOWED_HOSTS", with: json)
            .replacingOccurrences(of: "GTIIT_CLEANUP_HOSTS", with: cleanupJSON)
        return marker + """
        (() => {
            const allowed = \(json);
            const cleanup = \(cleanupJSON);
            let host = location.hostname;
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
}