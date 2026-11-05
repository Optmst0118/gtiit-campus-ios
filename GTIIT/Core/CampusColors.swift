import UIKit

/// Product palette shared by the app and every WidgetKit home-screen size.
enum CampusColors {
    static let accent = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.35, green: 0.76, blue: 1, alpha: 1)
        : UIColor(red: 0.02, green: 0.42, blue: 0.67, alpha: 1) }
    static let orange = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 1, green: 0.66, blue: 0.36, alpha: 1)
        : UIColor(red: 0.71, green: 0.29, blue: 0.06, alpha: 1) }
    static let surface = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 27/255.0, green: 37/255.0, blue: 50/255.0, alpha: 1)
        : .secondarySystemGroupedBackground }
}
