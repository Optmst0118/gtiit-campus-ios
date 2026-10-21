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

    static let pageBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.08, blue: 0.11, alpha: 1)
            : UIColor(red: 0.95, green: 0.97, blue: 0.98, alpha: 1)
    })
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)

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
