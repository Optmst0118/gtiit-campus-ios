import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $app.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.symbol)
                    }
                    .tag(tab)
            }
        }
        .tint(Theme.accent)
        .accessibilityHidden(app.lock.isLocked)
        .allowsHitTesting(!app.lock.isLocked)
        .onChange(of: app.selectedTab) { _, newValue in
            app.markVisited(newValue)
        }
        .overlay(alignment: .bottom) {
            if let text = app.toastText {
                ToastView(text: text)
                    .padding(.bottom, 58)
                    .allowsHitTesting(false)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: app.toastText)
            }
        }
        .overlay {
            LockGate(lock: app.lock)
                .zIndex(2)
        }
        .fullScreenCover(isPresented: $app.showWelcome) {
            WelcomeView()
                .environmentObject(app)
                .environmentObject(settings)
        }
        .sheet(item: $app.siteInfo) { site in
            SiteInfoView(site: site)
                .environmentObject(app)
        }
        .task {
            #if DEBUG
            applyDebugLaunchOverrides()
            #endif
        }
        .onAppear {
            if !settings.hasSeenWelcome {
                app.showWelcome = true
            } else if settings.biometricLockEnabled {
                app.lock.lock()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // 在切后台（含切换器快照）前就遮住内容，避免成绩页出现在系统快照里
            if phase == .background || phase == .inactive, settings.biometricLockEnabled {
                app.lock.lock()
            }
        }
    }

    #if DEBUG
    /// 只用于开发期截图/回归：`SIMCTL_CHILD_GTIIT_SKIP_WELCOME=1`、`GTIIT_TAB=me`。
    /// Release 构建里不存在这段代码。
    private func applyDebugLaunchOverrides() {
        let environment = ProcessInfo.processInfo.environment
        if environment["GTIIT_SKIP_WELCOME"] == "1" {
            settings.markWelcomeSeen()
            app.showWelcome = false
        }
        if let raw = environment["GTIIT_TAB"], let tab = AppTab(rawValue: raw) {
            app.select(tab: tab)
        }
    }
    #endif

    /// 首次进入某个 Tab 时才创建网页内核，避免冷启动同时打四个站点；
    /// 确认首次启动说明之前不创建任何 WebView（规格 F.5）。
    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        if app.visitedTabs.contains(tab), settings.hasSeenWelcome {
            switch tab {
            case .portal:
                SiteBrowserView(site: .portal)
            case .learning:
                SiteBrowserView(site: .moodle)
            case .booking:
                BookingTabView()
            case .me:
                MyTabView()
            }
        } else {
            Color.clear
        }
    }
}

/// 用 @ObservedObject 单独观察锁屏状态，避免 AppModel 再转发一层。
private struct LockGate: View {
    @ObservedObject var lock: AppLockController

    var body: some View {
        if lock.isLocked {
            LockScreenView()
                .environmentObject(lock)
                .transition(.opacity)
        }
    }
}