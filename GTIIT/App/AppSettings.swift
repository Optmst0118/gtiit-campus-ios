import Foundation
import SwiftUI

/// 只保存在本机的偏好设置。App 不收集账号、不接入任何埋点。
@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let welcome = "settings.hasSeenWelcome"
        static let lock = "settings.biometricLock"
    }

    private let defaults: UserDefaults

    @Published var hasSeenWelcome: Bool {
        didSet { defaults.set(hasSeenWelcome, forKey: Keys.welcome) }
    }

    @Published var biometricLockEnabled: Bool {
        didSet { defaults.set(biometricLockEnabled, forKey: Keys.lock) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasSeenWelcome = defaults.bool(forKey: Keys.welcome)
        self.biometricLockEnabled = defaults.bool(forKey: Keys.lock)
    }

    func markWelcomeSeen() {
        hasSeenWelcome = true
    }

    func resetWelcome() {
        hasSeenWelcome = false
    }
}
