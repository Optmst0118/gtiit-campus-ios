import Foundation

/// Shared container for WidgetKit / Live Activity / notification preferences.
enum AppGroup {
    static let identifier = "group.io.github.optmst0118.gtiit"
    static let defaults: UserDefaults = UserDefaults(suiteName: identifier) ?? .standard

    enum Key {
        static let teachingWeek = "shuttle.teachingWeek"
        static let language = "app.language"
        static let favoriteDirection = "shuttle.favoriteDirection"
    }
}
