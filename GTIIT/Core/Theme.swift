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
    static let sky = Color(red: 0.30, green: 0.73, blue: 0.96)

    static let corner: CGFloat = 18

    static let darkCanvasHex = "#0e141c"
    static let pageUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 14/255.0, green: 20/255.0, blue: 28/255.0, alpha: 1)
            : UIColor(red: 0.95, green: 0.97, blue: 0.98, alpha: 1)
    }
    static let pageBackground = Color(uiColor: pageUIColor)
    static func pageHex(for scheme: ColorScheme) -> String {
        scheme == .dark ? "#0e141c" : "#f2f7fa"
    }
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)

    /// Let the system own the navigation surface again: transparent at the top
    /// (the page background shows through) and the standard material once the
    /// content scrolls underneath. Forcing an opaque colour made the bar look
    /// like a coloured plate over the page in several screens.
    @MainActor static func configureNavigationAppearance() {
        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        scrollEdge.shadowColor = .clear
        scrollEdge.titleTextAttributes = [.foregroundColor: UIColor.label]
        scrollEdge.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        standard.shadowColor = .clear
        standard.titleTextAttributes = [.foregroundColor: UIColor.label]
        standard.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = standard
        bar.compactAppearance = standard
        // iOS 26 has a system bug where assigning a custom scroll-edge slot can
        // leave the large title permanently collapsed/blank after a transition.
        // The default scroll-edge appearance is already transparent, so leaving
        // the slot untouched is both safer and visually identical.
        if #unavailable(iOS 26.0) {
            bar.scrollEdgeAppearance = scrollEdge
            bar.compactScrollEdgeAppearance = scrollEdge
        }
        bar.isTranslucent = true
        bar.tintColor = UIColor(accent)
    }

    static let headerHeight: CGFloat = 46
}

extension View {
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