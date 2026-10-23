import SwiftUI

/// Non-blocking WebKit prewarm host. The views are laid out in the real window
/// (behind the tabs) so WKWebView can render and restore sessions before the
/// user opens each tab. It never intercepts touches and is visually hidden.
struct WebPrewarmHost: View {
    let models: [BrowserModel]

    var body: some View {
        ZStack {
            ForEach(models, id: \.site) { model in
                WebViewContainer(model: model)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
