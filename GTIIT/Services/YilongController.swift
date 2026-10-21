import SpriteKit
import SwiftUI

@MainActor final class YilongController: ObservableObject {
    @Published var visible = false
    private(set) var origin = CGPoint.zero
    private var taps = 0
    private var lastTap = Date.distantPast
    func tap(at point: CGPoint, settings: AppSettings, now: Date = Date()) {
        taps = now.timeIntervalSince(lastTap) <= 1.2 ? taps + 1 : 1
        lastTap = now
        guard taps >= 6 else { return }
        taps = 0; settings.yilongUnlocked = true; show(at: point)
    }
    func show(at point: CGPoint) { origin = point; visible = true }
    func close() { visible = false; taps = 0 }
}

/// Bounded, deterministic lifetime: no timers or physics remain after dismissal.
final class YilongScene: SKScene, SKPhysicsContactDelegate {
    private var textures: [SKTexture] = []
    private var started = false
    private var tick = 0
    var spawnPoint = CGPoint.zero
    var reducedMotion = false
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        physicsWorld.gravity = CGVector(dx: 0, dy: -3.5)
        physicsWorld.contactDelegate = self
        makeEdges()
        if let url = Bundle.main.url(forResource: "yilong", withExtension: "png", subdirectory: "CampusData"), let image = UIImage(contentsOfFile: url.path) {
            let atlas = SKTexture(image: image)
            // The original front crest extends slightly beyond the nominal first third.
            let regions = [CGRect(x: 0, y: 0, width: 0.36, height: 1), CGRect(x: 0.365, y: 0, width: 0.28, height: 1), CGRect(x: 0.655, y: 0, width: 0.345, height: 1)]
            textures = regions.map { SKTexture(rect: $0, in: atlas) }
        }
        guard !started else { return }; started = true
        if reducedMotion {
            for index in 0..<3 { spawn(index: index, staticPosition: true) }
        } else {
            run(.repeat(.sequence([.run { [weak self] in self?.burst() }, .wait(forDuration: 0.12)]), count: 12))
        }
    }
    override func didChangeSize(_ oldSize: CGSize) {
        makeEdges()
        for node in children where node.name == "body" {
            node.position.x = min(max(node.position.x, 36), max(36, size.width - 36))
            node.position.y = min(max(node.position.y, 60), max(60, size.height - 60))
        }
    }
    private func makeEdges() {
        guard size.width > 0, size.height > 0 else { return }
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: 12, y: 12, width: max(1, size.width - 24), height: max(1, size.height - 24)))
        physicsBody?.categoryBitMask = 2; physicsBody?.restitution = 0.8
    }
    func burst() {
        for _ in 0..<3 { spawn(index: tick % 3); tick += 1 }
    }
    private func spawn(index: Int, staticPosition: Bool = false) {
        guard !textures.isEmpty, children.filter({ $0.name == "body" }).count < 48 else { return }
        let body = SKNode(); body.name = "body"
        let sprite = SKSpriteNode(texture: textures[index % textures.count])
        let height: CGFloat = staticPosition ? 110 : CGFloat.random(in: 80...110)
        sprite.size = CGSize(width: height * textures[index % textures.count].size().width / textures[index % textures.count].size().height, height: height)
        sprite.name = "illustration"; body.addChild(sprite)
        body.position = staticPosition ? CGPoint(x: size.width * CGFloat(index + 1) / 4, y: size.height / 2) : CGPoint(x: min(max(spawnPoint.x, 52), size.width - 52), y: min(max(spawnPoint.y, 70), size.height - 70))
        if !staticPosition {
            body.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: sprite.size.width * 0.78, height: height * 0.82))
            let physics = body.physicsBody!
            physics.restitution = 0.82; physics.friction = 0.12; physics.linearDamping = 0.12; physics.angularDamping = 0.3
            physics.mass = 0.12; physics.categoryBitMask = 1; physics.collisionBitMask = 3; physics.contactTestBitMask = 3
            physics.velocity = CGVector(dx: CGFloat.random(in: -390...390), dy: CGFloat.random(in: -150...650))
            physics.angularVelocity = CGFloat.random(in: -4...4)
        }
        addChild(body)
    }
    func didBegin(_ contact: SKPhysicsContact) {
        guard !reducedMotion else { return }
        for body in [contact.bodyA, contact.bodyB] {
            guard let sprite = body.node?.childNode(withName: "illustration"), sprite.action(forKey: "rubber") == nil else { continue }
            sprite.run(.sequence([.group([.scaleX(to: 1.18, duration: 0.07), .scaleY(to: 0.82, duration: 0.07)]), .group([.scaleX(to: 0.96, duration: 0.10), .scaleY(to: 1.04, duration: 0.10)]), .scale(to: 1, duration: 0.12)]), withKey: "rubber")
        }
    }
}
