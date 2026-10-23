import Combine
import WebKit

/// Protected on-device summaries; cleared together with Moodle login data.
@MainActor final class MoodleUpcomingStore: ObservableObject {
    @Published private(set) var items: [MoodleWork] = []
    @Published private(set) var refreshing = false
    @Published private(set) var loginRequired = false
    @Published private(set) var updatedAt: Date?
    @Published private(set) var partial = false
    @Published private(set) var error = false
    @Published private(set) var checked = 0
    @Published private(set) var courses = 0
    @Published private(set) var courseItems: [MoodleCourse] = []
    static let refreshInterval: TimeInterval = 30 * 60
    private struct Cache: Codable {
        let version: Int
        let term: String
        let items: [MoodleWork]
        let updatedAt: Date
        let partial: Bool
        let checked: Int
        let courses: Int
        let courseList: [MoodleCourse]?
    }
    private let cacheURL: URL
    private var attemptedAt: Date?
    init(directory: URL? = nil) {
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MoodleUpcoming", isDirectory: true)
        cacheURL = root.appendingPathComponent("summary.json")
        guard let data = try? Data(contentsOf: cacheURL), data.count < 1_000_000,
              let cache = try? JSONDecoder().decode(Cache.self, from: data), cache.version == 3, cache.term == Self.termKey(),
              cache.updatedAt <= Date(), Date().timeIntervalSince(cache.updatedAt) < 7 * 86400 else { return }
        items = cache.items.filter { MoodleWork.safeURL($0.url) != nil }
        courseItems = cache.courseList ?? []
        updatedAt = cache.updatedAt; partial = cache.partial; checked = cache.checked; courses = cache.courses
    }
    static func currentTerm(now: Date = Date()) -> (year: Int, season: String) {
        if let event = AcademicCalendarStore.events.last(where: {
            $0.verified && $0.en.hasSuffix("semester begins") && ($0.startDate ?? .distantFuture) <= now
        }), let start = event.startDate {
            return (CampusDate.calendar.component(.year, from: start), String(event.en.split(separator: " ")[0]).lowercased())
        }
        let c = CampusDate.calendar.dateComponents([.year, .month], from: now)
        let month = c.month ?? 10, year = c.year ?? 2026
        return (month < 3 ? year - 1 : year, month < 3 || month >= 10 ? "winter" : month < 7 ? "spring" : "summer")
    }
    private static func termKey() -> String {
        let term = currentTerm()
        return "\(term.year)-\(term.season)"
    }
    func accept(_ result: MoodleUpcomingResult, at date: Date = Date()) {
        loginRequired = result.loginRequired
        guard !result.loginRequired else { cancel(clear: true); loginRequired = true; return }
        items = result.items.filter { MoodleWork.safeURL($0.url) != nil }
        checked = result.checked; courses = result.courses
        courseItems = result.courseList ?? []
        partial = result.failed > 0 || result.checked < result.courses
        updatedAt = date; attemptedAt = date
        persist()
    }
    private func persist() {
        guard let updatedAt else { return }
        do {
            var folder = cacheURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            let cache = Cache(version: 3, term: Self.termKey(), items: items, updatedAt: updatedAt, partial: partial, checked: checked, courses: courses, courseList: courseItems)
            try JSONEncoder().encode(cache).write(to: cacheURL, options: [.atomic, .completeFileProtection])
        } catch { /* Retain the current in-memory summary if local storage is unavailable. */ }
    }
    private var task: Task<Void, Never>?
    private weak var webView: WKWebView?
    private var generation = UUID()

    func refresh(browser: BrowserModel, force: Bool = false, allowed: @escaping () -> Bool) {
        guard !refreshing, allowed(), force || (attemptedAt ?? updatedAt).map({ Date().timeIntervalSince($0) >= Self.refreshInterval }) != false else { return }
        guard let path = Bundle.main.url(forResource: "moodle-upcoming", withExtension: "js", subdirectory: "CampusData"),
              let script = try? String(contentsOf: path, encoding: .utf8) else { error = true; return }
        refreshing = true; error = false; loginRequired = false; attemptedAt = Date()
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
                let term = Self.currentTerm()
                let value = try await browser.webView.callAsyncJavaScript(script, arguments: ["now": Date().timeIntervalSince1970, "jobID": token.uuidString, "termYear": term.year, "termSeason": term.season], in: nil, contentWorld: .page)
                guard self.generation == token, allowed(), !Task.isCancelled else { return }
                guard let string = value as? String, string.utf8.count < 1_000_000 else { throw CocoaError(.coderReadCorrupt) }
                let result = try JSONDecoder().decode(MoodleUpcomingResult.self, from: Data(string.utf8))
                self.accept(result)
            } catch {
                guard self.generation == token, allowed(), !Task.isCancelled else { return }
                self.error = true
            }
        }
    }
    func invalidate() { attemptedAt = nil; updatedAt = nil }

    func cancel(clear: Bool = false) {
        let previous = generation.uuidString
        if refreshing { attemptedAt = updatedAt }
        generation = UUID(); task?.cancel(); task = nil; refreshing = false
        if let webView { Task { try? await webView.evaluateJavaScript("if(window.__gtiitUpcomingJob?.jobID === '\(previous)') window.__gtiitUpcomingJob.abort()") } }
        if clear { try? FileManager.default.removeItem(at: cacheURL); attemptedAt = nil; items = []; updatedAt = nil; checked = 0; courses = 0; partial = false; error = false; loginRequired = false }
    }
}
