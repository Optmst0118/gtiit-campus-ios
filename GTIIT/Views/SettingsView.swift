import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        List {
            Section {
                NavigationLink {
                    GeneralSettingsView()
                } label: {
                    SettingsLabel("通用", symbol: "slider.horizontal.3")
                }
                NavigationLink {
                    PrivacySettingsView()
                } label: {
                    SettingsLabel("隐私与锁定", symbol: "lock.shield")
                }
                NavigationLink {
                    BrowsingSettingsView()
                } label: {
                    SettingsLabel("网页浏览", symbol: "safari")
                }
            }
            Section {
                NavigationLink {
                    SitesSettingsView()
                } label: {
                    SettingsLabel("站点与登录", symbol: "person.crop.rectangle")
                }
                NavigationLink {
                    StorageSettingsView(center: app.downloads)
                } label: {
                    SettingsLabel("存储空间", symbol: "internaldrive")
                }
                NavigationLink {
                    DownloadsView(center: app.downloads)
                } label: {
                    SettingsLabel("下载管理", symbol: "arrow.down.circle")
                }
            }
            Section {
                NavigationLink {
                    HelpView()
                } label: {
                    SettingsLabel("帮助与诊断", symbol: "questionmark.circle")
                }
                NavigationLink {
                    AboutView()
                } label: {
                    SettingsLabel("关于 GTIIT", symbol: "info.circle")
                }
            } footer: {
                Text("GTIIT \(AppInfo.versionText) · 非官方客户端")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.pageBackground)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
    }
}
struct SettingsLabel: View {
    let title: String
    let symbol: String
    init(_ title: String, symbol: String) {
        self.title = title
        self.symbol = symbol
    }
    var body: some View {
        Label {
            Text(title).foregroundStyle(.primary)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 24)
        }.padding(.vertical, 3)
    }
}
private struct GeneralSettingsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        Form {
            Section("显示") {
                SettingsChoicePicker(
                    "外观", selection: $settings.appearance, choices: AppAppearance.allCases,
                    title: { $0.title })
            }
            Section {
                SettingsChoicePicker(
                    "启动页面", selection: $settings.startupTab, choices: AppTab.allCases, title: { $0.title })
                SettingsChoicePicker(
                    "默认预约分类", selection: $settings.defaultBooking, choices: BookingSegment.allCases,
                    title: { $0.title })
                Toggle("启动时预加载网站", isOn: $settings.preloadSitesOnLaunch)
            } header: {
                Text("启动")
            } footer: {
                Text("下次启动时使用。预加载会并行准备四站并恢复有效会话，最多等待 10 秒；首次使用仍先显示启动说明。")
            }
            Section {
                Button("重新查看启动说明") { app.showWelcome = true }
            }
        }.navigationTitle("通用").navigationBarTitleDisplayMode(.inline)
    }
}
private struct PrivacySettingsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        Form {
            Section {
                Toggle("使用\(app.lock.biometryLabel)锁定", isOn: $settings.biometricLockEnabled)
                    .disabled(!app.lock.isBiometryAvailable && !settings.biometricLockEnabled)
                if settings.biometricLockEnabled {
                    SettingsChoicePicker(
                        "离开 App 后锁定", selection: $settings.lockDelay, choices: LockDelay.allCases,
                        title: { $0.title })
                    Button("立即锁定") { app.lock.lock() }
                }
            } footer: {
                Text(app.lock.isBiometryAvailable ? "由系统验证，支持设备密码回退。锁定不会退出学校账号。" : "请先在系统设置中设置设备密码或生物识别。")
            }
            Section {
                Toggle(
                    "在应用切换器中隐藏内容",
                    isOn: Binding(
                        get: { settings.hideInAppSwitcher || settings.biometricLockEnabled },
                        set: { settings.hideInAppSwitcher = $0 })
                )
                .disabled(settings.biometricLockEnabled)
            } footer: {
                Text("开启锁定时始终遮挡后台内容，包括分享面板和网页窗口。")
            }
            Section { NavigationLink("隐私与安全说明") { PrivacyAndSafetyView() } }
        }.navigationTitle("隐私与锁定").navigationBarTitleDisplayMode(.inline)
    }
}
private struct BrowsingSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        Form {
            Section {
                SettingsChoicePicker(
                    "其他网站链接", selection: $settings.externalLinks, choices: ExternalLinkMode.allCases,
                    title: { $0.title })
            } footer: {
                Text("只影响主动点击的普通外站链接。登录、表单和重定向保留原网页上下文。不同浏览器可能需要分别登录。")
            }
            Section {
                Toggle("重新打开上次浏览的页面", isOn: $settings.restoreLastPage)
            } footer: {
                Text("只在本机记住四站内不含查询参数的普通 HTTPS 地址；认证和表单页面不保存。关闭后删除已记住的地址。编辑内容与滚动位置不跨启动保存。")
            }
            Section {
                Toggle("网页暗色适配", isOn: $settings.webDarkMode)
            } footer: {
                Text("随 App 外观切换，仅调整四站的网页配色。图片与二维码保留原色，登录和表单仍由学校网页处理。各站更多菜单可单独恢复原色。")
            }
        }.navigationTitle("网页浏览").navigationBarTitleDisplayMode(.inline)
    }
}
struct SitesSettingsView: View {
    @EnvironmentObject private var app: AppModel
    var body: some View {
        List {
            Section {
                ForEach(SiteID.allCases) { site in
                    NavigationLink {
                        SiteDataView(site: site)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(site.displayName)
                            Text(app.storageStates[site] == true ? "本机有网页数据" : "本机无网页数据")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 3)
                    }
                }
            } footer: {
                Text("网页数据不代表当前已登录。四个站点分别管理登录状态。")
            }
        }.navigationTitle("站点与登录").navigationBarTitleDisplayMode(.inline)
            .task { await app.refreshStorageStates() }
    }
}
struct SiteDataView: View {
    @EnvironmentObject private var app: AppModel
    let site: SiteID
    @State private var confirmClear = false
    var body: some View {
        List {
            Section {
                LabeledContent("网址", value: site.host)
                Button("打开网站") { app.openSite(site) }
            }
            Section {
                if let summary = app.storageSummaries[site] {
                    LabeledContent("网页存储记录", value: String(summary.records))
                    LabeledContent("Cookie", value: String(summary.cookies))
                } else {
                    ProgressView("正在读取…")
                }
            } header: {
                Text("本机数据")
            } footer: {
                Text("数量仅用于存储管理，不判断登录是否有效。WebKit 不提供准确的分站占用字节数。")
            }
            Section("站点说明") {
                ForEach(site.capabilityNotes, id: \.self) {
                    Text($0).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Section {
                Button("清除登录与网页数据", role: .destructive) { confirmClear = true }.disabled(app.isClearingData)
            } footer: {
                Text("删除本站 Cookie、缓存、本地存储及 App 内浏览历史，停止本站下载。其他站点和已完成的下载文件不受影响。")
            }
        }.navigationTitle(site.displayName).navigationBarTitleDisplayMode(.inline)
            .task { await app.refreshStorageStates() }
            .confirmationDialog(
                "清除\(site.displayName)的数据？", isPresented: $confirmClear, titleVisibility: .visible
            ) {
                Button("清除并退出本站登录", role: .destructive) { Task { await app.clearData(for: site) } }
                Button("取消", role: .cancel) {}
            } message: {
                Text("未提交的网页内容会丢失。再次打开网站时需要重新登录；Safari 中的数据不受影响。")
            }
    }
}
struct StorageSettingsView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject private var center: DownloadCoordinator
    @State private var action: ClearAction?
    init(center: DownloadCoordinator) { self.center = center }
    enum ClearAction: String, Identifiable {
        case cache, all, downloads
        var id: String { rawValue }
    }
    var body: some View {
        List {
            Section {
                NavigationLink {
                    SitesSettingsView()
                } label: {
                    LabeledContent("网页数据", value: "按站点管理")
                }
                LabeledContent(
                    "本机下载",
                    value: ByteCountFormatter.string(fromByteCount: center.totalBytes, countStyle: .file))
            } footer: {
                Text("下载大小按本机现有文件计算。网页缓存的准确字节数无法从 WebKit 获取。")
            }
            if WebDataStoreRegistry.shared.pendingCleanupCount > 0 {
                Section {
                    Text("部分旧缓存尚在被系统释放。新的浏览会话已与旧数据隔离。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("重试清理旧缓存") {
                        Task {
                            await WebDataStoreRegistry.shared.cleanupRetiredStores()
                            await app.refreshStorageStates()
                            app.toast(
                                WebDataStoreRegistry.shared.pendingCleanupCount == 0
                                    ? "旧缓存已清理" : "系统仍在释放旧缓存，请稍后重试")
                        }
                    }
                }
            }
            Section {
                Button("仅清理网页缓存") { action = .cache }
                Button("清理本机下载", role: .destructive) { action = .downloads }
                Button("清除全部登录与网页数据", role: .destructive) { action = .all }
            }.disabled(app.isClearingData)
        }.navigationTitle("存储空间").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "确认清理？", isPresented: Binding(get: { action != nil }, set: { if !$0 { action = nil } }),
                titleVisibility: .visible
            ) {
                Button(action == .cache ? "清理缓存" : "清除", role: .destructive) {
                    let selection = action
                    action = nil
                    Task {
                        switch selection {
                        case .cache: await app.clearCaches()
                        case .all: await app.clearAllData()
                        case .downloads:
                            app.downloads.clear()
                            app.toast("已清理本机下载")
                        case .none: break
                        }
                    }
                }
                Button("取消", role: .cancel) { action = nil }
            } message: {
                Text(
                    action == .cache
                        ? "只清理缓存，保留 Cookie 与登录存储。不重新载入正在编辑的页面。"
                        : action == .downloads
                            ? "停止下载并删除 GTIIT/Downloads 内的文件。已另存到其他位置的副本不受影响。"
                            : "四站需要重新登录，未提交的内容会丢失。已完成的下载文件和 Safari 数据不受影响。")
            }
    }
}
