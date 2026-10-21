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
        case .faceID: return "面容 ID"
        case .touchID: return "触控 ID"
        default: return "设备密码"
        }
    }
    func authenticate() async throws -> Bool {
        let context = LAContext()
        self.context = context
        defer { self.context = nil }
        context.localizedCancelTitle = "取消"
        context.localizedFallbackTitle = "使用设备密码"
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "解锁 GTIIT，继续浏览校园网页")
    }
}
