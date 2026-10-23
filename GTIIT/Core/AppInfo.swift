import Foundation

enum AppInfo {
    static var displayName: String { L10n.tr("GTIIT 校园助手") }
    static let researchDate = "2026-10-21"

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var versionText: String {
        "\(Bundle.main.infoDictionary?["GTIITReleaseLabel"] as? String ?? version) (\(build))"
    }

    static var tagline: String { L10n.tr("校园服务，一路相连") }
}
