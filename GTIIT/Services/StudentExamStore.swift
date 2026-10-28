import Combine
import WebKit

struct StudentExam: Codable, Identifiable, Hashable {
    let course: String
    let code: String
    let session: String
    let date: String
    let time: String
    let duration: Double
    let venue: String
    var id: String { [code, session, date, time].joined(separator: "|") }
    var start: Date? {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai"); formatter.dateFormat = "yyyy-MM-dd HH:mm"; formatter.isLenient = false
        return formatter.date(from: date + " " + time)
    }
    var valid: Bool { !course.isEmpty && course.count <= 240 && start != nil && duration >= 0 && duration <= 24 }
}

/// Calendar days remain in campus time, including exams outside the next-14-day summary.
enum CalendarExamSelection {
    static func items(_ exams: [StudentExam], range: ClosedRange<Date>, day: Date? = nil, from: Date? = nil) -> [StudentExam] {
        exams.filter { exam in
            guard exam.valid, let date = CampusDate.parse(exam.date), range.contains(date) else { return false }
            if let day { return CampusDate.calendar.isDate(date, inSameDayAs: day) }
            return from.map { date >= $0 } ?? true
        }.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start! < $1.start! }
    }
}

/// The portal's existing, authenticated read-only Dashboard in its own WebKit
/// view. Refresh never navigates the user's portal or touches a form.
@MainActor final class StudentExamStore: NSObject, ObservableObject {
    @Published private(set) var items: [StudentExam] = []
    @Published private(set) var semester = ""
    @Published private(set) var updatedAt: Date?
    @Published private(set) var refreshing = false
    @Published private(set) var loginRequired = false
    @Published private(set) var failed = false
    static let refreshInterval: TimeInterval = 1800
    private let cacheURL: URL
    private var task: Task<Void, Never>?
    private var webView: WKWebView?
    private var attemptedAt: Date?
    private var generation = UUID()
    private struct Snapshot: Codable { let semester: String; let items: [StudentExam]; let updatedAt: Date }
    private struct Result: Decodable { let state: String; let semester: String?; let items: [StudentExam]? }
    var upcoming: [StudentExam] { items.filter { ($0.start ?? .distantPast) >= Date() }.sorted { $0.start! < $1.start! } }
    init(directory: URL? = nil) {
        cacheURL = (directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("StudentExams")) .appendingPathComponent("summary.json")
        super.init()
        if let snapshot = ProtectedCampusCache.read(Snapshot.self, from: cacheURL, maxBytes: 500_000),
           snapshot.updatedAt <= Date(),
           snapshot.items.count <= 500, snapshot.items.allSatisfy(\.valid) {
            items = snapshot.items; semester = snapshot.semester; updatedAt = snapshot.updatedAt
        }
    }
    func accept(semester: String, items: [StudentExam], at date: Date = Date()) throws {
        guard items.count <= 500, items.allSatisfy(\.valid), !semester.isEmpty else { throw CocoaError(.coderReadCorrupt) }
        self.items = Array(Set(items)).sorted { $0.start! < $1.start! }; self.semester = semester; updatedAt = date
        failed = false; loginRequired = false
        try ProtectedCampusCache.write(Snapshot(semester: semester, items: self.items, updatedAt: date), to: cacheURL)
    }
    func refresh(force: Bool = false, allowed: @escaping () -> Bool) {
        guard !refreshing, allowed(), force || (attemptedAt ?? updatedAt).map({ Date().timeIntervalSince($0) >= Self.refreshInterval }) != false else { return }
        guard let url = Bundle.main.url(forResource: "student-exams", withExtension: "js", subdirectory: "CampusData"), let script = try? String(contentsOf: url, encoding: .utf8) else { failed = true; return }
        let config = WKWebViewConfiguration(); config.websiteDataStore = WebDataStoreRegistry.shared.store(for: .portal)
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        self.webView = webView; refreshing = true; failed = false; attemptedAt = Date()
        let token = UUID(); generation = token
        webView.load(URLRequest(url: SiteID.portal.homeURL))
        task = Task { [weak self] in
            guard let self else { return }
            defer { if generation == token { refreshing = false; self.webView?.stopLoading(); self.webView = nil; task = nil } }
            for _ in 0..<60 {
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
                guard allowed(), !Task.isCancelled, generation == token else { return }
                guard let current = webView.url else { continue }
                guard !webView.isLoading else { continue }
                if current.host != SiteID.portal.host {
                    cancel(clear: true); loginRequired = true; return
                }
                do {
                    let raw = try await webView.callAsyncJavaScript(script, arguments: [:], in: nil, contentWorld: .page)
                    guard generation == token, allowed(), !Task.isCancelled else { return }
                    guard let string = raw as? String, string.utf8.count < 500_000 else { throw CocoaError(.coderReadCorrupt) }
                    let result = try JSONDecoder().decode(Result.self, from: Data(string.utf8))
                    if result.state == "login" { cancel(clear: true); loginRequired = true; return }
                    if result.state == "ready", let semester = result.semester, let items = result.items { try accept(semester: semester, items: items); return }
                    if result.state == "changed" { break }
                } catch { if !webView.isLoading { failed = true } }
            }
            if generation == token { failed = true }
        }
    }
    func cancel(clear: Bool = false) {
        generation = UUID(); task?.cancel(); task = nil; webView?.stopLoading(); webView = nil; refreshing = false
        if clear { items = []; semester = ""; updatedAt = nil; attemptedAt = nil; try? FileManager.default.removeItem(at: cacheURL) }
    }
}
