import SwiftUI

/// 顶部 2pt 加载进度条。
struct ProgressBarView: View {
    let progress: Double
    let isActive: Bool

    var body: some View {
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
    let site: SiteID

    var body: some View {
        VStack(spacing: 14) {
            SiteBadge(site: site, size: 52)
            ProgressView()
            VStack(spacing: 3) {
                Text("正在打开\(site.displayName)")
                    .font(.footnote.weight(.medium))
                Text(site.host)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}

/// 加载失败时的可操作错误页。
struct LoadErrorView: View {
    let site: SiteID
    let message: String
    let onRetry: () -> Void
    let onOpenSafari: () -> Void
    let onOpenHome: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)
                    .padding(.top, 40)

                Text("无法打开\(site.displayName)")
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    Button(action: onRetry) {
                        Text("重试").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: onOpenHome) {
                        Text("回到站点首页").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(action: onOpenSafari) {
                        Text("在 Safari 中打开").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .font(.footnote)
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Label("校园站点通常需要校内网络；校外访问可能需要学校认可的接入方式。", systemImage: "info.circle")
                    Label("App 不会绕过证书校验，也不会替你输入账号。", systemImage: "lock.shield")
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
        .background(Color(uiColor: .systemBackground))
    }
}

/// 底部轻提示。
struct ToastView: View {
    let text: String

    var body: some View {
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
