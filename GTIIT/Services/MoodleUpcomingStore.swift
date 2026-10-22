import Combine
import WebKit

/// Summaries stay in memory and are cleared together with Moodle's login data.
@MainActor final class MoodleUpcomingStore: ObservableObject {
    @Published private(set) var items: [MoodleWork] = []
    @Published private(set) var refreshing = false
    @Published private(set) var loginRequired = false
    @Published private(set) var updatedAt: Date?
    @Published private(set) var partial = false
    @Published private(set) var error = false
    @Published private(set) var checked = 0
    @Published private(set) var courses = 0
    private var task: Task<Void, Never>?
    private weak var webView: WKWebView?
    private var generation = UUID()

    func refresh(browser: BrowserModel, force: Bool = false, allowed: @escaping () -> Bool) {
        guard !refreshing, allowed(), force || updatedAt.map({ Date().timeIntervalSince($0) > 900 }) != false else { return }
        guard let path = Bundle.main.url(forResource: "moodle-upcoming", withExtension: "js", subdirectory: "CampusData"),
              let script = try? String(contentsOf: path, encoding: .utf8) else { error = true; return }
        refreshing = true; error = false; loginRequired = false
        webView = browser.webView
        let token = UUID(); generation = token
        task = Task { [weak self] in
            guard let self else { return }
            defer { if self.generation == token { self.refreshing = false; self.task = nil } }
            for _ in 0..<30 where browser.isLoading {
                guard allowed(), !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(500))
            }
            guard allowed(), !Task.isCancelled else { return }
            do {
                let value = try await browser.webView.callAsyncJavaScript(script, arguments: ["now": Date().timeIntervalSince1970, "jobID": token.uuidString], in: nil, contentWorld: .page)
                guard self.generation == token, allowed(), !Task.isCancelled else { return }
                guard let string = value as? String, string.utf8.count < 1_000_000 else { throw CocoaError(.coderReadCorrupt) }
                let result = try JSONDecoder().decode(MoodleUpcomingResult.self, from: Data(string.utf8))
                self.loginRequired = result.loginRequired
                guard !result.loginRequired else { self.items = []; self.updatedAt = nil; return }
                self.items = result.items.filter { MoodleWork.safeURL($0.url) != nil }
                self.checked = result.checked; self.courses = result.courses
                self.partial = result.failed > 0 || result.checked < result.courses
                self.updatedAt = Date()
            } catch {
                guard self.generation == token, allowed(), !Task.isCancelled else { return }
                self.error = true
            }
        }
    }
    func invalidate() { updatedAt = nil }

    func cancel(clear: Bool = false) {
        let previous = generation.uuidString
        generation = UUID(); task?.cancel(); task = nil; refreshing = false
        if let webView { Task { try? await webView.evaluateJavaScript("if(window.__gtiitUpcomingJob?.jobID === '\(previous)') window.__gtiitUpcomingJob.abort()") } }
        if clear { items = []; updatedAt = nil; checked = 0; courses = 0; partial = false; error = false; loginRequired = false }
    }
}
