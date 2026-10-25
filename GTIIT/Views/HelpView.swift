import SwiftUI

struct HelpView: View {
    @Environment(\.locale) private var nativeLocale
    @StateObject private var diagnostics = NetworkDiagnostics()
    var body: some View {
        let _ = nativeLocale.identifier

        List {
            Section {
                Text(L10n.tr("连接校园 Wi-Fi 或在 A Trust 中连接校园 VPN。"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(L10n.tr("Safari、App 内网页和 App 内 Safari 分别管理会话，可能需要分别登录。清理缓存不会主动退出登录；清除登录数据会移除本站会话。"))
                    .font(.subheadline).foregroundStyle(.secondary)
            } header: {
                Text(L10n.tr("访问与登录"))
            }
            Section {
                Button(diagnostics.isRunning ? L10n.tr("正在检查…") : L10n.tr("检查四个站点")) { diagnostics.run() }.disabled(
                    diagnostics.isRunning)
                if diagnostics.isRunning { Button(L10n.tr("停止检查")) { diagnostics.cancel() } }
                ForEach(diagnostics.results) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(
                            result.site.displayName,
                            systemImage: result.reachable ? "checkmark.circle" : "exclamationmark.circle")
                        Text(result.message).font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 3)
                }
                if !diagnostics.results.isEmpty {
                    ShareLink(item: diagnostics.report) {
                        Label(L10n.tr("分享诊断摘要"), systemImage: "square.and.arrow.up")
                    }
                }
            } header: {
                Text(L10n.tr("网络诊断"))
            }
            Section(L10n.tr("常见问题")) {
                DisclosureGroup(L10n.tr("找不到下载的资料")) {
                    Text(L10n.tr("打开“我的 → 下载管理”查看文件。点击下载位置可更改之后新文件的保存文件夹。"))
                }
                DisclosureGroup(L10n.tr("页面打不开或需要重新登录")) {
                    Text(L10n.tr("连接校园网络后重试，或从网页菜单选择“在默认浏览器中打开”。"))
                }
                DisclosureGroup(L10n.tr("如何反馈问题")) {
                    Text(L10n.tr("记录站点名称、发生时间、操作步骤和脱敏错误码，可用上方诊断摘要辅助说明。向开发者或学校支持提供这些信息前，请确认不含个人页面内容。"))
                }
            }.font(.subheadline)
            Section { NavigationLink(L10n.tr("技术日志")) { TechnicalDiagnosticsView() } }
            Section { NavigationLink(L10n.tr("版本与隐私说明")) { AboutView() } }
        }.navigationTitle(L10n.tr("帮助与诊断")).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
            .onDisappear { diagnostics.cancel() }
    }
}


struct TechnicalDiagnosticsView: View {
    @ObservedObject private var diagnostics = LocalDiagnostics.shared
    var body: some View {
        List {
            Text(diagnostics.report).font(.caption.monospaced()).textSelection(.enabled)
            ShareLink(item: diagnostics.report) { Label(L10n.tr("分享诊断摘要"), systemImage: "square.and.arrow.up") }
        }.navigationTitle(L10n.tr("技术日志")).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
            .scrollContentBackground(.hidden).background(Theme.pageBackground)
    }
}
