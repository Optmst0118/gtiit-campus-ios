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
        .allowsHitTesting(!app.lock.isLocked && !app.isClearingData)
        .onChange(of: app.selectedTab) { _, newValue in
            app.markVisited(newValue)
            app.downloads.dismissCompletedPresentation()
        }
        .onChange(of: app.bookingSegment) { _, _ in app.downloads.dismissCompletedPresentation() }
        .overlay {
            if app.isClearingData {
                ZStack {
                    Color(uiColor: .systemBackground).opacity(0.95).ignoresSafeArea()
                    ProgressView("正在清理网页数据…").padding()
                }.accessibilityAddTraits(.isModal)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            BrowserFeedbackOverlay(center: app.downloads, toastText: app.toastText)
                .padding(.horizontal, 16)
                .padding(.bottom, 72)
                .allowsHitTesting(!app.lock.isLocked && !app.isClearingData)
                .accessibilityHidden(app.lock.isLocked)
        }
        .sheet(isPresented: $app.showDownloads) {
            NavigationStack {
                DownloadsView(center: app.downloads)
                    .onAppear { app.downloads.dismissPresentation() }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { app.showDownloads = false }
                        }
                    }
            }
        }
        .background(
            SceneWindowReader { scene in
                app.privacyShield.attach(to: scene, lock: app.lock, settings: settings)
            }.frame(width: 0, height: 0)
        )
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
            await WebDataStoreRegistry.shared.cleanupRetiredStores()
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
            if phase == .active {
                app.lock.setActive(settings: settings)
            } else {
                app.lock.setInactive(settings: settings)
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
            if let raw = environment["GTIIT_REVIEW_URL"], let url = URL(string: raw),
                url.scheme == "https" || url.host == "127.0.0.1" {
                app.select(tab: .portal)
                app.browser(for: .portal).load(url)
            }
        }
    #endif

    /// 首次进入某个 Tab 时才创建网页内核，避免冷启动同时打四个站点；
    /// 确认首次启动说明之前不创建任何 WebView（规格 F.5）。
    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        if app.visitedTabs.contains(tab), settings.hasSeenWelcome {
            switch tab {
            case .shuttle:
                ShuttleView()
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
