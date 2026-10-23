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
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)

    /// Consistent navigation surfaces: white in light mode and the existing
    /// native canvas in dark mode, with matching system title/status contrast.
    @MainActor static func configureNavigationAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? pageUIColor.resolvedColor(with: traits) : .white
        }
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.compactScrollEdgeAppearance = appearance
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
