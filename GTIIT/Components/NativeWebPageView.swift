import SwiftUI

/// Shared native wrapper for an in-app official website. The page participates
/// in the same NavigationStack push flow as native cards and keeps a native
/// inline title while the official site supplies the content.
struct NativeWebPageView: View {
    @EnvironmentObject private var app: AppModel
    let site: SiteID
    let title: String
    let url: URL

    var body: some View {
        NativeWebPageContent(model: app.browser(for: site), site: site, title: title, url: url)
    }
}

private struct NativeWebPageContent: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var model: BrowserModel
    let site: SiteID
    let title: String
    let url: URL

    var body: some View {
        VStack(spacing: 0) {
            ProgressBarView(progress: model.progress, isActive: model.isLoading)
            ZStack {
                WebViewContainer(model: model)
                if let error = model.errorText {
                    LoadErrorView(
                        site: site,
                        message: error,
                        onRetry: { model.reload() },
                        onOpenSafari: { model.openInSystemBrowser() },
                        onOpenHome: { model.loadHome() }
                    )
                } else if !model.hasLoadedOnce {
                    LoadingPlaceholderView(site: site)
                }
            }
        }
        .background(Theme.pageBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if site == .rooms || site == .sports {
                WebAppearance.setNativePageBackground(site: site, pageHex: Theme.pageHex(for: colorScheme), on: model.webView)
            } else {
                WebAppearance.clearNativePageBackground(on: model.webView)
            }
            if model.webView.url?.absoluteString != url.absoluteString {
                model.load(url)
            }
        }
        .onChange(of: colorScheme) { _, scheme in
            guard site == .rooms || site == .sports else { return }
            WebAppearance.setNativePageBackground(site: site, pageHex: Theme.pageHex(for: scheme), on: model.webView)
        }
    }
}
