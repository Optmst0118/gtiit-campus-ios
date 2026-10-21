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

    @State private var showMenu = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                header
                ProgressBarView(progress: model.progress, isActive: model.isLoading)
                content
            }
            .background(Color(uiColor: .systemBackground))

            if showMenu {
                menuOverlay
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .task {
            #if DEBUG
                if ProcessInfo.processInfo.environment["GTIIT_OPEN_MENU"] == "1" { showMenu = true }
            #endif
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
            Button {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.9)) {
                    showMenu.toggle()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showMenu ? "关闭菜单" : "更多操作")
        }
        .padding(.horizontal, 4)
        .frame(minHeight: Theme.headerHeight)
        .padding(.vertical, 4)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - 二级菜单

    private var menuOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { closeMenu() }
                .accessibilityHidden(true)

            menuPanel
                .padding(.top, 58)
                .padding(.trailing, 8)
                .transition(.scale(scale: 0.94, anchor: .topTrailing).combined(with: .opacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var menuPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                navigationButton("chevron.backward", label: "后退", enabled: model.canGoBack) { model.goBack() }
                navigationButton("chevron.forward", label: "前进", enabled: model.canGoForward) { model.goForward() }
                navigationButton(
                    model.site == .moodle ? "book.closed" : "house",
                    label: "回到\(model.site.defaultLandingTitle)") { model.loadHome() }
                navigationButton("arrow.clockwise", label: "刷新") { model.reload() }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)

            Divider().padding(.horizontal, 10)

            appearanceRow

            Divider().padding(.leading, 44)
            menuRow("下载", systemImage: "arrow.down.circle") { app.showDownloads = true }
            Divider().padding(.leading, 44)
            menuRow("强制刷新（忽略缓存）", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                model.reloadFromOrigin()
            }
            Divider().padding(.leading, 44)
            menuRow("站点说明", systemImage: "info.circle") { app.siteInfo = model.site }
        }
        .frame(width: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }

    private func navigationButton(
        _ systemImage: String, label: String, enabled: Bool = true, action: @escaping () -> Void
    ) -> some View {
        Button {
            closeMenu()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }

    private var appearanceRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.fill")
                .frame(width: 24)
                .foregroundStyle(.primary)
            Text("暗色适配")
                .font(.body)
            Spacer(minLength: 0)
            Toggle("", isOn: appearanceBinding)
                .labelsHidden()
                .disabled(!settings.webDarkMode)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .opacity(settings.webDarkMode ? 1 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("暗色适配")
    }

    private var appearanceBinding: Binding<Bool> {
        Binding(
            get: { !settings.originalColorSites.contains(model.site) },
            set: { enabled in
                if enabled { settings.originalColorSites.remove(model.site) }
                else { settings.originalColorSites.insert(model.site) }
            })
    }

    private func menuRow(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            closeMenu()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.body)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func closeMenu() {
        withAnimation(.easeOut(duration: 0.16)) { showMenu = false }
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