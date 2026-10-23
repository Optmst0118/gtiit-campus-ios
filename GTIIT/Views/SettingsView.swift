import SwiftUI

struct SettingsView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        let _ = nativeLocale.identifier

        List {
            Section {
                NavigationLink { LanguageSettingsView() } label: { SettingsLabel(L10n.tr("语言"), symbol: "globe") }
                NavigationLink { TimetableSettingsView() } label: { SettingsLabel(L10n.tr("课表"), symbol: "calendar.badge.plus") }
                if settings.yilongUnlocked {
                    NavigationLink { YilongSettingsView() } label: { SettingsLabel(L10n.tr("以龙"), symbol: "sparkles") }
                }
                NavigationLink {
                    GeneralSettingsView()
                } label: {
                    SettingsLabel(L10n.tr("通用"), symbol: "slider.horizontal.3")
                }
                NavigationLink {
                    PrivacySettingsView()
                } label: {
                    SettingsLabel(L10n.tr("隐私与锁定"), symbol: "lock.shield")
                }
                NavigationLink {
                    BrowsingSettingsView()
                } label: {
                    SettingsLabel(L10n.tr("网页浏览"), symbol: "safari")
                }
            }
            Section {
                NavigationLink {
                    SitesSettingsView()
                } label: {
                    SettingsLabel(L10n.tr("站点与登录"), symbol: "person.crop.rectangle")
                }
                NavigationLink {
                    StorageSettingsView(center: app.downloads)
                } label: {
                    SettingsLabel(L10n.tr("存储空间"), symbol: "internaldrive")
                }
                NavigationLink {
                    DownloadsView(center: app.downloads)
                } label: {
                    SettingsLabel(L10n.tr("下载管理"), symbol: "arrow.down.circle")
                }
            }
            Section {
                NavigationLink {
                    HelpView()
                } label: {
                    SettingsLabel(L10n.tr("帮助与诊断"), symbol: "questionmark.circle")
                }
                NavigationLink {
                    AboutView()
                } label: {
                    SettingsLabel(L10n.tr("关于 GTIIT"), symbol: "info.circle")
                }
            } footer: {
                Text(L10n.format("GTIIT %@ · 非官方客户端", String(describing: AppInfo.versionText)))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.pageBackground)
        .navigationTitle(L10n.tr("设置"))
        .navigationBarTitleDisplayMode(.large)
    }
}
struct SettingsLabel: View {
    @Environment(\.locale) private var nativeLocale
    let title: String
    let symbol: String
    init(_ title: String, symbol: String) {
        self.title = title
        self.symbol = symbol
    }
    var body: some View {
        let _ = nativeLocale.identifier

        Label {
            Text(title).foregroundStyle(.primary)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 24)
        }.padding(.vertical, 3)
    }
}
private struct GeneralSettingsView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        let _ = nativeLocale.identifier

        Form {
            Section(L10n.tr("显示")) {
                SettingsChoicePicker(
                    L10n.tr("外观"), selection: $settings.appearance, choices: AppAppearance.allCases,
                    title: { $0.title })
            }
            Section {
                SettingsChoicePicker(
                    L10n.tr("启动页面"), selection: $settings.startupTab, choices: AppTab.allCases, title: { $0.title })
                SettingsChoicePicker(
                    L10n.tr("默认预约分类"), selection: $settings.defaultBooking, choices: BookingSegment.allCases,
                    title: { $0.title })
                Toggle(L10n.tr("启动时预加载网站"), isOn: $settings.preloadSitesOnLaunch)
            } header: {
                Text(L10n.tr("启动"))
            } footer: {
                Text(L10n.tr("下次启动时使用。预加载会并行准备四站并恢复有效会话，最多等待 10 秒；首次使用仍先显示启动说明。"))
            }
            Section {
                NavigationLink { ShortcutSettingsView() } label: {
                    SettingsLabel(L10n.tr("管理常用入口"), symbol: "square.grid.2x2")
                }
            }
            Section {
                Button(L10n.tr("重新查看启动说明")) { app.showWelcome = true }
            }
        }.navigationTitle(L10n.tr("通用")).navigationBarTitleDisplayMode(.inline)
    }
}
private struct PrivacySettingsView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        let _ = nativeLocale.identifier

        Form {
            Section {
                Toggle(L10n.format("使用%@锁定", String(describing: app.lock.biometryLabel)), isOn: $settings.biometricLockEnabled)
                    .disabled(!app.lock.isBiometryAvailable && !settings.biometricLockEnabled)
                if settings.biometricLockEnabled {
                    SettingsChoicePicker(
                        L10n.tr("离开 App 后锁定"), selection: $settings.lockDelay, choices: LockDelay.allCases,
                        title: { $0.title })
                    Button(L10n.tr("立即锁定")) { app.lock.lock() }
                }
            } footer: {
                Text(app.lock.isBiometryAvailable ? L10n.tr("由系统验证，支持设备密码回退。锁定不会退出学校账号。") : L10n.tr("请先在系统设置中设置设备密码或生物识别。"))
            }
            Section {
                Toggle(
                    L10n.tr("在应用切换器中隐藏内容"),
                    isOn: Binding(
                        get: { settings.hideInAppSwitcher || settings.biometricLockEnabled },
                        set: { settings.hideInAppSwitcher = $0 })
                )
                .disabled(settings.biometricLockEnabled)
            } footer: {
                Text(L10n.tr("开启锁定时始终遮挡后台内容，包括分享面板和网页窗口。"))
            }
            Section { NavigationLink(L10n.tr("隐私与安全说明")) { PrivacyAndSafetyView() } }
        }.navigationTitle(L10n.tr("隐私与锁定")).navigationBarTitleDisplayMode(.inline)
    }
}
private struct BrowsingSettingsView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        let _ = nativeLocale.identifier

        Form {
            Section {
                SettingsChoicePicker(
                    L10n.tr("其他网站链接"), selection: $settings.externalLinks, choices: ExternalLinkMode.allCases,
                    title: { $0.title })
            } footer: {
                Text(L10n.tr("只影响主动点击的普通外站链接。登录、表单和重定向保留原网页上下文。不同浏览器可能需要分别登录。"))
            }
            Section {
                Toggle(L10n.tr("重新打开上次浏览的页面"), isOn: $settings.restoreLastPage)
            } footer: {
                Text(L10n.tr("只在本机记住四站内不含查询参数的普通 HTTPS 地址；认证和表单页面不保存。关闭后删除已记住的地址。编辑内容与滚动位置不跨启动保存。"))
            }
            Section {
                Toggle(L10n.tr("网页暗色适配"), isOn: $settings.webDarkMode)
            } footer: {
                Text(L10n.tr("随 App 外观切换，仅调整四站的网页配色。图片与二维码保留原色，登录和表单仍由学校网页处理。各站更多菜单可单独恢复原色。"))
            }
            Section {
                Toggle(L10n.tr("新版预约界面（Alpha）"), isOn: $settings.nativeBookingEnabled)
            } footer: {
                Text(L10n.tr("关闭后回到旧版网页预约界面；新版为原生重绘预览，最终预约仍在学校官方页面完成。"))
            }
        }.navigationTitle(L10n.tr("网页浏览")).navigationBarTitleDisplayMode(.inline)
    }
}
struct SitesSettingsView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    var body: some View {
        let _ = nativeLocale.identifier

        List {
            Section {
                ForEach(SiteID.allCases) { site in
                    NavigationLink {
                        SiteDataView(site: site)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(site.displayName)
                            Text(app.storageStates[site] == true ? L10n.tr("本机有网页数据") : L10n.tr("本机无网页数据"))
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 3)
                    }
                }
            } footer: {
                Text(L10n.tr("网页数据不代表当前已登录。四个站点分别管理登录状态。"))
            }
        }.navigationTitle(L10n.tr("站点与登录")).navigationBarTitleDisplayMode(.inline)
            .task { await app.refreshStorageStates() }
    }
}
struct SiteDataView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    let site: SiteID
    @State private var confirmClear = false
    var body: some View {
        let _ = nativeLocale.identifier

        List {
            Section {
                LabeledContent(L10n.tr("网址"), value: site.host)
                Button(L10n.tr("打开网站")) { app.openSite(site) }
            }
            Section {
                if let summary = app.storageSummaries[site] {
                    LabeledContent(L10n.tr("网页存储记录"), value: String(summary.records))
                    LabeledContent("Cookie", value: String(summary.cookies))
                } else {
                    ProgressView(L10n.tr("正在读取…"))
                }
            } header: {
                Text(L10n.tr("本机数据"))
            } footer: {
                Text(L10n.tr("数量仅用于存储管理，不判断登录是否有效。WebKit 不提供准确的分站占用字节数。"))
            }
            Section(L10n.tr("站点说明")) {
                ForEach(site.capabilityNotes, id: \.self) {
                    Text($0).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Section {
                Button(L10n.tr("清除登录与网页数据"), role: .destructive) { confirmClear = true }.disabled(app.isClearingData)
            } footer: {
                Text(L10n.tr("删除本站 Cookie、缓存、本地存储及 App 内浏览历史，停止本站下载。其他站点和已完成的下载文件不受影响。"))
            }
        }.navigationTitle(site.displayName).navigationBarTitleDisplayMode(.inline)
            .task { await app.refreshStorageStates() }
            .confirmationDialog(
                L10n.format("清除%@的数据？", String(describing: site.displayName)), isPresented: $confirmClear, titleVisibility: .visible
            ) {
                Button(L10n.tr("清除并退出本站登录"), role: .destructive) { Task { await app.clearData(for: site) } }
                Button(L10n.tr("取消"), role: .cancel) {}
            } message: {
                Text(L10n.tr("未提交的网页内容会丢失。再次打开网站时需要重新登录；Safari 中的数据不受影响。"))
            }
    }
}
struct StorageSettingsView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @ObservedObject private var center: DownloadCoordinator
    @State private var action: ClearAction?
    @State private var appFootprint = L10n.tr("正在计算…")
    init(center: DownloadCoordinator) { self.center = center }
    enum ClearAction: String, Identifiable {
        case cache, all, downloads
        var id: String { rawValue }
    }
    var body: some View {
        let _ = nativeLocale.identifier

        List {
            Section {
                LabeledContent(L10n.tr("App 总占用"), value: appFootprint)
            }
            Section {
                NavigationLink {
                    SitesSettingsView()
                } label: {
                    LabeledContent(L10n.tr("网页数据"), value: L10n.tr("按站点管理"))
                }
                LabeledContent(
                    L10n.tr("本机下载"),
                    value: ByteCountFormatter.string(fromByteCount: center.totalBytes, countStyle: .file))
            } footer: {
                Text(L10n.tr("下载大小按本机现有文件计算。网页缓存的准确字节数无法从 WebKit 获取。"))
            }
            if WebDataStoreRegistry.shared.pendingCleanupCount > 0 {
                Section {
                    Text(L10n.tr("部分旧缓存尚在被系统释放。新的浏览会话已与旧数据隔离。"))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button(L10n.tr("重试清理旧缓存")) {
                        Task {
                            await WebDataStoreRegistry.shared.cleanupRetiredStores()
                            await app.refreshStorageStates()
                            app.toast(
                                WebDataStoreRegistry.shared.pendingCleanupCount == 0
                                    ? L10n.tr("旧缓存已清理") : L10n.tr("系统仍在释放旧缓存，请稍后重试"))
                        }
                    }
                }
            }
            Section {
                Button(L10n.tr("仅清理网页缓存")) { action = .cache }
                Button(L10n.tr("清理本机下载"), role: .destructive) { action = .downloads }
                Button(L10n.tr("清除全部登录与网页数据"), role: .destructive) { action = .all }
            }.disabled(app.isClearingData)
        }.navigationTitle(L10n.tr("存储空间")).navigationBarTitleDisplayMode(.inline)
            .task {
                let bytes = await Task.detached(priority: .utility) { AppStorageFootprint.totalBytes() }.value
                appFootprint = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            }
            .confirmationDialog(
                L10n.tr("确认清理？"), isPresented: Binding(get: { action != nil }, set: { if !$0 { action = nil } }),
                titleVisibility: .visible
            ) {
                Button(action == .cache ? L10n.tr("清理缓存") : L10n.tr("清除"), role: .destructive) {
                    let selection = action
                    action = nil
                    Task {
                        switch selection {
                        case .cache: await app.clearCaches()
                        case .all: await app.clearAllData()
                        case .downloads:
                            app.downloads.clear()
                            app.toast(L10n.tr("已清理本机下载"))
                        case .none: break
                        }
                    }
                }
                Button(L10n.tr("取消"), role: .cancel) { action = nil }
            } message: {
                Text(
                    action == .cache
                        ? L10n.tr("只清理缓存，保留 Cookie 与登录存储。不重新载入正在编辑的页面。")
                        : action == .downloads
                            ? L10n.tr("停止下载并删除 GTIIT/Downloads 内的文件。已另存到其他位置的副本不受影响。")
                            : L10n.tr("四站需要重新登录，未提交的内容会丢失。已完成的下载文件和 Safari 数据不受影响。"))
            }
    }
}

struct ShortcutSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.locale) private var nativeLocale
    var body: some View {
        let _ = nativeLocale.identifier
        Form {
            Section {
                ForEach(CampusShortcut.all) { item in
                    Toggle(isOn: Binding(get: { settings.shortcutIDs.contains(item.id) }, set: { enabled in
                        if enabled { settings.shortcutIDs.insert(item.id) } else { settings.shortcutIDs.remove(item.id) }
                    })) { SettingsLabel(item.title, symbol: item.symbol) }
                }
            } footer: { Text(L10n.tr("开启以添加到我的页面；关闭仅移除快捷入口，不影响网站和数据。")) }
            Section { Button(L10n.tr("恢复默认入口")) { settings.shortcutIDs = CampusShortcut.defaults } }
        }.navigationTitle(L10n.tr("管理常用入口")).navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden).background(Theme.pageBackground)
    }
}