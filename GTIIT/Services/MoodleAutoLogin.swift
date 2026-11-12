import Foundation
import WebKit

struct MoodleSSOAttempt {
    private(set) var canAttempt = true
    mutating func finish() { canAttempt = false }
    mutating func authenticated() { canAttempt = true }
}

/// One Office 365 handoff per expired session. The existing WebKit session
/// handles the rest of the school's authentication, including any MFA.
@MainActor
final class MoodleAutoLogin {
    private var attempt = MoodleSSOAttempt()
    private var task: Task<Void, Never>?
    private var generation = UUID()

    func sessionDidAuthenticate() { attempt.authenticated() }

    func stopForLogout() {
        reset()
        attempt.finish()
    }

    func reset() {
        generation = UUID()
        task?.cancel()
        task = nil
        attempt.authenticated()
    }

    func inspect(browser: BrowserModel, allowed: @escaping @MainActor () -> Bool) {
        guard attempt.canAttempt, task == nil, allowed(), browser.hasLoadedOnce, !browser.isLoading,
              let loginURL = browser.webView.url, Self.isMoodleLogin(loginURL) else { return }
        let token = generation
        task = Task { @MainActor [weak self, weak browser] in
            defer { if let self, self.generation == token { self.task = nil } }
            for index in 0..<2 {
                if index > 0 { try? await Task.sleep(for: .milliseconds(700)) }
                guard let self, let browser, !Task.isCancelled, self.generation == token, self.attempt.canAttempt,
                      allowed(), !browser.webView.isLoading, browser.webView.url == loginURL else { return }
                let raw = try? await browser.webView.evaluateJavaScript(Self.linkProbe) as? String
                guard !Task.isCancelled, self.generation == token, self.attempt.canAttempt,
                      allowed(), !browser.webView.isLoading, browser.webView.url == loginURL else { return }
                if let raw, let link = Self.allowedOffice365(raw) {
                    self.attempt.finish()
                    browser.load(link)
                    return
                }
                if index == 1 { self.attempt.finish() }
            }
        }
    }

    static func isMoodleLogin(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == SiteID.moodle.host && url.user == nil && url.password == nil &&
            (url.port == nil || url.port == 443) && ["/moodle/login/index.php", "/moodle/login/"].contains(url.path)
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
        (() => {
          const links = Array.from(document.querySelectorAll('a[href]')).filter(a => {
            const u = new URL(a.href);
            return u.origin === location.origin && u.pathname === '/moodle/auth/saml2/login.php'
              && a.getClientRects().length > 0 && getComputedStyle(a).visibility === 'visible';
          });
          const office = links.find(a => /office[\\s-]*365|microsoft/i.test(
            [a.textContent, a.title, a.getAttribute('aria-label'), a.querySelector('img')?.alt].join(' ')));
          return (office || (links.length === 1 ? links[0] : null))?.href || '';
        })()
        """
}
