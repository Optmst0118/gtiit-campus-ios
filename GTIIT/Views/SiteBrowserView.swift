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
        HStack(spacing: 2) {
            navButton("chevron.backward", label: "后退", isEnabled: model.canGoBack) {
                model.goBack()
            }

            VStack(spacing: 1) {
                Text(model.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if model.isLoading {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(0.7)
                            .frame(width: 8, height: 8)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 7, weight: .bold))
                    }
                    Text(model.currentHost)
                        .font(.system(size: 10))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(model.displayTitle)，\(model.currentHost)")

            navButton("chevron.forward", label: "前进", isEnabled: model.canGoForward) {
                model.goForward()
            }

            navButton("arrow.clockwise", label: "刷新", isEnabled: true) {
                model.reload()
            }

            menu
        }
        .padding(.horizontal, 4)
        .frame(height: Theme.headerHeight)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func navButton(_ symbol: String, label: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    private var menu: some View {
        Menu {
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

            Button {
                model.reloadFromOrigin()
            } label: {
                Label("强制刷新（忽略缓存）", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
            }

            if let url = model.currentURL {
                ShareLink(item: url, subject: Text(model.displayTitle)) {
                    Label("分享当前页面", systemImage: "square.and.arrow.up")
                }
            }

            Button {
                model.openInSystemBrowser()
            } label: {
                Label("在 Safari 中打开", systemImage: "safari")
            }

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
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("更多操作")
    }

    // MARK: - 网页内容

    private var content: some View {
        ZStack {
            WebViewContainer(model: model)

            if let error = model.errorText {
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
