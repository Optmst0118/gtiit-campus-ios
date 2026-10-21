import Foundation

struct DiagnosticResult: Identifiable {
    let site: SiteID
    var id: String { site.rawValue }
    let message: String
    let reachable: Bool
    let checkedAt: Date
}
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
    ) { completionHandler(nil) }
}
@MainActor final class NetworkDiagnostics: ObservableObject {
    @Published private(set) var results: [DiagnosticResult] = []
    @Published private(set) var isRunning = false
    private var task: Task<Void, Never>?
    private let endpoints: [SiteID: URL]
    init(endpoints: [SiteID: URL]? = nil) {
        self.endpoints = endpoints ?? Dictionary(uniqueKeysWithValues: SiteID.allCases.map { ($0, $0.homeURL) })
    }
    func run() {
        guard !isRunning else { return }
        isRunning = true
        results = []
        task = Task {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 12
            configuration.timeoutIntervalForResource = 15
            let session = URLSession(
                configuration: configuration, delegate: NoRedirectDelegate(), delegateQueue: nil)
            defer {
                session.invalidateAndCancel()
                isRunning = false
                task = nil
            }
            for site in SiteID.allCases {
                if Task.isCancelled { break }
                var request = URLRequest(url: endpoints[site] ?? site.homeURL)
                request.httpMethod = "HEAD"
                do {
                    let (_, response) = try await session.data(for: request)
                    guard !Task.isCancelled else { break }
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    results.append(
                        DiagnosticResult(
                            site: site, message: "HTTP \(code) · 服务器已响应", reachable: true, checkedAt: Date()))
                } catch {
                    guard !Task.isCancelled else { break }
                    let error = error as NSError
                    results.append(
                        DiagnosticResult(
                            site: site, message: "未连通 · 网络错误 \(error.code)", reachable: false,
                            checkedAt: Date()))
                }
            }
        }
    }
    func cancel() { task?.cancel() }
    var report: String {
        (["GTIIT \(AppInfo.versionText)", "网络连通性检查（不代表已登录或业务可用）"]
            + results.map {
                "\($0.site.displayName) | \($0.site.host) | \($0.message) | \($0.checkedAt.formatted(date: .numeric, time: .shortened))"
            }).joined(separator: "\n")
    }
}
