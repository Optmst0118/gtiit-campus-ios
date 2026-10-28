import SwiftUI
import UIKit

/// A single owner for the collapsed sidebar/back pair. Page probes supply the
/// existing navigation action; the split controller supplies geometry/lifetime.
@MainActor protocol SidebarNavigationHosting: AnyObject {
    func updateSidebarBack(_ visible: Bool, action: @escaping () -> Void,
                           coordinator: UIViewControllerTransitionCoordinator?)
    func toggleSidebarNavigation()
}

@MainActor final class SidebarNavigationGlass: UIView {
    let sidebar = UIButton(type: .system)
    let back = UIButton(type: .system)
    private let container: UIVisualEffectView
    private let sidebarGlass: UIVisualEffectView
    private let backGlass: UIVisualEffectView
    private var backVisible = false
    var onSidebar: (() -> Void)?
    var onBack: (() -> Void)?

    override init(frame: CGRect) {
        if #available(iOS 26.0, *) {
            let effect = UIGlassContainerEffect(); effect.spacing = 16
            container = UIVisualEffectView(effect: effect)
            let glass = UIGlassEffect(style: .regular); glass.isInteractive = true
            sidebarGlass = UIVisualEffectView(effect: glass)
            backGlass = UIVisualEffectView(effect: nil)
        } else {
            container = UIVisualEffectView(effect: nil)
            sidebarGlass = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
            backGlass = UIVisualEffectView(effect: nil)
        }
        super.init(frame: frame)
        addSubview(container)
        container.contentView.addSubview(sidebarGlass)
        container.contentView.addSubview(backGlass)
        for (button, glass, symbol, label, identifier) in [
            (sidebar, sidebarGlass, "sidebar.left", L10n.tr("展开侧栏"), "sidebar.reveal"),
            (back, backGlass, "chevron.left", L10n.tr("返回"), "sidebar.back")
        ] {
            button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)), for: .normal)
            button.tintColor = .label
            button.accessibilityLabel = label
            button.accessibilityIdentifier = identifier
            glass.layer.cornerRadius = 22
            glass.clipsToBounds = true
            glass.contentView.addSubview(button)
        }
        sidebar.addTarget(self, action: #selector(reveal), for: .touchUpInside)
        back.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        backGlass.alpha = 0
        back.isEnabled = false
        back.accessibilityElementsHidden = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func reveal() { onSidebar?() }
    @objc private func goBack() { onBack?() }
    override func layoutSubviews() {
        super.layoutSubviews()
        container.frame = bounds
        sidebarGlass.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        backGlass.frame = CGRect(x: backVisible ? 56 : 0, y: 0, width: 44, height: 44)
        sidebar.frame = sidebarGlass.bounds
        back.frame = backGlass.bounds
    }
    func setBackVisible(_ visible: Bool, coordinator: UIViewControllerTransitionCoordinator?) {
        guard backVisible != visible else { return }
        backVisible = visible
        back.isEnabled = visible
        back.accessibilityElementsHidden = !visible
        let changes = {
            if #available(iOS 26.0, *) {
                let glass = UIGlassEffect(style: .regular); glass.isInteractive = true
                self.backGlass.effect = visible ? glass : nil
            } else {
                self.backGlass.effect = visible ? UIBlurEffect(style: .systemThinMaterial) : nil
            }
            self.backGlass.alpha = visible ? 1 : 0
            self.setNeedsLayout(); self.layoutIfNeeded()
        }
        if UIAccessibility.isReduceMotionEnabled || window == nil { changes() }
        else if let coordinator {
            coordinator.animate(alongsideTransition: { _ in changes() })
        } else {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut], animations: changes)
        }
    }
    // The transparent space between controls must not block page interactions.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        sidebarGlass.frame.contains(point) || (backVisible && backGlass.frame.contains(point))
    }
}

struct SidebarNavigationSurface: ViewModifier {
    @Environment(\.campusSidebarNavigation) private var usesSidebar
    @Environment(\.campusSidebarRevealVisible) private var collapsed
    @Environment(\.dismiss) private var dismiss
    let customBack: (() -> Void)?
    let isRoot: Bool
    @State private var integrated = false
    func body(content: Content) -> some View {
        content
            .toolbar { if usesSidebar && integrated { SidebarRevealToolbarSpace() } }
            .navigationBarBackButtonHidden(usesSidebar && integrated && collapsed)
            .background {
                SidebarNavigationProbe(collapsed: collapsed, isRoot: isRoot, customBack: customBack,
                                       fallback: { dismiss() }, attached: { integrated = $0 })
                    .frame(width: 0, height: 0).allowsHitTesting(false)
            }
    }
}

private struct SidebarNavigationProbe: UIViewControllerRepresentable {
    let collapsed: Bool
    let isRoot: Bool
    let customBack: (() -> Void)?
    let fallback: () -> Void
    let attached: (Bool) -> Void
    func makeUIViewController(context: Context) -> ProbeController { ProbeController() }
    func updateUIViewController(_ controller: ProbeController, context: Context) {
        controller.collapsed = collapsed; controller.isRoot = isRoot; controller.customBack = customBack
        controller.fallback = fallback; controller.attached = attached
        controller.refreshSoon()
    }

    final class ProbeController: UIViewController {
        var isRoot = false
        var collapsed = false
        var customBack: (() -> Void)?
        var fallback: (() -> Void)?
        var attached: ((Bool) -> Void)?
        private var queued = false
        private var lastAttached: Bool?
        private let gestureProxy = BackGestureProxy()
        override func loadView() { view = UIView(); view.isUserInteractionEnabled = false }
        override func didMove(toParent parent: UIViewController?) { super.didMove(toParent: parent); refreshSoon() }
        override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); refreshSoon() }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); refreshSoon() }
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            transitionCoordinator?.animate(alongsideTransition: nil) { [weak self] _ in self?.refreshSoon() }
        }
        override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); restoreGesture() }
        func refreshSoon() {
            guard !queued else { return }; queued = true
            DispatchQueue.main.async { [weak self] in self?.queued = false; self?.refresh() }
        }
        private func refresh() {
            var ancestor = parent
            var owner: UIViewController?
            var nav: UINavigationController?
            var host: (any SidebarNavigationHosting)?
            while let controller = ancestor {
                if nav == nil, let navigation = controller as? UINavigationController {
                    nav = navigation
                } else if nav == nil { owner = controller }
                if let hosting = controller as? any SidebarNavigationHosting { host = hosting; break }
                ancestor = controller.parent
            }
            let attached = host != nil
            if lastAttached != attached {
                lastAttached = attached; self.attached?(attached)
            }
            // Modal navigation stacks have no split-controller ancestor.
            guard let host, let nav, let owner, nav.topViewController === owner else { return }
            let hasBack = !isRoot && (nav.viewControllers.first !== owner || customBack != nil)
            host.updateSidebarBack(collapsed && hasBack, action: customBack ?? fallback ?? {}, coordinator: nav.transitionCoordinator)
            if collapsed && hasBack && customBack == nil {
                if let gesture = nav.interactivePopGestureRecognizer, gesture.delegate !== gestureProxy {
                    // A push/pop can hand the gesture from one page probe to
                    // another. Never chain proxies: returning pages would form
                    // a delegate cycle and recurse in responds(to:).
                    var original = gesture.delegate
                    var visited = Set<ObjectIdentifier>()
                    while let proxy = original as? BackGestureProxy {
                        guard visited.insert(ObjectIdentifier(proxy)).inserted else { original = nil; break }
                        original = proxy.original
                    }
                    gestureProxy.original = original; gestureProxy.navigation = nav
                    gesture.delegate = gestureProxy
                }
            } else { restoreGesture() }
        }
        private func restoreGesture() {
            if let gesture = gestureProxy.navigation?.interactivePopGestureRecognizer, gesture.delegate === gestureProxy {
                gesture.delegate = gestureProxy.original
            }
        }
    }
}

/// Preserve UIKit's other gesture arbitration while enabling the native pop
/// gesture when its stock back button is represented by the shared glass pair.
@MainActor private final class BackGestureProxy: NSObject, UIGestureRecognizerDelegate {
    weak var navigation: UINavigationController?
    weak var original: (any UIGestureRecognizerDelegate)?
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigation else { return false }
        return navigation.viewControllers.count > 1 && navigation.transitionCoordinator == nil
    }
    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (original?.responds(to: selector) ?? false)
    }
    override func forwardingTarget(for selector: Selector!) -> Any? {
        original?.responds(to: selector) == true ? original : super.forwardingTarget(for: selector)
    }
}
