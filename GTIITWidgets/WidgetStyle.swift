import SwiftUI

/// Shared home-screen hierarchy; system container owns radius and outer margins.
enum WidgetStyle {
    static let gap: CGFloat = 12
    static let rowGap: CGFloat = 6
    static let tight: CGFloat = 1
    static let sectionGap: CGFloat = 8
    static let headerHeight: CGFloat = 16
    static let footerHeight: CGFloat = 14
    static let taskHeight: CGFloat = 42
    static let iconSize: CGFloat = 12
    static let title = Font.system(size: 12, weight: .semibold)
    static let body = Font.system(size: 13, weight: .semibold)
    static let course = Font.system(size: 10, weight: .medium)
    static let detail = Font.system(size: 10, weight: .medium)
    static let footer = Font.system(size: 11, weight: .medium)
    static let time = Font.system(size: 32, weight: .semibold, design: .rounded)
    static let countdown = Font.system(size: 14, weight: .medium, design: .rounded)
    static let primary = Color.primary
    static let secondary = adaptive(light: (0.36, 0.38, 0.41), dark: (0.70, 0.72, 0.75))
    static let background = Color(uiColor: CampusColors.surface)
    static let accent = Color(uiColor: CampusColors.accent)
    static let urgent = Color(uiColor: CampusColors.orange)
    static func routeColor(_ direction: ShuttleDirection) -> Color {
        direction == .southToNorth ? accent : urgent
    }
    private static func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
    static func text(_ key: String, english: Bool, _ arguments: CVarArg...) -> String {
        let language = english ? "en" : "zh-Hans"
        let bundle = Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        return String(format: bundle.localizedString(forKey: key, value: key, table: nil), locale: Locale(identifier: language), arguments: arguments)
    }
    static func deadline(_ date: Date, now: Date, english: Bool) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let formatter = DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: english ? "en_GB" : "zh_CN")
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: date)
        if calendar.isDate(date, inSameDayAs: now) { return text("今天 %@", english: english, time) }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return text("明天 %@", english: english, time)
        }
        formatter.dateFormat = english ? "MMM d HH:mm" : "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}

/// Identical title baseline and footer baseline for every size and content type.
struct WidgetFrame<Content: View, Footer: View>: View {
    let title: String
    let symbol: String
    var located = false
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer
    var body: some View {
        VStack(alignment: .leading, spacing: WidgetStyle.sectionGap) {
            HStack(spacing: WidgetStyle.rowGap) {
                Image(systemName: symbol).font(.system(size: WidgetStyle.iconSize, weight: .semibold))
                    .frame(width: WidgetStyle.headerHeight)
                Text(title).font(WidgetStyle.title).lineLimit(1)
                Spacer(minLength: 0)
                if located { Image(systemName: "location.fill").font(WidgetStyle.detail) }
            }.foregroundStyle(WidgetStyle.accent).frame(height: WidgetStyle.headerHeight, alignment: .leading)
            content().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer().font(WidgetStyle.footer).foregroundStyle(WidgetStyle.secondary)
                .frame(maxWidth: .infinity, minHeight: WidgetStyle.footerHeight, maxHeight: WidgetStyle.footerHeight, alignment: .leading)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(WidgetStyle.primary)
    }
}
