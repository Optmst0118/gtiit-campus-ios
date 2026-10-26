import SwiftUI

/// 单个站点的完整浏览界面：原生极简铬 + 官方网页。
struct SiteBrowserView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @Environment(\.scenePhase) private var phase
    @Environment(\.colorScheme) private var colorScheme
    let site: SiteID

    var body: some View {
        let _ = nativeLocale.identifier
        NavigationStack { BrowserChrome(model: app.browser(for: site)) }
            .id(site)
            .onAppear {
                app.browser(for: site).recoverReadOnlyDocumentIfNeeded()
                applyPortalBackground()
            }
            .onChange(of: colorScheme) { _, _ in applyPortalBackground() }
            .onChange(of: phase) { _, value in
                if value == .active && !app.lock.isLocked { app.browser(for: site).recoverReadOnlyDocumentIfNeeded() }
            }
    }

    private func applyPortalBackground() {
        guard site == .portal else { return }
        WebAppearance.setNativePageBackground(site: .portal, pageHex: Theme.pageHex(for: colorScheme), on: app.browser(for: .portal).webView)
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
            ProgressBarView(progress: model.progress, isActive: model.isLoading)
            content
        }
        .background(Theme.pageBackground)
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationTitle(model.site.nativeTitle)
        .navigationBarTitleDisplayMode(.large)
        .nativeNavigationSurface(large: true)
        .modifier(PortalLandscapeNavigation(site: model.site))
        .toolbar {
            if model.site == .rooms || model.site == .sports {
                ToolbarItem(placement: .topBarLeading) { bookingPicker }
            } else if model.site == .portal {
                ToolbarItem(placement: .topBarLeading) { portalMenu }
            }
            if model.site == .portal {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.reload() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel(L10n.tr("刷新"))
                }
            }
            ToolbarItem(placement: .topBarTrailing) { menu }
        }
    }

    private var bookingPicker: some View {
        Menu {
            Picker(L10n.tr("预约场所"), selection: $app.bookingSegment) {
                ForEach(BookingSegment.allCases) { segment in
                    Label(segment.title, systemImage: segment == .rooms ? "door.left.hand.open" : "sportscourt").tag(segment)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: app.bookingSegment == .rooms ? "door.left.hand.open" : "sportscourt").font(.system(size: 15, weight: .medium))
                Text(app.bookingSegment == .rooms ? L10n.tr("练习房") : L10n.tr("体育场馆")).font(.subheadline.weight(.medium)).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold))
            }.frame(minHeight: 44).contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.tr("切换预约场所"))
        .menuOrder(.fixed)
    }

    private var portalMenu: some View {
        Menu {
            Button { model.loadHome() } label: { Label(L10n.tr("首页"), systemImage: "house") }
            portalLink("成绩", "/grades")
            portalLink("选课与周课表", "/enrollments")
            portalLink("刷卡考勤", "/attendance")
            portalLink("申请与下载", "/apps")
            portalLink("教学评价", "/evaluations")
            portalLink("培养计划", "/checklist")
        } label: { Label(L10n.tr("Student"), systemImage: "person.text.rectangle.fill") }
            .menuOrder(.fixed)
    }

    private func portalLink(_ title: String, _ path: String) -> some View {
        Button { if let url = URL(string: "https://students.gtiit.edu.cn" + path) { model.load(url) } }
            label: { Label(L10n.tr(title), systemImage: "chevron.right") }
    }

    private var menu: some View {
        Menu {
            Button { model.loadHome() } label: { Label(L10n.tr("回到站点首页"), systemImage: "house") }
            Toggle(isOn: appearanceBinding) { Label(L10n.tr("暗色适配"), systemImage: "moon") }.disabled(!settings.webDarkMode)
            Button { app.showDownloads = true } label: { Label(L10n.tr("下载"), systemImage: "arrow.down.circle") }
            Button { model.reloadFromOrigin() } label: { Label(L10n.tr("强制刷新（忽略缓存）"), systemImage: "arrow.trianglehead.2.clockwise.rotate.90") }
            Button { app.siteInfo = model.site } label: { Label(L10n.tr("站点说明"), systemImage: "info.circle") }
        } label: {
            Image(systemName: "ellipsis.circle").font(.system(size: 17)).frame(width: 44, height: 44).contentShape(Rectangle())
        }.accessibilityLabel(L10n.tr("更多操作")).menuOrder(.fixed)
    }

    private var appearanceBinding: Binding<Bool> {
        Binding(get: { !settings.originalColorSites.contains(model.site) }, set: { enabled in
            if enabled { settings.originalColorSites.remove(model.site) } else { settings.originalColorSites.insert(model.site) }
        })
    }

    private var content: some View {
        ZStack {
            WebViewContainer(model: model).ignoresSafeArea(.container, edges: .bottom)
            if model.needsReloadAfterClear {
                ContentUnavailableView {
                    Label(L10n.tr("网页数据已清除"), systemImage: "checkmark.shield")
                } description: {
                    Text(L10n.tr("本站的登录与浏览历史已移除。重新打开网站后可登录。"))
                } actions: {
                    Button(L10n.tr("重新打开网站")) { model.loadHome() }.buttonStyle(.borderedProminent)
                }.background(Theme.pageBackground)
            } else if model.site != .portal, let error = model.errorText {
                LoadErrorView(site: model.site, message: error, onRetry: { model.reload() }, onOpenSafari: { model.openInSystemBrowser() }, onOpenHome: { model.loadHome() })
            } else if !model.hasLoadedOnce {
                LoadingPlaceholderView(site: model.site)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
