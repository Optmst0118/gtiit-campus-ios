import Foundation

/// Native UI only. Never changes WebKit's preferred languages or website content.
enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans", english = "en"
    var id: String { rawValue }
    var title: String { self == .english ? "English" : "中文" }
}
enum L10n {
    static var language: AppLanguage = .chinese
    static var isEnglish: Bool { language == .english }
    static var locale: Locale { Locale(identifier: language.rawValue) }
    static var translations: [String: String] = {
        guard let url = Bundle.main.url(forResource: "native-en", withExtension: "json", subdirectory: "CampusData"),
              let data = try? Data(contentsOf: url), let result = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return result
    }()
    static func tr(_ key: String) -> String { isEnglish ? translations[key] ?? key : key }
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        // Placeholders are %@; literal percent signs must never become format directives.
        let template = tr(key).replacingOccurrences(of: "%", with: "%%").replacingOccurrences(of: "%%@", with: "%@")
        return String(format: template, locale: locale, arguments: arguments)
    }
}


extension Date {
    /// Native UI dates must follow the in-app language, not the system locale.
    func gtiitFormatted(
        date: Date.FormatStyle.DateStyle = .abbreviated,
        time: Date.FormatStyle.TimeStyle = .shortened
    ) -> String {
        formatted(Date.FormatStyle(date: date, time: time).locale(L10n.locale))
    }
}
