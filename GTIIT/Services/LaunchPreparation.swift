import Foundation
import WebKit

enum SitePreparationState: Equatable {
    case preparing, restoringSession, ready, needsLogin, unavailable, deferred
    var title: String {
        switch self {
        case .preparing: return L10n.tr("正在准备")
        case .restoringSession: return L10n.tr("正在恢复会话")
        case .ready: return L10n.tr("页面已就绪")
        case .needsLogin: return L10n.tr("需要登录")
        case .unavailable: return L10n.tr("暂时无法连接")
        case .deferred: return L10n.tr("后台继续准备")
        }
    }
    var isSettled: Bool { self != .preparing && self != .restoringSession }
}

/// 每个进程只准备一次：复用原持久容器及同一个 WKWebView，不读取或填写密码。
@MainActor final class LaunchPreparation: ObservableObject {
    @Published private(set) var hasStarted = false
    @Published private(set) var didFinish = false
    @Published private(set) var states: [SiteID: SitePreparationState] = [:]
    private(set) var models: [BrowserModel] = []
    private var task: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    var settledCount: Int { states.values.filter(\.isSettled).count }
    var isPreparing: Bool { hasStarted && !didFinish }

    func start(models: [BrowserModel], timeout: TimeInterval = 10,
        canRestoreSession: @escaping @MainActor () -> Bool = { true }) {
        guard !hasStarted, !didFinish else { return }
        self.models = models
        states = Dictionary(uniqueKeysWithValues: models.map { ($0.site, .preparing) })
        hasStarted = true
        // 独立于 WebKit 回调；页面脚本无响应也不能无限挡住启动。
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, timeout) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
        task = Task { [weak self] in
            guard let self else { return }
            let started = Date()
            var triedSSO: Set<SiteID> = []
            var settlingUntil: [SiteID: Date] = [:]
            while !Task.isCancelled && !self.didFinish {
                for model in models where self.states[model.site]?.isSettled != true {
                    guard !Task.isCancelled, !self.didFinish else { return }
                    if model.errorText != nil {
                        self.states[model.site] = .unavailable
                        continue
                    }
                    guard model.hasLoadedOnce, !model.isLoading,
                        model.webView.window != nil, model.webView.bounds.width > 0 else { continue }
                    if let until = settlingUntil[model.site], Date() < until { continue }
                    if model.site == .moodle, !triedSSO.contains(.moodle),
                        Self.isMoodleLogin(model.currentURL), canRestoreSession() {
                        triedSSO.insert(.moodle)
                        // 只读取学校登录页上既有的 SSO 链接，不读取表单值、账号或 Cookie。
                        let candidate = try? await model.webView.evaluateJavaScript(
                            "Array.from(document.querySelectorAll('a[href]')).find(a=>a.href.includes('/auth/saml2/login.php'))?.href || ''")
                        guard !Task.isCancelled, !self.didFinish else { return }
                        if let raw = candidate as? String, let url = Self.allowedMoodleSSO(raw), canRestoreSession() {
                            self.states[model.site] = .restoringSession
                            settlingUntil[model.site] = Date().addingTimeInterval(0.6)
                            model.load(url)
                            continue
                        }
                    }
                    let authURL = model.currentURL.map(NavigationPolicy.isAuthentication) ?? false
                    if authURL {
                        self.states[model.site] = .needsLogin
                        continue
                    }
                    let probe = try? await model.webView.evaluateJavaScript(Self.loginFormProbe)
                    guard !Task.isCancelled, !self.didFinish else { return }
                    guard let loginForm = probe as? Bool else {
                        self.states[model.site] = .deferred
                        continue
                    }
                    self.states[model.site] = model.errorText != nil ? .unavailable : loginForm ? .needsLogin : .ready
                }
                let elapsed = Date().timeIntervalSince(started)
                if elapsed >= timeout || self.states.values.allSatisfy(\.isSettled) && elapsed >= 0.7 {
                    self.finish()
                    return
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
    }
    /// 跳过只结束启动遮罩；已经发出的正常网页加载继续，进入标签仍复用原内核。
    func skip() { finish() }
    private func finish() {
        guard !didFinish else { return }
        task?.cancel()
        task = nil
        deadlineTask?.cancel()
        deadlineTask = nil
        for site in states.keys where states[site]?.isSettled != true { states[site] = .deferred }
        didFinish = true
    }
    static func isMoodleLogin(_ url: URL?) -> Bool {
        guard let url, url.scheme == "https", url.host == SiteID.moodle.host else { return false }
        return url.path == "/moodle/login/index.php"
    }
    static func allowedMoodleSSO(_ raw: String) -> URL? {
        guard let url = URL(string: raw), url.scheme == "https", url.host == SiteID.moodle.host,
            url.path == "/moodle/auth/saml2/login.php", url.user == nil, url.password == nil,
            url.port == nil || url.port == 443 else { return nil }
        return url
    }
    private static let loginFormProbe = """
        (() => {
          const fields = document.querySelectorAll('input[type="password"],input[autocomplete="one-time-code"]');
          return Array.from(fields).some(e => e.getClientRects().length > 0 && getComputedStyle(e).visibility !== 'hidden');
        })()
        """
}
