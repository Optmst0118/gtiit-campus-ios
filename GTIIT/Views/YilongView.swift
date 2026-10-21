import SpriteKit
import SwiftUI

struct YilongOverlay: View {
    @Environment(\.locale) private var nativeLocale
    @ObservedObject var controller: YilongController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let _ = nativeLocale.identifier

        if controller.visible {
            GeometryReader { proxy in
                ZStack(alignment: .topTrailing) {
                    YilongCanvas(origin: CGPoint(x: controller.origin.x - proxy.frame(in: .global).minX, y: controller.origin.y - proxy.frame(in: .global).minY), reduceMotion: reduceMotion)
                        .allowsHitTesting(false).accessibilityHidden(true)
                    Button { controller.close() } label: {
                        Label(L10n.tr("收起以龙"), systemImage: "xmark").font(.subheadline.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 12)
                    }.buttonStyle(.plain).background(.regularMaterial, in: Capsule())
                        .padding(.top, 8).padding(.trailing, 16)
                }
            }
        }
    }
}
private struct YilongCanvas: UIViewRepresentable {
    let origin: CGPoint
    let reduceMotion: Bool
    func makeUIView(context: Context) -> SKView {
        let view = SKView(); view.backgroundColor = .clear; view.allowsTransparency = true
        view.isUserInteractionEnabled = false; view.preferredFramesPerSecond = 60
        return view
    }
    func updateUIView(_ view: SKView, context: Context) {
        guard view.scene == nil, view.bounds.width > 0 else {
            if view.scene == nil { DispatchQueue.main.async { install(in: view) } }
            return
        }
        install(in: view)
    }
    private func install(in view: SKView) {
        guard view.scene == nil, view.bounds.width > 0 else { return }
        let scene = YilongScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill
        scene.spawnPoint = CGPoint(x: origin.x, y: view.bounds.height - origin.y)
        scene.reducedMotion = reduceMotion
        view.presentScene(scene)
    }
    static func dismantleUIView(_ view: SKView, coordinator: ()) {
        view.scene?.removeAllActions(); view.scene?.removeAllChildren(); view.presentScene(nil)
    }
}
struct YilongSettingsView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    var body: some View {
        let _ = nativeLocale.identifier

        List {
            Section {
                Button(L10n.tr("召唤以龙"), systemImage: "sparkles") {
                    let bounds = UIScreen.main.bounds
                    app.yilong.show(at: CGPoint(x: bounds.midX, y: bounds.midY))
                }
                Button(L10n.tr("收起以龙")) { app.yilong.close() }
            } footer: { Text(L10n.tr("正面、侧面和背面的以龙会弹跳碰撞。减弱动态效果开启时，改为静态展示。")) }
        }.navigationTitle(L10n.tr("以龙")).navigationBarTitleDisplayMode(.inline)
    }
}
