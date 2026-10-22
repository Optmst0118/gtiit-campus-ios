import SwiftUI

/// 顶部 2pt 加载进度条。
struct ProgressBarView: View {
    @Environment(\.locale) private var nativeLocale
    let progress: Double
    let isActive: Bool

    var body: some View {
        let _ = nativeLocale.identifier

        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color.clear
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: max(0, min(1, progress)) * geometry.size.width)
            }
        }
        .frame(height: 2)
        .opacity(isActive ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: isActive)
        .animation(.linear(duration: 0.15), value: progress)
    }
}

/// 首次加载时的占位。
struct LoadingPlaceholderView: View {
    @Environment(\.locale) private var nativeLocale
    let site: SiteID

    var body: some View {
        let _ = nativeLocale.identifier

        VStack(spacing: 14) {
            SiteBadge(site: site, size: 52)
            ProgressView()
            VStack(spacing: 3) {
                Text(L10n.format("正在打开%@", String(describing: site.displayName)))
                    .font(.footnote.weight(.medium))
                Text(L10n.tr("正在连接学校网站"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.pageBackground)
    }
}

/// 加载失败时的可操作错误页。
struct LoadErrorView: View {
    @Environment(\.locale) private var nativeLocale
    let site: SiteID
    let message: String
    let onRetry: () -> Void
    let onOpenSafari: () -> Void
    let onOpenHome: () -> Void
    @State private var canOpenATrust = CampusNetworkAccess.canOpenClient
    @State private var showATrustHelp = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        let _ = nativeLocale.identifier

        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)
                    .padding(.top, 40)

                Text(L10n.format("无法打开%@", String(describing: site.displayName)))
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    Button(action: onRetry) {
                        Text(L10n.tr("重试")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: onOpenHome) {
                        Text(L10n.tr("回到站点首页")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(action: onOpenSafari) {
                        Text(L10n.tr("在 Safari 中打开")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .font(.footnote)
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Label(L10n.tr("校园网络访问"), systemImage: "network").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(L10n.tr("请连接校内无线网络，或在 aTrust 中连接学校对应的校园 VPN，再返回此处重试。"))
                        .fixedSize(horizontal: false, vertical: true)
                    if canOpenATrust {
                        Button(L10n.tr("打开 aTrust"), systemImage: "arrow.up.forward.app") {
                            CampusNetworkAccess.openClient { success in if !success { showATrustHelp = true } }
                        }.buttonStyle(.bordered).padding(.top, 6)
                    } else {
                        Text(L10n.tr("请从主屏幕打开 aTrust 并连接校园 VPN。"))
                        Button(L10n.tr("在 App Store 查看 aTrust"), systemImage: "arrow.up.right") {
                            openURL(CampusNetworkAccess.storeURL)
                        }.buttonStyle(.borderless).padding(.top, 6)
                    }
                    Text(L10n.tr("若仍无法访问，可能是站点维护、登录失效或证书问题，请按上方错误信息处理。"))
                        .padding(.top, 4)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 8)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
        }
        .background(Theme.pageBackground)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            canOpenATrust = CampusNetworkAccess.canOpenClient
        }
        .alert(L10n.tr("请手动打开 aTrust"), isPresented: $showATrustHelp) {
            Button(L10n.tr("好"), role: .cancel) {}
        } message: { Text(L10n.tr("请从主屏幕打开 aTrust 并连接校园 VPN。")) }
    }
}

/// 底部轻提示。
struct ToastView: View {
    @Environment(\.locale) private var nativeLocale
    let text: String

    var body: some View {
        let _ = nativeLocale.identifier

        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .padding(.horizontal, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
