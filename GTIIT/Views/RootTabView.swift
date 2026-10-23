import SwiftUI
import WidgetKit

struct RootTabView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let _ = nativeLocale.identifier

        ZStack {
            // Lay out the WebKit views behind the UI so pages can restore
            // sessions/render without a blocking launch screen.
            if !app.launch.didFinish {
                WebPrewarmHost(models: app.launch.models)
                    .opacity(0.01)
            }
            tabs
        }
        .modifier(ContextMenuBackdrop(active: app.contextMenuSource != nil))
        .overlay { YilongOverlay(controller: app.yilong).allowsHitTesting(!app.lock.isLocked) }
        .onOpenURL { app.handleShuttleURL($0) }
        .modifier(RootLifecycle(app: app, settings: settings))
    }

    private var tabs: some View {
        TabView(selection: $app.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.symbol)
                    }
                    .tag(tab)
            }
        }
        .background(
            TabBarReselectObserver(
                currentSelection: { app.selectedTab },
                onReselect: { tab in app.reselect(tab: tab) }
            )
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
        )
    }
}

/// 放在启动页与主界面外层，切换界面不会重复显示引导、重置锁或启动网络请求。
private struct RootLifecycle: ViewModifier {
    @ObservedObject var app: AppModel
    @ObservedObject var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content.tint(Theme.accent)
        .accessibilityHidden(app.lock.isLocked)
        .allowsHitTesting(!app.lock.isLocked && !app.isClearingData)
        .onChange(of: app.selectedTab) { _, newValue in
            Haptics.selection()
            app.markVisited(newValue)
            app.downloads.dismissCompletedPresentation()
        }
        .onChange(of: app.bookingSegment) { _, _ in
            Haptics.selection()
            app.downloads.dismissCompletedPresentation()
        }
        .overlay {
            if app.isClearingData {
                ZStack {
                    Color(uiColor: .systemBackground).opacity(0.95).ignoresSafeArea()
                    ProgressView(L10n.tr("正在清理网页数据…")).padding()
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
                            Button(L10n.tr("完成")) { app.showDownloads = false }
                        }
                    }
            }.modifier(ContextMenuBackdrop(active: app.contextMenuSource != nil))
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
            LocalDiagnostics.shared.firstViewReady()
            #if DEBUG
                applyDebugLaunchOverrides()
            #endif
            app.prepareLaunchIfAllowed()
            syncShuttleSystemState()
            await WebDataStoreRegistry.shared.cleanupRetiredStores()
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
                Haptics.prepare()
                syncShuttleSystemState()
                app.lock.setActive(settings: settings)
                app.prepareLaunchIfAllowed()
            } else {
                app.yilong.close()
                app.lock.setInactive(settings: settings)
            }
        }
        .onChange(of: settings.shuttleTeachingWeek) { _, _ in syncShuttleSystemState() }
        .onChange(of: settings.favoriteShuttleDirection) { _, _ in syncShuttleSystemState() }
        .onChange(of: settings.language) { _, _ in syncShuttleSystemState() }
        .onChange(of: settings.privateShuttleReminders) { _, _ in syncShuttleSystemState() }
        .onChange(of: app.lock.isLocked) { _, locked in
            if !locked {
                Haptics.success()
                app.prepareLaunchIfAllowed()
            } else {
                app.yilong.close()
            }
        }
        .onChange(of: settings.hasSeenWelcome) { _, _ in app.prepareLaunchIfAllowed() }
        .onChange(of: app.showWelcome) { _, shown in if !shown { app.prepareLaunchIfAllowed() } }
    }

    private func syncShuttleSystemState() {
        WidgetCenter.shared.reloadTimelines(ofKind: "ShuttleHomeWidget")
        Task {
            await ShuttleLiveActivityController.shared.reconcile(direction: settings.favoriteShuttleDirection, teachingWeek: settings.shuttleTeachingWeek)
            await ShuttleNotificationCenter.shared.reconcile(teachingWeek: settings.shuttleTeachingWeek)
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
            if environment["GTIIT_SKIP_PRELOAD"] == "1" { app.launch.skip() }
            if let raw = environment["GTIIT_TAB"], let tab = AppTab(rawValue: raw) {
                app.select(tab: tab)
            }
            if let raw = environment["GTIIT_BOOKING"], let segment = BookingSegment(rawValue: raw) {
                app.bookingSegment = segment
            }
            if let raw = environment["GTIIT_REVIEW_URL"], let url = URL(string: raw),
                url.scheme == "https" || url.host == "127.0.0.1" {
                app.select(tab: .portal)
                app.browser(for: .portal).load(url)
            }
        }
    #endif

}

extension RootTabView {
    /// 启动预加载完成后复用同一批内核；未查看的标签仍延迟创建 SwiftUI 宿主。
    @ViewBuilder fileprivate func tabContent(for tab: AppTab) -> some View {
        if app.visitedTabs.contains(tab), settings.hasSeenWelcome {
            switch tab {
            case .shuttle:
                ShuttleView()
            case .portal:
                SiteBrowserView(site: .portal)
            case .learning:
                MoodleTabView()
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