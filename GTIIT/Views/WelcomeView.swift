import SwiftUI

struct WelcomeView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page = 0
    @State private var hasConfirmed = false
    @State private var showAbout = false
    @State private var showLogin = false
    @State private var confirmedSites: Set<SiteID> = []
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
        .onChange(of: page) { previous, next in
            if previous <= 1 && next > 1 && confirmedSites.count < SiteID.allCases.count { page = 1 }
            Haptics.selection()
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showLogin) {
            WelcomeLoginFlow(confirmed: $confirmedSites)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
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
                    .symbolEffectsRemoved(reduceMotion)
            }
            VStack(spacing: 10) {
                Text(AppInfo.displayName).font(.largeTitle.weight(.bold))
                Text(AppInfo.tagline).font(.title3).foregroundStyle(.secondary)
                Text(L10n.tr("轻扫查看功能与隐私说明，再开始使用。"))
                    .font(.subheadline).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .modifier(WelcomeReveal(active: page == 0, index: 0))
            HStack(spacing: 18) {
                ForEach(Array(SiteID.allCases.enumerated()), id: \.element.id) { index, site in
                    Image(systemName: site.symbol)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(site.tint, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .modifier(WelcomeReveal(active: page == 0, index: index))
                }
            }
            Spacer(minLength: 32)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity, maxHeight: .infinity)

    }

    private var sites: some View {
        pageLayout(index: 1, symbol: "person.crop.circle.badge.checkmark", title: L10n.tr("登录校园网站"),
                   subtitle: L10n.tr("依次登录四个校园入口，完成后逐个确认。")) {
            VStack(spacing: 10) {
                ForEach(Array(SiteID.allCases.enumerated()), id: \.element.id) { index, site in
                    HStack(spacing: 14) {
                        Image(systemName: site.symbol)
                            .font(.system(size: 18, weight: .semibold)).foregroundStyle(site.tint)
                            .frame(width: 42, height: 42)
                            .background(site.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                        Text(site.displayName).font(.headline)
                        Spacer(minLength: 0)
                        Image(systemName: confirmedSites.contains(site) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(confirmedSites.contains(site) ? Theme.accent : Color.secondary.opacity(0.35))
                            .font(.title3)
                            .accessibilityLabel(confirmedSites.contains(site) ? L10n.tr("已确认登录") : L10n.tr("待登录"))
                    }
                    .padding(14)
                    .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .modifier(WelcomeReveal(active: page == 1, index: index))
                }
                Button { showLogin = true } label: {
                    Label(confirmedSites.isEmpty ? L10n.tr("登录") : L10n.tr("继续登录"), systemImage: "person.crop.circle")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(confirmedSites.count == SiteID.allCases.count)
                .padding(.top, 6)
                .modifier(WelcomeReveal(active: page == 1, index: 4))
            }
        }
    }

    private var tools: some View {
        pageLayout(index: 2, symbol: "sparkles", title: L10n.tr("更顺手的校园工具"),
                   subtitle: L10n.tr("原生入口、班车倒计时与本地文件，都围绕同一个校园。")) {
            VStack(spacing: 14) {
                featureRow("door.left.hand.open", Theme.accent, L10n.tr("原生预约目录"),
                           L10n.tr("练习房、学生中心和活动室按用途整理，直接进入官方预约表单。"))
                    .modifier(WelcomeReveal(active: page == 2, index: 0))
                featureRow("bus.fill", Theme.orange, L10n.tr("班车倒计时"),
                           L10n.tr("锁屏实时活动、发车提醒与按校区推荐方向。"))
                    .modifier(WelcomeReveal(active: page == 2, index: 1))
                featureRow("arrow.down.circle.fill", Theme.sky, L10n.tr("文件与课表"),
                           L10n.tr("下载管理、本地课表和校园日历集中在一个 App。"))
                    .modifier(WelcomeReveal(active: page == 2, index: 2))
            }
        }
    }

    private var privacy: some View {
        pageLayout(index: 3, symbol: "lock.shield.fill", title: L10n.tr("隐私与数据"),
                   subtitle: L10n.tr("管理你的本地数据与登录设置。")) {
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
                            Text(L10n.tr("我已了解应用与隐私说明。"))
                                .font(.caption).foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                Button(L10n.tr("查看完整说明与隐私")) { showAbout = true }.font(.footnote)
            }
        }
    }

    private func pageLayout<Content: View>(index: Int, symbol: String, title: String, subtitle: String,
                                           @ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { geometry in
        ScrollView {
        VStack(spacing: 28) {
            Spacer(minLength: 16)
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 31, weight: .semibold)).foregroundStyle(Theme.accent)
                    .frame(width: 72, height: 72)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
                    .symbolEffect(.bounce, value: page)
                    .symbolEffectsRemoved(reduceMotion)
                VStack(spacing: 8) {
                    Text(title).font(.title2.weight(.bold)).multilineTextAlignment(.center)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .modifier(WelcomeReveal(active: page == index, index: 0))
            content()
            Spacer(minLength: 16)
        }
        .padding(.horizontal, 32).padding(.vertical, 28)
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
        }
        }
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
                        .animation(reduceMotion ? nil : .spring(duration: 0.25), value: page)
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
                .disabled((page == 1 && confirmedSites.count != SiteID.allCases.count) || (page == pageCount - 1 && !hasConfirmed && !settings.hasSeenWelcome))
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

/// Completion is an explicit user confirmation, never inferred from a cookie
/// or a public homepage. The actual WebKit session is reused by the main tabs.
private struct WelcomeLoginFlow: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @Binding var confirmed: Set<SiteID>
    @State private var selected: SiteID?

    private var site: SiteID {
        selected ?? SiteID.allCases.first { !confirmed.contains($0) } ?? .portal
    }

    var body: some View {
        NavigationStack {
            WelcomeLoginPage(model: app.browser(for: site), site: site) {
                confirmed.insert(site)
                Haptics.success()
                if let next = SiteID.allCases.first(where: { !confirmed.contains($0) }) {
                    selected = next
                } else {
                    dismiss()
                }
            }
            .id(site)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("返回")) { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 3) {
                        Text(site.displayName).font(.headline)
                        HStack(spacing: 8) {
                        ForEach(SiteID.allCases) { item in
                            Image(systemName: confirmed.contains(item) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(confirmed.contains(item) || item == site ? Theme.accent : Color.secondary)
                                .font(.caption)
                                .accessibilityLabel(item.displayName + " · " + (confirmed.contains(item) ? L10n.tr("已确认登录") : L10n.tr("待登录")))
                        }
                        }
                    }
                }
            }
        }
    }
}

private struct WelcomeLoginPage: View {
    @ObservedObject var model: BrowserModel
    let site: SiteID
    let confirm: () -> Void

    var body: some View {
        NativeWebPageView(site: site, title: site.displayName, url: site.homeURL)
            .safeAreaInset(edge: .bottom) {
                Button(action: confirm) {
                    Label(L10n.tr("确认已登录，继续"), systemImage: "checkmark")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!WelcomeLoginPolicy.canConfirm(site: site, url: model.currentURL, loaded: model.hasLoadedOnce, loading: model.isLoading, error: model.errorText))
                .padding(16)
                .background(.regularMaterial)
            }
    }
}

private struct WelcomeReveal: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let active: Bool
    let index: Int
    @State private var revealed = false

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: reduceMotion || revealed ? 0 : 10)
            .task(id: active) {
                guard active else { revealed = false; return }
                if reduceMotion { revealed = true; return }
                try? await Task.sleep(for: .milliseconds(60 + index * 55))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.32)) { revealed = true }
            }
    }
}

/// Page readiness only; completion always requires the user's explicit tap.
enum WelcomeLoginPolicy {
    static func canConfirm(site: SiteID, url: URL?, loaded: Bool, loading: Bool, error: String?) -> Bool {
        guard loaded, !loading, error == nil, let url, url.scheme == "https",
              url.host == site.host, !NavigationPolicy.isAuthentication(url) else { return false }
        return true
    }
}
