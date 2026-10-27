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
        let updatedAt: Date?
        let partial: Bool
        let checked: Int
        let courses: Int
        let courseList: [MoodleCourse]?
        var directoryUpdatedAt: Date? = nil
        var readerVersion: Int? = nil
    }
    private let cacheURL: URL
    private var attemptedAt: Date?
    private var retryAfter: Date?
    private var failureCount = 0
    private var directoryUpdatedAt: Date?
    var upcomingDays = 10
    private var needsReaderUpgrade = false
    var priorityCourseIDs: Set<Int> = []
    var onReminderSnapshot: (() -> Void)?
    var onClearReminders: (() -> Void)?
    var status: CampusSummaryStatus {
        if loginRequired { return .needsLogin }
        if refreshing { return updatedAt == nil ? .loading : .refreshing }
        if error { return updatedAt == nil ? .failed : .stale }
        if partial { return .partial }
        return updatedAt == nil ? .notConnected : .current
    }
    private func failedAttempt() {
        error = true
        failureCount = min(failureCount + 1, 4)
        retryAfter = Date().addingTimeInterval(min(300, 15 * pow(2, Double(failureCount))))
    }
    init(directory: URL? = nil) {
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MoodleUpcoming", isDirectory: true)
        cacheURL = root.appendingPathComponent("summary.json")
        guard let data = try? Data(contentsOf: cacheURL), data.count < 5_000_000,
              let cache = try? JSONDecoder().decode(Cache.self, from: data), cache.version == 3, (cache.updatedAt ?? .distantPast) <= Date() else { return }
        courseItems = cache.courseList ?? []
        directoryUpdatedAt = cache.directoryUpdatedAt
        needsReaderUpgrade = cache.readerVersion != 3
        guard cache.term == Self.termKey() else { return }
        items = cache.items.filter { MoodleWork.safeURL($0.url) != nil }
        directoryUpdatedAt = cache.directoryUpdatedAt
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
        guard !result.loginRequired else { cancel(); loginRequired = true; return }
        let previous = Dictionary(items.map { ($0.url, $0) }, uniquingKeysWith: { _, last in last })
        let incoming = result.items.filter { MoodleWork.safeURL($0.url) != nil }.map { item in
            // A submission observed after this scan began outranks its older result.
            if let old = previous[item.url], let stamp = old.checkedAt,
               stamp > (item.checkedAt ?? 0), old.status != "unknown" { return old }
            return item
        }
        if result.failed > 0 || result.checked < result.courses {
            var merged = Dictionary(items.map { ($0.url, $0) }, uniquingKeysWith: { _, last in last })
            for item in incoming {
                if item.status == "unknown", let old = merged[item.url], old.isSubmitted {
                    merged[item.url] = old
                } else { merged[item.url] = item }
            }
            items = Array(merged.values).sorted { $0.priority() < $1.priority() }
        } else { items = incoming }
        needsReaderUpgrade = false
        checked = result.checked; courses = result.courses
        if let list = result.courseList {
            if result.failed > 0 {
                var directory = Dictionary(courseItems.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
                for course in list { directory[course.id] = course }
                courseItems = directory.values.sorted { $0.id < $1.id }
            } else { courseItems = list }
        }
        if result.directoryRefreshed == true { directoryUpdatedAt = date }
        error = false; failureCount = 0; retryAfter = nil
        partial = result.failed > 0 || result.checked < result.courses
        updatedAt = date; attemptedAt = date
        persist()
        onReminderSnapshot?()
    }
    private func persist() {
        guard updatedAt != nil || !courseItems.isEmpty else { return }
        do {
            var folder = cacheURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            let cache = Cache(version: 3, term: Self.termKey(), items: items, updatedAt: updatedAt, partial: partial, checked: checked, courses: courses, courseList: courseItems, directoryUpdatedAt: directoryUpdatedAt, readerVersion: needsReaderUpgrade ? nil : 3)
            try JSONEncoder().encode(cache).write(to: cacheURL, options: [.atomic, .completeFileProtection])
        } catch { /* Retain the current in-memory summary if local storage is unavailable. */ }
    }
    private var task: Task<Void, Never>?
    private weak var webView: WKWebView?
    private var generation = UUID()

    func refresh(browser: BrowserModel, force: Bool = false, allowed: @escaping () -> Bool) {
        guard !refreshing, allowed(), force || retryAfter.map({ $0 <= Date() }) != false else { return }
        guard force || needsReaderUpgrade || (attemptedAt ?? updatedAt).map({ Date().timeIntervalSince($0) >= Self.refreshInterval }) != false else { return }
        guard let script = try? Self.readerScript() else { error = true; return }
        LocalDiagnostics.shared.record("moodleSummaryRefresh")
        refreshing = true; error = false; loginRequired = false
        webView = browser.webView
        let token = UUID(); generation = token
        task = Task { [weak self] in
            guard let self else { return }
            defer { if self.generation == token { self.refreshing = false; self.task = nil } }
            // A freshly created BrowserModel starts with isLoading == false
            // before navigation begins. Wait for a real first load instead of
            // evaluating the summary script against an empty document.
            var waited = 0
            while (waited < 30) && (!browser.hasLoadedOnce || browser.isLoading) {
                guard allowed(), !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(500))
                waited += 1
            }
            guard allowed(), !Task.isCancelled, browser.hasLoadedOnce, !browser.isLoading else {
                self.failedAttempt()
                return
            }
            do {
                let term = Self.currentTerm()
                let directoryJSON = String(data: try JSONEncoder().encode(self.courseItems), encoding: .utf8) ?? "[]"
                let itemsJSON = String(data: try JSONEncoder().encode(self.items), encoding: .utf8) ?? "[]"
                let refreshDirectory = force || (self.directoryUpdatedAt.map { Date().timeIntervalSince($0) >= 6 * 3600 } ?? true)
                let progress = Task { [weak self] in
                    await self?.observeDirectory(browser: browser, token: token, allowed: allowed)
                }
                defer { progress.cancel() }
                let value = try await browser.webView.callAsyncJavaScript(script, arguments: [
                    "now": Date().timeIntervalSince1970, "jobID": token.uuidString,
                    "termYear": term.year, "termSeason": term.season,
                    "cachedDirectoryJSON": directoryJSON, "refreshDirectory": refreshDirectory,
                    "cachedItemsJSON": itemsJSON, "forceDetails": force || self.needsReaderUpgrade, "upcomingDays": self.upcomingDays, "priorityIDs": Array(self.priorityCourseIDs)
                ], in: nil, contentWorld: .page)
                guard self.generation == token, allowed(), !Task.isCancelled else { return }
                guard let string = value as? String, string.utf8.count < 1_000_000 else { throw CocoaError(.coderReadCorrupt) }
                let result = try JSONDecoder().decode(MoodleUpcomingResult.self, from: Data(string.utf8))
                self.accept(result)
                self.attemptedAt = Date()
            } catch {
                guard self.generation == token, allowed(), !Task.isCancelled else { return }
                self.failedAttempt()
            }
        }
    }
    /// A token-scoped, one-shot course preview; it never marks work as fresh.
    /// The parent refresh owns cancellation and the final atomic cache update.
    private func observeDirectory(browser: BrowserModel, token: UUID, allowed: () -> Bool) async {
        while generation == token, !Task.isCancelled, allowed() {
            do {
                let value = try await browser.webView.callAsyncJavaScript("""
                    const p=window.__gtiitUpcomingDirectory;
                    return p?.jobID===jobID ? JSON.stringify(p.courses) : null;
                    """, arguments: ["jobID": token.uuidString], in: nil, contentWorld: .page)
                guard generation == token, !Task.isCancelled, allowed() else { return }
                if let text = value as? String, text.utf8.count < 200_000,
                   let list = try? JSONDecoder().decode([MoodleCourse].self, from: Data(text.utf8)),
                   list.count <= 500, list.allSatisfy({ $0.id > 0 && !$0.name.isEmpty }) {
                    if !list.isEmpty {
                        var directory = Dictionary(courseItems.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
                        for course in list { directory[course.id] = course }
                        courseItems = directory.values.sorted { $0.id < $1.id }
                        persist()
                    }
                    return
                }
            } catch { }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }
    static func readerScript() throws -> String {
        try ["moodle-activity", "moodle-upcoming"].map {
            guard let url = Bundle.main.url(forResource: $0, withExtension: "js", subdirectory: "CampusData") else { throw CocoaError(.fileNoSuchFile) }
            return try String(contentsOf: url, encoding: .utf8)
        }.joined(separator: "\n")
    }

    /// A viewed activity provides immediate evidence after a student submits in-app.
    /// Reads only the status/date DOM, never an attempt form, grade or answer.
    func observeActivity(browser: BrowserModel) {
        guard let pageURL = browser.webView.url, let url = MoodleWork.activityURL(pageURL),
              items.contains(where: { $0.url == url.absoluteString }),
              let path = Bundle.main.url(forResource: "moodle-activity", withExtension: "js", subdirectory: "CampusData"),
              let helper = try? String(contentsOf: path, encoding: .utf8) else { return }
        let token = generation, kind = url.path.contains("/quiz/") ? "quiz" : "assign"
        Task { [weak self, weak browser] in
            guard let self, let browser else { return }
            do {
                let value = try await browser.webView.callAsyncJavaScript(helper + "\nreturn JSON.stringify(readMoodleActivity(document,kind));", arguments: ["kind": kind], in: nil, contentWorld: .page)
                guard self.generation == token, browser.webView.url == pageURL,
                      let string = value as? String, let data = string.data(using: .utf8),
                      let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      result["recognized"] as? Bool == true, let status = result["status"] as? String,
                      ["submitted", "draft", "notSubmitted"].contains(status),
                      let index = self.items.firstIndex(where: { $0.url == url.absoluteString }) else { return }
                self.items[index].status = status
                self.items[index].checkedAt = Date().timeIntervalSince1970
                self.persist(); self.onReminderSnapshot?()
            } catch { }
        }
    }
    func invalidate() { attemptedAt = .distantPast; retryAfter = nil }
    func sessionDidAuthenticate() { retryAfter = nil; attemptedAt = nil; loginRequired = false }

    func cancel(clear: Bool = false) {
        let previous = generation.uuidString
        if refreshing { attemptedAt = updatedAt }
        generation = UUID(); task?.cancel(); task = nil; refreshing = false
        if let webView { Task { try? await webView.evaluateJavaScript("if(window.__gtiitUpcomingJob?.jobID === '\(previous)') window.__gtiitUpcomingJob.abort()") } }
        if clear { onClearReminders?() }
        if clear { directoryUpdatedAt = nil; retryAfter = nil; failureCount = 0; priorityCourseIDs = []; try? FileManager.default.removeItem(at: cacheURL); attemptedAt = nil; items = []; courseItems = []; updatedAt = nil; checked = 0; courses = 0; partial = false; error = false; loginRequired = false }
    }
}
