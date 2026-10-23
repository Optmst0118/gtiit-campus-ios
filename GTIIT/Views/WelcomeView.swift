import SwiftUI

struct WelcomeView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0
    @State private var hasConfirmed = false
    @State private var showAbout = false
    private let pageCount = 4

    var body: some View {
        let _ = nativeLocale.identifier
        VStack(spacing: 0) {
            TabView(selection: $page) {
                hero.tag(0)
                sites.tag(1)
                tools.tag(2)
                privacy.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer
        }
        .background(Theme.pageBackground)
        .onChange(of: page) { _, _ in Haptics.selection() }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showAbout) {
            NavigationStack {
                AboutView().toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.tr("完成")) { showAbout = false }
                    }
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 32)
            ZStack {
                Circle().fill(Theme.accent.opacity(0.08)).frame(width: 190, height: 190)
                Circle().fill(Theme.accent.opacity(0.13)).frame(width: 148, height: 148)
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.sky, Theme.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 104, height: 104)
                    .shadow(color: Theme.accent.opacity(0.28), radius: 20, y: 10)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 45, weight: .semibold)).foregroundStyle(.white)
                    .symbolEffect(.bounce, value: page)
            }
            VStack(spacing: 10) {
                Text(AppInfo.displayName).font(.largeTitle.weight(.bold))
                Text(AppInfo.tagline).font(.title3).foregroundStyle(.secondary)
                Text(L10n.tr("轻扫查看功能与隐私说明，再开始使用。"))
                    .font(.subheadline).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 18) {
                ForEach(SiteID.allCases) { site in
                    Image(systemName: site.symbol)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(site.tint, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
            }
            Spacer(minLength: 32)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            if !settings.hasSeenWelcome && page < pageCount - 1 {
                Button(L10n.tr("跳过")) { withAnimation { page = pageCount - 1 } }
                    .font(.subheadline.weight(.medium)).padding(12)
            }
        }
    }

    private var sites: some View {
        pageLayout(symbol: "square.grid.2x2.fill", title: L10n.tr("四个校园入口"),
                   subtitle: L10n.tr("门户、Moodle、预约与体育中心，各自独立登录、独立清除。")) {
            VStack(spacing: 14) {
                ForEach(SiteID.allCases) { site in
                    HStack(spacing: 16) {
                        Image(systemName: site.symbol)
                            .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(site.tint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.displayName).font(.headline)
                            Text(site.purpose).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private var tools: some View {
        pageLayout(symbol: "sparkles", title: L10n.tr("更顺手的校园工具"),
                   subtitle: L10n.tr("原生入口、班车倒计时与本地文件，都围绕同一个校园。")) {
            VStack(spacing: 14) {
                featureRow("door.left.hand.open", Theme.accent, L10n.tr("原生预约目录"),
                           L10n.tr("练习房、学生中心和活动室按用途整理，直接进入官方预约表单。"))
                featureRow("bus.fill", Theme.orange, L10n.tr("班车倒计时"),
                           L10n.tr("锁屏实时活动、发车提醒与按校区推荐方向。"))
                featureRow("arrow.down.circle.fill", Theme.sky, L10n.tr("文件与课表"),
                           L10n.tr("下载管理、本地课表和校园日历集中在一个 App。"))
            }
        }
    }

    private var privacy: some View {
        pageLayout(symbol: "lock.shield.fill", title: L10n.tr("边界与隐私"),
                   subtitle: L10n.tr("非官方客户端；只做入口，不代填、不代提交。")) {
            VStack(alignment: .leading, spacing: 16) {
                Label(L10n.tr("这是非官方客户端"), systemImage: "exclamationmark.shield.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
                Text(L10n.tr("本应用由学生个人开发，非广东以色列理工学院官方应用。登录与网页数据仅保存在本机，开发者不采集、不上传；选课、申请、预约等业务请在官方网页内确认并提交。"))
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(L10n.tr("账号邮箱只用于登录页自动填入，密码不会保存在 App 中。"))
                    .font(.footnote).foregroundStyle(.secondary)
                if !settings.hasSeenWelcome {
                    Button { hasConfirmed.toggle() } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: hasConfirmed ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18)).foregroundStyle(hasConfirmed ? Theme.accent : Color.secondary)
                            Text(L10n.tr("我已阅读并了解：本应用不是学校官方应用，仅作为官方网页入口，不采集数据、不代填、不代提交。"))
                                .font(.caption).foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                Button(L10n.tr("查看完整说明与隐私")) { showAbout = true }.font(.footnote)
            }
        }
    }

    private func pageLayout<Content: View>(symbol: String, title: String, subtitle: String,
                                           @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 28) {
            Spacer(minLength: 16)
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 31, weight: .semibold)).foregroundStyle(Theme.accent)
                    .frame(width: 72, height: 72)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
                    .symbolEffect(.bounce, value: page)
                VStack(spacing: 8) {
                    Text(title).font(.title2.weight(.bold)).multilineTextAlignment(.center)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
            Spacer(minLength: 16)
        }
        .padding(.horizontal, 32).padding(.vertical, 28)
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureRow(_ symbol: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18).background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Theme.accent : Color.secondary.opacity(0.25))
                        .frame(width: index == page ? 20 : 6, height: 6)
                        .animation(.spring(duration: 0.25), value: page)
                }
            }
            HStack(spacing: 12) {
                if page > 0 {
                    Button { withAnimation { page -= 1 } } label: {
                        Image(systemName: "chevron.left").font(.headline).frame(width: 46, height: 46)
                    }.buttonStyle(.bordered).clipShape(Circle())
                        .accessibilityLabel(L10n.tr("上一页"))
                }
                Button {
                    if page < pageCount - 1 { withAnimation { page += 1 } } else { finish() }
                } label: {
                    Text(page < pageCount - 1 ? L10n.tr("下一步") : settings.hasSeenWelcome ? L10n.tr("完成") : L10n.tr("我已了解，开始使用"))
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(page == pageCount - 1 && !hasConfirmed && !settings.hasSeenWelcome)
            }
        }
        .padding(.horizontal, 32).padding(.top, 18).padding(.bottom, 20)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Theme.pageBackground.overlay(alignment: .top) { Divider() })
    }

    private func finish() {
        guard hasConfirmed || settings.hasSeenWelcome else { return }
        Haptics.success()
        settings.markWelcomeSeen()
        app.showWelcome = false
        dismiss()
    }
}
