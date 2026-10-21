import SwiftUI

protocol SettingChoice: RawRepresentable, CaseIterable, Identifiable where RawValue == String {
    var title: String { get }
}
extension SettingChoice { var id: String { rawValue } }
enum AppAppearance: String, SettingChoice {
    case system, light, dark
    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
enum ExternalLinkMode: String, SettingChoice {
    case webView, safariView, systemBrowser
    var title: String {
        switch self {
        case .webView: return "当前网页"
        case .safariView: return "App 内 Safari"
        case .systemBrowser: return "默认浏览器"
        }
    }
}
enum LockDelay: String, SettingChoice {
    case immediately, minute, fiveMinutes
    var title: String {
        switch self {
        case .immediately: return "立即"
        case .minute: return "1 分钟后"
        case .fiveMinutes: return "5 分钟后"
        }
    }
    var seconds: TimeInterval {
        switch self {
        case .immediately: return 0
        case .minute: return 60
        case .fiveMinutes: return 300
        }
    }
}
enum DownloadRetention: String, SettingChoice {
    case session, day, week
    var title: String {
        switch self {
        case .session: return "下次启动时清理"
        case .day: return "1 天"
        case .week: return "7 天"
        }
    }
    var seconds: TimeInterval {
        switch self {
        case .session: return 0
        case .day: return 86_400
        case .week: return 604_800
        }
    }
}

@MainActor final class AppSettings: ObservableObject {
    private let defaults: UserDefaults
    @Published var hasSeenWelcome: Bool {
        didSet { defaults.set(hasSeenWelcome, forKey: "settings.hasSeenWelcome") }
    }
    @Published var biometricLockEnabled: Bool {
        didSet { defaults.set(biometricLockEnabled, forKey: "settings.biometricLock") }
    }
    @Published var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: "settings.appearance") }
    }
    @Published var startupTab: AppTab {
        didSet { defaults.set(startupTab.rawValue, forKey: "settings.startupTab") }
    }
    @Published var defaultBooking: BookingSegment {
        didSet { defaults.set(defaultBooking.rawValue, forKey: "settings.defaultBooking") }
    }
    @Published var externalLinks: ExternalLinkMode {
        didSet { defaults.set(externalLinks.rawValue, forKey: "settings.externalLinks") }
    }
    @Published var lockDelay: LockDelay {
        didSet { defaults.set(lockDelay.rawValue, forKey: "settings.lockDelay") }
    }
    @Published var hideInAppSwitcher: Bool {
        didSet { defaults.set(hideInAppSwitcher, forKey: "settings.hideInAppSwitcher") }
    }
    @Published var restoreLastPage: Bool {
        didSet {
            defaults.set(restoreLastPage, forKey: "settings.restoreLastPage")
            if !restoreLastPage { clearLocations() }
        }
    }
    @Published var downloadRetention: DownloadRetention {
        didSet { defaults.set(downloadRetention.rawValue, forKey: "settings.downloadRetention") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasSeenWelcome = defaults.bool(forKey: "settings.hasSeenWelcome")
        biometricLockEnabled = defaults.bool(forKey: "settings.biometricLock")
        appearance = AppAppearance(rawValue: defaults.string(forKey: "settings.appearance") ?? "") ?? .system
        startupTab = AppTab(rawValue: defaults.string(forKey: "settings.startupTab") ?? "") ?? .portal
        defaultBooking =
            BookingSegment(rawValue: defaults.string(forKey: "settings.defaultBooking") ?? "") ?? .rooms
        externalLinks =
            ExternalLinkMode(rawValue: defaults.string(forKey: "settings.externalLinks") ?? "") ?? .webView
        lockDelay = LockDelay(rawValue: defaults.string(forKey: "settings.lockDelay") ?? "") ?? .immediately
        hideInAppSwitcher = defaults.object(forKey: "settings.hideInAppSwitcher") as? Bool ?? true
        restoreLastPage = defaults.bool(forKey: "settings.restoreLastPage")
        downloadRetention =
            DownloadRetention(rawValue: defaults.string(forKey: "settings.downloadRetention") ?? "")
            ?? .session
    }
    func markWelcomeSeen() { hasSeenWelcome = true }
    func resetWelcome() { hasSeenWelcome = false }
    func initialURL(for site: SiteID) -> URL {
        guard restoreLastPage, let raw = defaults.string(forKey: "location.\(site.rawValue)"),
            let url = URL(string: raw), Self.restorable(url, site: site)
        else { return site.homeURL }
        return url
    }
    func remember(_ url: URL, for site: SiteID) {
        guard restoreLastPage, Self.restorable(url, site: site) else { return }
        defaults.set(url.absoluteString, forKey: "location.\(site.rawValue)")
    }
    static func restorable(_ url: URL, site: SiteID) -> Bool {
        guard url.scheme == "https", url.host == site.homeURL.host, url.user == nil, url.password == nil,
            url.query == nil, url.fragment == nil
        else { return false }
        let path = url.path.lowercased()
        return !["login", "logout", "oauth", "saml", "auth", "callback", "token", "submit", "delete"]
            .contains(where: path.contains)
    }
    func clearLocation(for site: SiteID) { defaults.removeObject(forKey: "location.\(site.rawValue)") }
    func clearLocations() { SiteID.allCases.forEach { clearLocation(for: $0) } }
}
