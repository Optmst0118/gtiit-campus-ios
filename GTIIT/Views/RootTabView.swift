import SwiftUI
import WidgetKit
import UIKit

struct RootTabView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var sidebarVisible = true

    var body: some View {
        let _ = nativeLocale.identifier

        GeometryReader { geometry in
            let sidebar = PrimaryNavigationLayout.usesSidebar(geometry.size)
            ZStack {
                if !app.launch.didFinish {
                    WebPrewarmHost(models: app.launch.models).opacity(0.01)
                }
                NativePrimaryNavigation(wide: sidebar, onVisibilityChange: { sidebarVisible = $0 },
                    sidebar: sidebarContent.environmentObject(app).environmentObject(settings)
                        .environment(\.locale, nativeLocale).preferredColorScheme(colorScheme),
                    content: tabs(sidebar: sidebar).environmentObject(app).environmentObject(settings)
                        .environment(\.locale, nativeLocale).environment(\.campusSidebarNavigation, sidebar)
                        .preferredColorScheme(colorScheme))
                    .ignoresSafeArea(.container, edges: .bottom)
            }
            .background {
                if sidebar && sidebarVisible && UIDevice.current.userInterfaceIdiom == .phone {
                    HStack(spacing: 0) {
                        Color(uiColor: Theme.sidebarSurroundUIColor)
                            .frame(width: geometry.safeAreaInsets.leading + 12)
                        Color.clear
                    }.ignoresSafeArea()
                }
            }
            .overlay(alignment: .top) {
                // The page canvas continues behind the status bar / Dynamic Island;
                // no separate material or extra navigation plate is introduced.
                Rectangle()
                    .fill(Theme.pageBackground)
                    .frame(height: geometry.safeAreaInsets.top)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .modifier(ContextMenuBackdrop(active: app.contextMenuSource != nil))
            .overlay { YilongOverlay(controller: app.yilong).allowsHitTesting(!app.lock.isLocked) }
            .onOpenURL { app.handleShuttleURL($0) }
            .modifier(RootLifecycle(app: app, settings: settings))
            .environment(\.campusSidebarNavigation, sidebar)
        }.background(Theme.pageBackground.ignoresSafeArea())
    }

    private var sidebarContent: some View {
        List(selection: Binding<AppTab?>(
            get: { app.selectedTab },
            set: { value in
                guard let tab = value else { return }
                if app.selectedTab == tab { app.reselect(tab: tab) }
                else { app.select(tab: tab) }
            }
        )) {
            ForEach(AppTab.allCases) { tab in
                Label(tab.title, systemImage: tab.symbol).tag(tab)
            }
        }
        .listStyle(.sidebar)
        // Keep the menu canvas distinct from the detail page in every size class.
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: Theme.sidebarSurroundUIColor).ignoresSafeArea())
    }

    private func tabs(sidebar: Bool) -> some View {
        TabView(selection: $app.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                tabContent(for: tab)
                    .toolbar(sidebar ? .hidden : .visible, for: .tabBar)
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

/// Keep one hosting controller for the tabs through rotation. The split view
/// and sidebar are genuine system components, including their iOS 26 material.
private struct NativePrimaryNavigation<Sidebar: View, Content: View>: UIViewControllerRepresentable {
    let wide: Bool
    let onVisibilityChange: (Bool) -> Void
    let sidebar: Sidebar
    let content: Content
    func makeUIViewController(context: Context) -> NativePrimaryController<Sidebar, Content> {
        let controller = NativePrimaryController(sidebar: sidebar, content: content)
        controller.onVisibilityChange = onVisibilityChange
        controller.update(wide: wide, sidebar: sidebar, content: content)
        return controller
    }
    func updateUIViewController(_ controller: NativePrimaryController<Sidebar, Content>, context: Context) {
        controller.onVisibilityChange = onVisibilityChange
        controller.update(wide: wide, sidebar: sidebar, content: content)
    }
}
private final class NativePrimaryController<Sidebar: View, Content: View>: UISplitViewController, UISplitViewControllerDelegate {
    private let sidebarHost: UIHostingController<Sidebar>
    private let detailHost: UIHostingController<Content>
    private let detailNavigation: UINavigationController
    private let revealSidebarButton = UIButton(type: .system)
    var onVisibilityChange: ((Bool) -> Void)?
    private var reportedVisibility: Bool?
    private var wide: Bool?
    init(sidebar: Sidebar, content: Content) {
        sidebarHost = UIHostingController(rootView: sidebar)
        detailHost = UIHostingController(rootView: content)
        detailNavigation = UINavigationController(rootViewController: PrimaryDetailContainer(host: detailHost))
        super.init(style: .doubleColumn)
        delegate = self
        sidebarHost.title = "GTIIT"
        sidebarHost.view.backgroundColor = .clear
        view.backgroundColor = .clear
        detailHost.view.backgroundColor = Theme.pageUIColor
        detailNavigation.view.backgroundColor = Theme.pageUIColor
        detailNavigation.setNavigationBarHidden(true, animated: false)
        setViewController(UINavigationController(rootViewController: sidebarHost), for: .primary)
        minimumPrimaryColumnWidth = 180
        maximumPrimaryColumnWidth = 280
        preferredPrimaryColumnWidthFraction = 0.25
        preferredSplitBehavior = .tile
        displayModeButtonVisibility = .never
        var configuration: UIButton.Configuration
        if #available(iOS 26.0, *) { configuration = .glass() }
        else { configuration = .plain() }
        configuration.image = UIImage(systemName: "sidebar.left")
        revealSidebarButton.configuration = configuration
        revealSidebarButton.tintColor = UIColor(Theme.accent)
        revealSidebarButton.accessibilityLabel = L10n.tr("收起侧栏")
        revealSidebarButton.addTarget(self, action: #selector(toggleSidebarVisibility), for: .touchUpInside)
        view.addSubview(revealSidebarButton)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func collapseSidebar() {
        preferredDisplayMode = .secondaryOnly
        hide(.primary)
        view.setNeedsLayout()
    }
    @objc private func expandSidebar() {
        preferredDisplayMode = .oneBesideSecondary
        show(.primary)
        view.setNeedsLayout()
    }
    @objc private func toggleSidebarVisibility() {
        if wide == true && displayMode != .secondaryOnly { collapseSidebar() }
        else { expandSidebar() }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let expanded = wide == true && displayMode != .secondaryOnly
        if reportedVisibility != expanded {
            reportedVisibility = expanded
            DispatchQueue.main.async { [weak self] in self?.onVisibilityChange?(expanded) }
        }
        revealSidebarButton.isHidden = wide != true
        // Keep the single toggle at the physical top-leading corner, inside the
        // window safe area. In landscape the left safe area is created by the
        // Dynamic Island; using the window insets keeps the button off the
        // rounded hardware corner instead of drifting with the split view.
        let insets = view.window?.safeAreaInsets ?? view.safeAreaInsets
        let left = max(view.safeAreaInsets.left, insets.left)
        let top = max(view.safeAreaInsets.top, insets.top)
        revealSidebarButton.frame = CGRect(x: left + 8, y: top + 8, width: 44, height: 44)
        revealSidebarButton.accessibilityLabel = expanded ? L10n.tr("收起侧栏") : L10n.tr("展开侧栏")
        view.bringSubviewToFront(revealSidebarButton)
    }
    func update(wide: Bool, sidebar: Sidebar, content: Content) {
        sidebarHost.rootView = sidebar
        detailHost.rootView = content
        guard self.wide != wide else { return }
        self.wide = wide
        if wide {
            setViewController(nil, for: .compact)
            traitOverrides.horizontalSizeClass = .regular
            setViewController(detailNavigation, for: .secondary)
            preferredDisplayMode = .oneBesideSecondary
        } else {
            // A dedicated compact column avoids stacking the entire TabView
            // on the sidebar navigation controller (and an unwanted back bar).
            setViewController(nil, for: .secondary)
            setViewController(detailNavigation, for: .compact)
            traitOverrides.horizontalSizeClass = .compact
            preferredDisplayMode = .secondaryOnly
        }
        detailNavigation.setNavigationBarHidden(true, animated: false)
        view.setNeedsLayout()
    }
    func splitViewController(_ svc: UISplitViewController, topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column { .secondary }
    func splitViewController(_ svc: UISplitViewController, displayModeForExpandingToProposedDisplayMode proposedDisplayMode: UISplitViewController.DisplayMode) -> UISplitViewController.DisplayMode { .oneBesideSecondary }
}

/// iOS 26 can extend the secondary column underneath its floating sidebar.
/// Give nested SwiftUI navigation its actual usable horizontal bounds so its
/// back buttons stay in the detail column; keep vertical scroll-edge coverage.
private final class PrimaryDetailContainer: UIViewController {
    private let host: UIViewController
    private var safeTrailingConstraint: NSLayoutConstraint!
    private var edgeTrailingConstraint: NSLayoutConstraint!
    init(host: UIViewController) {
        self.host = host
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.pageUIColor
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        safeTrailingConstraint = host.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        edgeTrailingConstraint = host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            safeTrailingConstraint,
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let screenBounds = view.window?.bounds ?? view.bounds
        let edgeToEdge = traitCollection.userInterfaceIdiom == .phone && screenBounds.width > screenBounds.height
        // Preserve tablet and portrait sizing while releasing the phone's right
        // landscape gutter. Leading safe-area protection still belongs to the menu.
        if safeTrailingConstraint.isActive == edgeToEdge {
            NSLayoutConstraint.deactivate([safeTrailingConstraint, edgeTrailingConstraint])
            (edgeToEdge ? edgeTrailingConstraint : safeTrailingConstraint)?.isActive = true
        }
    }
}

/// 放在启动页与主界面外层，切换界面不会重复显示引导、重置锁或启动网络请求。
private struct RootLifecycle: ViewModifier {
    @ObservedObject var app: AppModel
    @ObservedObject var settings: AppSettings
    @Environment(\.campusSidebarNavigation) private var sidebar
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
                .padding(.bottom, sidebar ? 16 : 72)
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
