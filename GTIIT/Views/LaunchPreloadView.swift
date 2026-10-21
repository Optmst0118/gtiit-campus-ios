import SwiftUI

struct LaunchPreloadView: View {
    @Environment(\.locale) private var nativeLocale
    @ObservedObject var preparation: LaunchPreparation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let _ = nativeLocale.identifier

        ZStack {
            // 让四个真实内核拥有布局与窗口，避免进入标签时重新初始化/首次绘制。
            ZStack {
                ForEach(preparation.models, id: \.site) { model in WebViewContainer(model: model) }
            }.opacity(0.01).allowsHitTesting(false).accessibilityHidden(true)
            Theme.pageBackground.ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer(minLength: 24)
                VStack(spacing: 18) {
                    Image("CampusMark").resizable().scaledToFit().frame(width: 88, height: 88)
                        .accessibilityHidden(true)
                    Text(L10n.tr("校园，即将就绪")).font(.title.weight(.semibold))
                    Text(L10n.tr("正在准备网站与登录会话"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                VStack(spacing: 18) {
                    ForEach(SiteID.allCases) { site in
                        HStack(spacing: 12) {
                            SiteBadge(site: site, size: 32)
                            Text(site.displayName).font(.subheadline)
                            Spacer()
                            status(preparation.states[site] ?? .preparing)
                        }
                    }
                    ProgressView(value: Double(preparation.settledCount), total: 4)
                        .tint(Theme.accent).accessibilityLabel(L10n.tr("网站准备进度"))
                }.padding(20).cardBackground(corner: 24)
                Spacer(minLength: 24)
                VStack(spacing: 12) {
                    Button(L10n.tr("直接进入")) { preparation.skip() }
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    Text(L10n.tr("会话有效时自动恢复；需要密码或验证时由你完成。"))
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            }
            .padding(24).frame(maxWidth: 480)
        }
        .background(Theme.pageBackground)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: preparation.settledCount)
    }
    @ViewBuilder private func status(_ state: SitePreparationState) -> some View {
        HStack(spacing: 6) {
            if !state.isSettled {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: state == .ready ? "checkmark.circle.fill" : state == .needsLogin ? "person.crop.circle.badge.exclamationmark" : "clock")
                    .foregroundStyle(state == .ready ? Theme.accent : Theme.orange)
            }
            Text(state.title).font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }
}
