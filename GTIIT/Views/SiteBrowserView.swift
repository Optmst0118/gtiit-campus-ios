import SwiftUI

/// 单个站点的完整浏览界面：原生极简铬 + 官方网页。
struct SiteBrowserView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    let site: SiteID

    var body: some View {
        let _ = nativeLocale.identifier

        BrowserChrome(model: app.browser(for: site))
    }
}

private struct BrowserChrome: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var app: AppModel
    @ObservedObject var model: BrowserModel

    var body: some View {
        let _ = nativeLocale.identifier

        VStack(spacing: 0) {
            header
            ProgressBarView(progress: model.progress, isActive: model.isLoading)
            content
        }
        .background(Theme.pageBackground)
    }

    // MARK: - 顶部铬

    private var header: some View {
        HStack(spacing: 0) {
            // 与右侧菜单等宽，保持页面标题居中。
            Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
            Button { model.loadHome() } label: {
                Text(model.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.format("%@，回到%@", String(describing: model.displayTitle), String(describing: model.site.defaultLandingTitle)))
            .accessibilityHint(L10n.tr("轻点回到网站主页"))
            menu
        }
        .padding(.horizontal, 4)
        .frame(minHeight: Theme.headerHeight)
        .padding(.vertical, 4)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - 更多菜单（原生 Menu，iOS 26 使用系统 Liquid Glass）

    private var menu: some View {
        Menu {
            Toggle(isOn: appearanceBinding) {
                Label(L10n.tr("暗色适配"), systemImage: "moon")
            }
            .disabled(!settings.webDarkMode)

            Button { app.showDownloads = true } label: {
                Label(L10n.tr("下载"), systemImage: "arrow.down.circle")
            }

            Button { model.reloadFromOrigin() } label: {
                Label(L10n.tr("强制刷新（忽略缓存）"), systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
            }

            Button { app.siteInfo = model.site } label: {
                Label(L10n.tr("站点说明"), systemImage: "info.circle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 17))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.tr("更多操作"))
        .menuOrder(.fixed)
    }

    private var appearanceBinding: Binding<Bool> {
        Binding(
            get: { !settings.originalColorSites.contains(model.site) },
            set: { enabled in
                if enabled { settings.originalColorSites.remove(model.site) }
                else { settings.originalColorSites.insert(model.site) }
            })
    }

    // MARK: - 网页内容

    private var content: some View {
        ZStack {
            WebViewContainer(model: model)
                .ignoresSafeArea(.container, edges: .bottom)

            if model.needsReloadAfterClear {
                ContentUnavailableView {
                    Label(L10n.tr("网页数据已清除"), systemImage: "checkmark.shield")
                } description: {
                    Text(L10n.tr("本站的登录与浏览历史已移除。重新打开网站后可登录。"))
                } actions: {
                    Button(L10n.tr("重新打开网站")) { model.loadHome() }.buttonStyle(.borderedProminent)
                }.background(Theme.pageBackground)
            } else if let error = model.errorText {
                LoadErrorView(
                    site: model.site,
                    message: error,
                    onRetry: { model.reload() },
                    onOpenSafari: { model.openInSystemBrowser() },
                    onOpenHome: { model.loadHome() }
                )
            } else if !model.hasLoadedOnce {
                LoadingPlaceholderView(site: model.site)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}