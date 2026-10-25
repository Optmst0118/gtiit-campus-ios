import SwiftUI

/// 辅助功能字号使用完整选项列表，避免系统菜单选择器截短当前值。
struct SettingsChoicePicker<Selection: Hashable & Identifiable>: View {
    @Environment(\.locale) private var nativeLocale
    let name: String
    @Binding var selection: Selection
    let choices: [Selection]
    let title: (Selection) -> String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        _ name: String, selection: Binding<Selection>, choices: [Selection],
        title: @escaping (Selection) -> String
    ) {
        self.name = name
        _selection = selection
        self.choices = choices
        self.title = title
    }
    var body: some View {
        let _ = nativeLocale.identifier

        if dynamicTypeSize.isAccessibilitySize {
            NavigationLink {
                SettingsChoiceList(name: name, selection: $selection, choices: choices, title: title)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(name).foregroundStyle(.primary)
                    Text(title(selection)).font(.subheadline).foregroundStyle(.secondary)
                }.fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Picker(name, selection: $selection) {
                ForEach(choices) { choice in Text(title(choice)).tag(choice) }
            }
        }
    }
}
private struct SettingsChoiceList<Selection: Hashable & Identifiable>: View {
    @Environment(\.locale) private var nativeLocale
    let name: String
    @Binding var selection: Selection
    let choices: [Selection]
    let title: (Selection) -> String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let _ = nativeLocale.identifier

        List(choices) { choice in
            Button {
                selection = choice
                dismiss()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(title(choice)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if choice == selection {
                        Image(systemName: "checkmark").foregroundStyle(Theme.accent).accessibilityHidden(true)
                    }
                }.padding(.vertical, 6).frame(minHeight: 44)
            }.buttonStyle(.plain).accessibilityAddTraits(choice == selection ? .isSelected : [])
        }.navigationTitle(name).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
    }
}
