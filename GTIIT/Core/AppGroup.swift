import Foundation

/// Shared container for WidgetKit / Live Activity / notification preferences.
enum AppGroup {
    static let identifier = "group.io.github.optmst0118.gtiit"
    static let isAvailable = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    static let defaults: UserDefaults = isAvailable ? (UserDefaults(suiteName: identifier) ?? .standard) : .standard

    enum Key {
        static let teachingWeek = "shuttle.teachingWeek"
        static let language = "app.language"
        static let favoriteDirection = "shuttle.favoriteDirection"
    }
}
