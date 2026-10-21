import SwiftUI

@main
struct GTIITApp: App {
    @StateObject private var app = AppModel()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(app)
                .environmentObject(settings)
                .tint(Theme.accent)
        }
    }
}
