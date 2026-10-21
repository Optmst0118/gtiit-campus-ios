import Foundation
import LocalAuthentication

@MainActor final class AppLockController: ObservableObject {
    @Published private(set) var isLocked = false
    @Published private(set) var isAuthenticating = false
    @Published private(set) var lastMessage: String?
    @Published private(set) var isPrivacyCovered = false
    @Published private(set) var isActive = true
    private var inactiveAt: Date?
    private let authenticator: LocalAuthenticating
    init(authenticator: LocalAuthenticating? = nil) {
        self.authenticator = authenticator ?? SystemAuthenticator()
    }
    var biometryLabel: String { authenticator.label }
    var isBiometryAvailable: Bool { authenticator.isAvailable }
    func lock() {
        guard !isLocked else { return }
        lastMessage = nil
        isLocked = true
    }
    func setInactive(settings: AppSettings, now: Date = Date()) {
        // 系统认证面板本身会使 scene inactive，不把它算作新一次离开。
        guard !isAuthenticating else { return }
        if inactiveAt == nil { inactiveAt = now }
        isActive = false
        isPrivacyCovered = settings.hideInAppSwitcher || settings.biometricLockEnabled
        if settings.biometricLockEnabled && settings.lockDelay == .immediately { lock() }
    }
    func setActive(settings: AppSettings, now: Date = Date()) {
        if settings.biometricLockEnabled, let inactiveAt,
            now.timeIntervalSince(inactiveAt) >= settings.lockDelay.seconds
        {
            lock()
        }
        inactiveAt = nil
        isActive = true
        isPrivacyCovered = false
    }
    func unlock() async {
        guard isLocked, isActive, !isAuthenticating else { return }
        guard authenticator.isAvailable else {
            lastMessage = L10n.tr("系统验证暂不可用。请在系统设置中检查设备密码或生物识别，再返回重试。")
            return
        }
        isAuthenticating = true
        defer {
            isAuthenticating = false
        }
        do {
            if try await authenticator.authenticate() {
                isLocked = false
                lastMessage = nil
            }
        } catch { lastMessage = L10n.tr("验证未完成，请重试。") }
    }
}
