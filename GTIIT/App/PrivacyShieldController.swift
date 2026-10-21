import Combine
import SwiftUI

/// 独立于主控制器的遮挡窗口，覆盖分享面板、Safari 与网页弹窗。
@MainActor final class PrivacyShieldController {
    private var window: UIWindow?
    private var subscription: AnyCancellable?
    func attach(to scene: UIWindowScene, lock: AppLockController, settings: AppSettings) {
        guard window?.windowScene !== scene else { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .systemBackground
        window.rootViewController = UIHostingController(
            rootView: PrivacyShieldView(lock: lock).environmentObject(settings))
        self.window = window
        subscription = Publishers.CombineLatest(lock.$isLocked, lock.$isPrivacyCovered).sink {
            [weak window] locked, covered in
            window?.isHidden = !(locked || covered)
        }
    }
    var isVisible: Bool { window?.isHidden == false }
}
private struct PrivacyShieldView: View {
    @ObservedObject var lock: AppLockController
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        Group {
            if lock.isLocked && lock.isActive {
                LockScreenView().environmentObject(lock)
            } else {
                ZStack {
                    Color(uiColor: .systemBackground)
                    Label("GTIIT", systemImage: "lock.shield").font(.title2).foregroundStyle(.secondary)
                }.ignoresSafeArea()
            }
        }
        .preferredColorScheme(settings.appearance.colorScheme)
        .accessibilityAddTraits(.isModal)
    }
}
struct SceneWindowReader: UIViewRepresentable {
    let onScene: (UIWindowScene) -> Void
    func makeUIView(context: Context) -> SceneProbe {
        let view = SceneProbe()
        view.onScene = onScene
        return view
    }
    func updateUIView(_ view: SceneProbe, context: Context) {
        view.onScene = onScene
        if let scene = view.window?.windowScene { onScene(scene) }
    }
}
final class SceneProbe: UIView {
    var onScene: ((UIWindowScene) -> Void)?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let scene = window?.windowScene { onScene?(scene) }
    }
}
