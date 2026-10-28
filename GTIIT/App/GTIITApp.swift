import SwiftUI

@main struct GTIITApp: App {
    @StateObject private var app: AppModel
    @StateObject private var settings: AppSettings
    init() {
        LocalDiagnostics.shared.start()
        Theme.configureNavigationAppearance()
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _app = StateObject(wrappedValue: AppModel(settings: settings))
    }
    var body: some Scene {
        WindowGroup {
            appContent.environmentObject(app).environmentObject(settings)
                .environment(\.locale, Locale(identifier: settings.language.rawValue))
                .tint(Theme.accent)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
    @ViewBuilder private var appContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.environment["UI_REVIEW_ACTIVITY"] == "1" {
            NavigationStack { ActivityExamplesView() }
                .onOpenURL { app.handleShuttleURL($0) }
        } else { RootTabView() }
        #else
        RootTabView()
        #endif
    }

}
