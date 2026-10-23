import UIKit

/// Central haptic vocabulary for the app.
///
/// Tune the feel here:
/// - light / medium are impact styles;
/// - selection is the small tick used for tab/picker changes;
/// - success / warning are notification patterns;
/// - the Settings toggle writes settings.hapticsEnabled.
@MainActor
enum Haptics {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "settings.hapticsEnabled") as? Bool ?? true
    }

    static func light(intensity: CGFloat = 0.7) {
        guard isEnabled else { return }
        lightGenerator.prepare()
        lightGenerator.impactOccurred(intensity: intensity)
    }

    static func medium(intensity: CGFloat = 0.8) {
        guard isEnabled else { return }
        mediumGenerator.prepare()
        mediumGenerator.impactOccurred(intensity: intensity)
    }

    static func selection() {
        guard isEnabled else { return }
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }

    static func success() {
        guard isEnabled else { return }
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }

    static func warning() {
        guard isEnabled else { return }
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.warning)
    }
}
