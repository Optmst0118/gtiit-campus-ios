import SwiftUI

/// 单个站点的完整浏览界面：原生极简铬 + 官方网页。
struct SiteBrowserView: View {
    @EnvironmentObject private var app: AppModel
    let site: SiteID

    var body: some View {
        BrowserChrome(model: app.browser(for: site))
    }
}

private struct BrowserChrome: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var app: AppModel
    @ObservedObject var model: BrowserModel

    @State private var showClearDataDialog = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ProgressBarView(progress: model.progress, isActive: model.isLoading)
            content
        }
        .background(Color(uiColor: .systemBackground))
        .confirmationDialog(
            "清除「\(model.site.displayName)」的网页数据？",
            isPresented: $showClearDataDialog,
            titleVisibility: .visible
        ) {
            Button("清除并重新登录", role: .destructive) {
                Task { await model.clearSiteData() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("会删除该站点的 Cookie、缓存与本地存储，其他站点不受影响。")
        }
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
            .accessibilityLabel("\(model.displayTitle)，回到\(model.site.defaultLandingTitle)")
            .accessibilityHint("轻点回到网站主页")
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

    private var menu: some View {
        Menu {
            Button {
                model.goBack()
            } label: {
                Label("后退", systemImage: "chevron.backward")
            }.disabled(!model.canGoBack)
            Button {
                model.goForward()
            } label: {
                Label("前进", systemImage: "chevron.forward")
            }.disabled(!model.canGoForward)

            Button {
                model.loadHome()
            } label: {
                Label("回到\(model.site.defaultLandingTitle)", systemImage: "house")
            }

            Button {
                model.reload()
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }

            Toggle("本站网页暗色适配", isOn: Binding(
                get: { !settings.originalColorSites.contains(model.site) },
                set: { enabled in
                    if enabled { settings.originalColorSites.remove(model.site) }
                    else { settings.originalColorSites.insert(model.site) }
                }))
                .disabled(!settings.webDarkMode)

            Button { app.showDownloads = true } label: {
                Label("下载", systemImage: "arrow.down.circle")
            }

            Button {
                model.reloadFromOrigin()
            } label: {
                Label("强制刷新（忽略缓存）", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
            }

            if model.canOpenInExternalBrowser, let url = model.currentURL {
                ShareLink(item: url, subject: Text(model.displayTitle)) {
                    Label("分享当前页面", systemImage: "square.and.arrow.up")
                }
            }

            Button {
                model.openInSystemBrowser()
            } label: {
                Label("在默认浏览器中打开", systemImage: "arrow.up.forward.app")
            }.disabled(!model.canOpenInExternalBrowser)

            Button {
                model.openInAppSafari()
            } label: {
                Label("在 App 内 Safari 打开", systemImage: "safari")
            }.disabled(!model.canOpenInExternalBrowser)

            Button {
                app.siteInfo = model.site
            } label: {
                Label("站点说明", systemImage: "info.circle")
            }

            Divider()

            Button(role: .destructive) {
                showClearDataDialog = true
            } label: {
                Label("清除本站网页数据", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 17))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("更多操作")
    }

    // MARK: - 网页内容

    private var content: some View {
        ZStack {
            WebViewContainer(model: model)

            if model.needsReloadAfterClear {
                ContentUnavailableView {
                    Label("网页数据已清除", systemImage: "checkmark.shield")
                } description: {
                    Text("本站的登录与浏览历史已移除。重新打开网站后可登录。")
                } actions: {
                    Button("重新打开网站") { model.loadHome() }.buttonStyle(.borderedProminent)
                }.background(Color(uiColor: .systemBackground))
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
