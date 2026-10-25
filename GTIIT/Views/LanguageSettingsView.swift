import SwiftUI

struct LanguageSettingsView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        let _ = nativeLocale.identifier

        List {
            Section {
                ForEach(AppLanguage.allCases) { language in
                    Button { settings.language = language } label: {
                        HStack {
                            Text(language.title).foregroundStyle(.primary)
                            Spacer()
                            if settings.language == language { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                        }.frame(minHeight: 32)
                    }.accessibilityAddTraits(settings.language == language ? .isSelected : [])
                }
            } footer: { Text(L10n.tr("只切换 App 界面语言，学校网页保持原语言。")) }
        }.navigationTitle(L10n.tr("语言")).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
    }
}
