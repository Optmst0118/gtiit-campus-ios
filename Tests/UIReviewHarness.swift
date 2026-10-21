import SwiftUI
import UIKit

/// 独立测试包：用原 App 的完整 RootTabView 检查外观及 Dynamic Type，不进入产品 target。
@main struct UIReviewApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var app: AppModel
    private let environment = ProcessInfo.processInfo.environment
    init() {
        let defaults = UserDefaults(suiteName: "ui-review.preferences")!
        defaults.removePersistentDomain(forName: "ui-review.preferences")
        let settings = AppSettings(defaults: defaults)
        settings.hasSeenWelcome = true
        settings.startupTab = .me
        settings.appearance = ProcessInfo.processInfo.environment["UI_REVIEW_DARK"] == "1" ? .dark : .light
        _settings = StateObject(wrappedValue: settings)
        _app = StateObject(wrappedValue: AppModel(settings: settings))
    }
    var body: some Scene {
        WindowGroup {
            RootTabView().environmentObject(app).environmentObject(settings)
                .tint(Theme.accent)
                .preferredColorScheme(settings.appearance.colorScheme)
                .background(
                    SceneWindowReader { scene in
                        scene.traitOverrides.preferredContentSizeCategory =
                            environment["UI_REVIEW_LARGE_TEXT"] == "1"
                            ? .accessibilityExtraExtraExtraLarge : .large
                    }.frame(width: 0, height: 0))
        }
    }
}
