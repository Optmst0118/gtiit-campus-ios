import SwiftUI

enum Theme {
    /// 天蓝用于操作，橙色用于方向和信息高亮；深色模式提高亮度。
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.35, green: 0.76, blue: 1, alpha: 1)
            : UIColor(red: 0.02, green: 0.42, blue: 0.67, alpha: 1)
    })
    static let orange = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1, green: 0.66, blue: 0.36, alpha: 1)
            : UIColor(red: 0.71, green: 0.29, blue: 0.06, alpha: 1)
    })
    static let iconBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.028, green: 0.118, blue: 0.275, alpha: 1) : UIColor(red: 0.71, green: 0.89, blue: 0.98, alpha: 1)
    })
    static let sky = Color(red: 0.30, green: 0.73, blue: 0.96)

    static let corner: CGFloat = 24
    static let shortcutCorner: CGFloat = 24
    static let pageInset: CGFloat = 20
    static let cardInset: CGFloat = 18
    static let destructive = Color(uiColor: .systemRed)
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary

    static let darkCanvasHex = "#0e141c"
    static let pageUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 14/255.0, green: 20/255.0, blue: 28/255.0, alpha: 1)
            : UIColor(red: 0.95, green: 0.97, blue: 0.98, alpha: 1)
    }
    static let pageBackground = Color(uiColor: pageUIColor)
    static let sidebarSurroundUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 19/255, green: 24/255, blue: 30/255, alpha: 1)
            : UIColor(red: 244/255, green: 249/255, blue: 251/255, alpha: 1)
    }
    static let navigationUIColor = pageUIColor
    static let navigationBackground = Color(uiColor: navigationUIColor)
    static func pageHex(for scheme: ColorScheme) -> String {
        scheme == .dark ? "#0e141c" : "#f2f7fa"
    }
    static let cardBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 27/255.0, green: 37/255.0, blue: 50/255.0, alpha: 1)
            : .white
    })

    /// iOS 26 owns the Liquid Glass/scroll-edge transition. Older systems use
    /// UIKit's transparent edge and default material rather than an opaque plate.
    @MainActor static func configureNavigationAppearance() {
        let bar = UINavigationBar.appearance()
        if #unavailable(iOS 26.0) {
            let standard = UINavigationBarAppearance()
            standard.configureWithDefaultBackground()
            standard.backgroundColor = pageUIColor.withAlphaComponent(0.16)
            standard.shadowColor = .clear
            let edge = UINavigationBarAppearance()
            edge.configureWithTransparentBackground()
            edge.shadowColor = .clear
            bar.standardAppearance = standard
            bar.compactAppearance = standard
            bar.scrollEdgeAppearance = edge
            bar.compactScrollEdgeAppearance = edge
        }
        bar.isTranslucent = true
        bar.tintColor = UIColor(accent)
    }

    static let headerHeight: CGFloat = 46
}

extension View {
    func nativeNavigationSurface(large: Bool = false, sidebarBack: (() -> Void)? = nil) -> some View {
        // Automatic visibility lets native scroll tracking progressively reveal
        // the system material. The same canvas also covers the status-bar area.
        self.scrollContentBackground(.hidden)
            .background(Theme.pageBackground.ignoresSafeArea())
            .toolbarBackground(.automatic, for: .navigationBar)
            .modifier(SidebarNavigationSurface(customBack: sidebarBack))
    }

    /// 统一的卡片外观，供「我的」等原生页面使用。
    func cardBackground(corner: CGFloat = Theme.corner) -> some View {
        self
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

/// 站点配色胶囊（用于「我的」页和 toast）。
struct SiteBadge: View {
    let site: SiteID
    var size: CGFloat = 38

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(site.tint.opacity(0.12))
            .overlay(
                Image(systemName: site.symbol)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(site.tint)
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Press feedback for tappable cards; a ButtonStyle preserves tap cancellation,
/// scrolling, context menus and accessibility without adding a competing gesture.
struct CardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: configuration.isPressed)
    }
}

/// The system still owns menu placement, material, accessibility and dismissal.
/// This adds only the requested subtle defocus/dim to the underlying page.
struct ContextMenuBackdrop: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .blur(radius: active ? 1.6 : 0)
            .overlay { Color.black.opacity(active ? 0.04 : 0).allowsHitTesting(false).accessibilityHidden(true) }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: active)
    }
}

/// Observe the actual viewport so rotation, iPad and split-window layouts share
/// one rule. Keep the existing browser/WebKit instance alive across rotations.
enum PortalNavigationPolicy {
    static func hidesBar(site: SiteID, viewport: CGSize) -> Bool {
        site == .portal && viewport.width > viewport.height && viewport.height > 0
    }
}
struct PortalLandscapeNavigation: ViewModifier {
    let site: SiteID
    @State private var hideBar = false
    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geometry in
                    Color.clear.onChange(of: geometry.size, initial: true) { _, size in
                        hideBar = PortalNavigationPolicy.hidesBar(site: site, viewport: size)
                    }
                }.allowsHitTesting(false)
            }
            .toolbar(hideBar ? .hidden : .automatic, for: .navigationBar)
    }
}

enum PrimaryNavigationLayout {
    static func usesSidebar(_ size: CGSize) -> Bool {
        size.width >= 700 || (size.width >= 600 && size.width > size.height)
    }
}
enum PrimaryNavigationMotion {
    static let duration = 0.3
    static func animation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: duration)
    }
}
struct PrimaryPageScrollToTop: ViewModifier {
    @EnvironmentObject private var app: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tab: AppTab
    let anchor: String
    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content.onChange(of: app.tabReselectToken) { _, _ in
                guard app.tabReselectTarget == tab else { return }
                withAnimation(PrimaryNavigationMotion.animation(reduceMotion: reduceMotion)) {
                    proxy.scrollTo(anchor, anchor: .top)
                }
            }
        }
    }
}
private struct CampusSidebarKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var campusSidebarNavigation: Bool {
        get { self[CampusSidebarKey.self] }
        set { self[CampusSidebarKey.self] = newValue }
    }
}

private struct CampusSidebarRevealKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var campusSidebarRevealVisible: Bool {
        get { self[CampusSidebarRevealKey.self] }
        set { self[CampusSidebarRevealKey.self] = newValue }
    }
}

/// Reserve room only for the collapsed floating reveal button. An empty native
/// toolbar item must not join the booking selector's shared glass background.
struct SidebarRevealToolbarSpace: ToolbarContent {
    @Environment(\.campusSidebarRevealVisible) private var visible
    var body: some ToolbarContent {
        if visible {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarLeading) {
                    Color.clear.frame(width: 24).accessibilityHidden(true)
                }.sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarLeading) {
                    Color.clear.frame(width: 64).accessibilityHidden(true)
                }
            }
        }
    }
}
