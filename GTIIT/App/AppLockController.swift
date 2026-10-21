import Foundation
import LocalAuthentication

/// 可选的本地门禁：用面容 ID / 触控 ID / 设备密码遮住网页内容。
/// 解锁结果只影响界面可见性，不参与任何网络请求，也不上传任何数据。
@MainActor
final class AppLockController: ObservableObject {
    @Published private(set) var isLocked = false
    @Published private(set) var isAuthenticating = false
    @Published private(set) var lastMessage: String?

    private var biometryContext: LAContext?

    var biometryLabel: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch context.biometryType {
        case .faceID: return "面容 ID"
        case .touchID: return "触控 ID"
        case .opticID: return "光学 ID"
        case .none: return "设备密码"
        @unknown default: return "设备密码"
        }
    }

    var isBiometryAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func lock() {
        guard !isLocked else { return }
        lastMessage = nil
        isLocked = true
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        context.localizedFallbackTitle = "使用密码"

        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            // 设备没有设置密码或生物识别时不把用户挡在外面
            lastMessage = authError?.localizedDescription
            isLocked = false
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "解锁 GTIIT 校园助手，继续查看官网页面"
            )
            if success {
                lastMessage = nil
                isLocked = false
            }
        } catch {
            lastMessage = "验证未通过，可再试一次。"
        }
    }
}
