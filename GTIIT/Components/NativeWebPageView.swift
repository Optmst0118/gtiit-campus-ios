import SwiftUI
import WebKit

/// A route owns a single entry point; internal web history stays inside it.
struct NativeWebPageView: View {
    @EnvironmentObject private var app: AppModel
    let site: SiteID
    let title: String
    let url: URL
    var courseChrome = false
    var body: some View {
        NativeWebPageContent(model: app.browser(for: site), site: site, title: title, url: url, courseChrome: courseChrome)
    }
}

private struct NativeWebPageContent: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: BrowserModel
    let site: SiteID
    let title: String
    let url: URL
    let courseChrome: Bool
    @State private var showSiteInfo = false
    @State private var started = false
    @State private var entry: WKBackForwardListItem?
    @State private var confirmLeave = false

    private var handlesBack: Bool {
        if model.hasUnsavedChanges { return true }
        guard let entry else { return false }
        return model.canGoBack && model.webView.backForwardList.backList.contains { $0 === entry }
    }
    var body: some View {
        VStack(spacing: 0) {
            ProgressBarView(progress: model.progress, isActive: model.isLoading)
            ZStack {
                WebViewContainer(model: model, inlineTitle: true)
                if let error = model.errorText {
                    LoadErrorView(site: site, message: error, onRetry: { model.reload() },
                        onOpenSafari: { model.openInSystemBrowser() }, onOpenHome: { model.loadHome() })
                } else if !model.hasLoadedOnce { LoadingPlaceholderView(site: site) }
            }
        }
        .background(Theme.pageBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
        .modifier(PortalLandscapeNavigation(site: site))
        .navigationBarBackButtonHidden(handlesBack)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.reload() } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel(L10n.tr("刷新"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(L10n.tr("在 Safari 中打开"), systemImage: "safari") { model.openInSystemBrowser() }
                    ShareLink(item: model.webView.url ?? url) { Label(L10n.tr("分享"), systemImage: "square.and.arrow.up") }
                    Button(L10n.tr("站点与登录"), systemImage: "info.circle") { showSiteInfo = true }
                } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel(L10n.tr("更多"))
            }
            if handlesBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if model.hasUnsavedChanges { confirmLeave = true } else { goBack() }
                    } label: { Label(L10n.tr("返回"), systemImage: "chevron.left") }
                }
            }
        }
        .sheet(isPresented: $showSiteInfo) { SiteInfoView(site: site) }
        .confirmationDialog(L10n.tr("离开此页面？"), isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(L10n.tr("离开"), role: .destructive) { goBack() }
            Button(L10n.tr("继续编辑"), role: .cancel) { }
        } message: { Text(L10n.tr("未提交的修改将丢失。")) }
        .onAppear {
            model.webView.allowsBackForwardNavigationGestures = false
            applyAppearance()
            guard !started else { return }
            started = true
            if model.webView.url?.absoluteString != url.absoluteString { model.load(url) }
            else if !model.isLoading { entry = model.webView.backForwardList.currentItem }
        }
        .onChange(of: model.isLoading) { _, loading in
            if !loading, entry == nil, model.errorText == nil { entry = model.webView.backForwardList.currentItem }
        }
        .onChange(of: colorScheme) { _, _ in applyAppearance() }
        .onDisappear {
            model.webView.allowsBackForwardNavigationGestures = true
            if site == .moodle { WebAppearance.setMoodleCourseChrome(hidden: false, on: model.webView) }
        }
    }
    private func goBack() {
        Haptics.light()
        if let entry, model.webView.backForwardList.backList.contains(where: { $0 === entry }), model.canGoBack {
            model.goBack()
        } else { dismiss() }
    }
    private func applyAppearance() {
        if site == .moodle {
            WebAppearance.setMoodleCourseChrome(hidden: true, on: model.webView, pageHex: Theme.pageHex(for: colorScheme))
        } else if site == .rooms || site == .sports || site == .portal {
            WebAppearance.setNativePageBackground(site: site, pageHex: Theme.pageHex(for: colorScheme), on: model.webView)
        } else { WebAppearance.clearNativePageBackground(on: model.webView) }
    }
}
