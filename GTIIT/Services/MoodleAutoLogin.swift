import Combine
import Foundation
import WebKit

/// If Moodle has a cached school session, the login page exposes a normal
/// Office 365 SAML link. This helper clicks that existing link once; it never
/// reads or fills an email/password form and never tries to bypass MFA.
@MainActor
final class MoodleAutoLogin {
    private var cancellables: Set<AnyCancellable> = []
    private weak var browser: BrowserModel?
    private var generation = UUID()
    private var busy = false
    private var tried: Set<String> = []
    private var retryTask: Task<Void, Never>?

    func reset() {
        generation = UUID()
        cancellables.removeAll(); retryTask?.cancel(); retryTask = nil
        browser = nil; tried = []; busy = false
    }
    func start(browser: BrowserModel, allowed: @escaping @MainActor () -> Bool) {
        guard self.browser == nil else { return }
        self.browser = browser
        browser.$currentURLString
            .combineLatest(browser.$isLoading)
            .receive(on: RunLoop.main)
            .sink { [weak self] urlString, loading in
                guard !loading, let self, let url = URL(string: urlString) else { return }
                guard Self.isMoodleLogin(url), allowed() else { return }
                Task { @MainActor [weak self] in
                    await self?.tryOffice365Link(browser: browser, loginURL: url, allowed: allowed)
                }
            }
            .store(in: &cancellables)
    }

    private func tryOffice365Link(browser: BrowserModel, loginURL: URL, allowed: @escaping @MainActor () -> Bool) async {
        let key = loginURL.absoluteString
        guard !busy, !tried.contains(key), allowed(), browser.currentURLString == key else { return }
        let token = generation
        busy = true
        defer { busy = false }

        if let raw = try? await browser.webView.evaluateJavaScript(Self.linkProbe) as? String,
           let link = Self.allowedOffice365(raw), token == generation, self.browser === browser, allowed() {
            tried.insert(key)
            browser.load(link)
            return
        }

        // The Office 365 link can render one frame after the login form. Try
        // once more, then leave the page untouched for a manual tap.
        tried.insert(key)
        retryTask?.cancel()
        retryTask = Task { @MainActor [weak self, weak browser] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self, let browser, !Task.isCancelled, allowed(),
                  self.generation == token, browser.currentURLString == key, !self.busy else { return }
            if let raw = try? await browser.webView.evaluateJavaScript(Self.linkProbe) as? String,
               let link = Self.allowedOffice365(raw), self.generation == token, allowed() {
                browser.load(link)
            }
        }
    }

    static func isMoodleLogin(_ url: URL) -> Bool {
        guard url.scheme == "https", url.host == SiteID.moodle.host else { return false }
        return url.path == "/moodle/login/index.php"
    }

    static func allowedOffice365(_ raw: String) -> URL? {
        guard let url = URL(string: raw), url.scheme == "https",
              url.host == SiteID.moodle.host,
              url.path == "/moodle/auth/saml2/login.php",
              url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else { return nil }
        return url
    }

    private static let linkProbe = """
        Array.from(document.querySelectorAll('a[href]'))
          .map(a => a.href)
          .find(href => href.includes('/auth/saml2/login.php')) || ''
        """
}
