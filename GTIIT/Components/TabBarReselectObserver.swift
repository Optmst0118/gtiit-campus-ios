import SwiftUI
import UIKit

/// Watches the real UIKit tab bar so re-tapping the current tab can be handled.
/// SwiftUI's TabView has no re-selection callback; adding a non-cancelling tap
/// gesture keeps the native bar behaviour (selection, glass, accessibility).
struct TabBarReselectObserver: UIViewRepresentable {
    let currentSelection: () -> AppTab
    let onReselect: (AppTab) -> Void

    func makeUIView(context: Context) -> TabReselectProbeView {
        let view = TabReselectProbeView()
        view.currentSelection = currentSelection
        view.onReselect = onReselect
        return view
    }

    func updateUIView(_ uiView: TabReselectProbeView, context: Context) {
        uiView.currentSelection = currentSelection
        uiView.onReselect = onReselect
        uiView.installIfNeeded()
    }
}

final class TabReselectProbeView: UIView, UIGestureRecognizerDelegate {
    var currentSelection: (() -> AppTab)?
    var onReselect: ((AppTab) -> Void)?
    private var touchDownTab: AppTab?
    private weak var bar: UITabBar?
    private var gesture: UITapGestureRecognizer?
    private var retries = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        installIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        installIfNeeded()
    }

    func installIfNeeded() {
        guard let window else { return }
        guard let found = Self.findTabBar(in: window) else {
            scheduleRetry()
            return
        }
        if bar === found, gesture != nil { return }
        if let gesture, let bar { bar.removeGestureRecognizer(gesture) }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        found.addGestureRecognizer(tap)
        bar = found
        gesture = tap
    }

    private func scheduleRetry() {
        guard retries < 20 else { return }
        retries += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.installIfNeeded()
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let bar else { return }
        let point = recognizer.location(in: bar)
        guard let tab = Self.tab(at: point, in: bar) else { return }
        // Only a tap that started on the already-selected tab counts; tapping a
        // different tab must keep the normal switch behaviour (no home reload).
        guard tab == touchDownTab, tab == currentSelection?() else { return }
        onReselect?(tab)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        touchDownTab = currentSelection?()
        return true
    }

    /// Prefer the tapped button's accessibility/label text: on iOS 26 the
    /// floating tab bar nests its buttons, so frame maths alone is brittle.
    private static func tabLabel(at point: CGPoint, in bar: UITabBar) -> String? {
        var node = bar.hitTest(point, with: nil)
        while let view = node, view !== bar {
            if let label = view.accessibilityLabel, !label.isEmpty { return label }
            if let label = (view as? UILabel)?.text, !label.isEmpty { return label }
            node = view.superview
        }
        return nil
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    private static func findTabBar(in view: UIView) -> UITabBar? {
        if let bar = view as? UITabBar, bar.window != nil, !bar.isHidden { return bar }
        for child in view.subviews {
            if let bar = findTabBar(in: child) { return bar }
        }
        return nil
    }

    private static func tab(at point: CGPoint, in bar: UITabBar) -> AppTab? {
        let tabs = AppTab.allCases
        let buttons = bar.subviews
            .filter { view in
                !view.isHidden && view.alpha > 0.05 && view.isUserInteractionEnabled &&
                    view.frame.width > 8 && view.frame.height > 8 &&
                    view.frame.width < bar.bounds.width * 0.95 &&
                    !(view is UIVisualEffectView)
            }
            .sorted { $0.frame.minX < $1.frame.minX }
        if let label = tabLabel(at: point, in: bar),
            let tab = tabs.first(where: { label.localizedCaseInsensitiveContains($0.title) }) {
            return tab
        }
        if buttons.count == tabs.count,
            let index = buttons.firstIndex(where: { $0.frame.contains(point) }) {
            return tabs[index]
        }
        guard bar.bounds.width > 0 else { return nil }
        let width = bar.bounds.width / CGFloat(tabs.count)
        let index = Int((point.x - bar.bounds.minX) / width)
        return tabs[min(max(index, 0), tabs.count - 1)]
    }
}