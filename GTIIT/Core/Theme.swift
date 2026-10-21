import SwiftUI

enum Theme {
    /// 与图标同源的校园蓝。
    static let accent = Color(red: 0.14, green: 0.38, blue: 0.86)

    static let corner: CGFloat = 18

    static let pageBackground = Color(uiColor: .systemGroupedBackground)
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
            .fill(
                LinearGradient(
                    colors: [site.tint.opacity(0.95), site.tint.opacity(0.65)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: site.symbol)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
