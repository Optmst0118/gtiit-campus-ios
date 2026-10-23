import UIKit

/// Short, deliberate tactile events; one event per interaction.
@MainActor enum Haptics {
    private static let crisp = UIImpactFeedbackGenerator(style: .rigid)
    private static let firm = UIImpactFeedbackGenerator(style: .medium)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let notification = UINotificationFeedbackGenerator()
    private static var lastEvent: TimeInterval = -.infinity
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "settings.hapticsEnabled") as? Bool ?? true
    }
    private static func accept() -> Bool {
        guard isEnabled, UIApplication.shared.applicationState == .active else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastEvent >= 0.09 else { return false }
        lastEvent = now
        return true
    }
    static func prepare() { guard isEnabled else { return }; crisp.prepare(); firm.prepare(); soft.prepare(); notification.prepare() }
    static func light(intensity: CGFloat = 0.9) {
        guard accept() else { return }
        crisp.impactOccurred(intensity: min(1, max(0, intensity))); crisp.prepare()
    }
    static func medium(intensity: CGFloat = 1) {
        guard accept() else { return }
        firm.impactOccurred(intensity: min(1, max(0, intensity))); firm.prepare()
    }
    static func selection() {
        guard accept() else { return }
        soft.impactOccurred(intensity: 0.95); soft.prepare()
    }
    static func success() { guard accept() else { return }; notification.notificationOccurred(.success); notification.prepare() }
    static func warning() { guard accept() else { return }; notification.notificationOccurred(.warning); notification.prepare() }
    static func error() { guard accept() else { return }; notification.notificationOccurred(.error); notification.prepare() }
}
