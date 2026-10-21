import LocalAuthentication

@MainActor protocol LocalAuthenticating {
    var isAvailable: Bool { get }
    var label: String { get }
    func authenticate() async throws -> Bool
}
@MainActor final class SystemAuthenticator: LocalAuthenticating {
    private var context: LAContext?
    var isAvailable: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) }
    var label: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch context.biometryType {
        case .faceID: return L10n.tr("面容 ID")
        case .touchID: return L10n.tr("触控 ID")
        default: return L10n.tr("设备密码")
        }
    }
    func authenticate() async throws -> Bool {
        let context = LAContext()
        self.context = context
        defer { self.context = nil }
        context.localizedCancelTitle = L10n.tr("取消")
        context.localizedFallbackTitle = L10n.tr("使用设备密码")
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: L10n.tr("解锁 GTIIT，继续浏览校园网页"))
    }
}
