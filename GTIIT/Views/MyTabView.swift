import SwiftUI

/// 「我的」：原生页。只做站点/会话管理、快捷入口与说明，不承载学业数据。
struct MyTabView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings

    @State private var showClearAllDialog = false
    @State private var showClearSiteDialog = false
    @State private var pendingClearSite: SiteID?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    hero
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    ForEach(SiteID.allCases) { site in
                        siteRow(site)
                    }
                } header: {
                    Text("站点与会话")
                } footer: {
                    Text("四个站点各自使用独立的持久化网页容器，登录状态互不影响。「本机有网页数据」只表示浏览器存过内容，不代表当前已登录。左滑可查看站点说明或清除数据。")
                }

                Section("常用入口") {
                    ForEach(QuickLinkCatalog.highlights) { link in
                        Button {
                            app.open(link)
                        } label: {
                            quickLinkRow(link)
                        }
                        .buttonStyle(.plain)
                    }
                }

                settingsSection

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("非官方说明与隐私", systemImage: "info.circle")
                    }

                    HStack {
                        Text("版本")
                        Spacer()
                        Text(AppInfo.versionText)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("关于")
                } footer: {
                    Text("研究快照：\(AppInfo.researchDate)。学校页面结构与可用性可能随时调整。")
                }
            }
            .navigationTitle("我的")
            .scrollContentBackground(.hidden)
            .background(Theme.pageBackground)
            .task { await app.refreshStorageStates() }
            .confirmationDialog(
                "清除「\(pendingClearSite?.displayName ?? "")」的网页数据？",
                isPresented: $showClearSiteDialog,
                titleVisibility: .visible
            ) {
                Button("清除并重新登录", role: .destructive) {
                    guard let site = pendingClearSite else { return }
                    Task { await app.clearData(for: site) }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("会删除该站点的 Cookie、缓存与本地存储，其他站点不受影响。")
            }
            .confirmationDialog(
                "清除全部站点的网页数据？",
                isPresented: $showClearAllDialog,
                titleVisibility: .visible
            ) {
                Button("全部清除", role: .destructive) {
                    Task { await app.clearAllData() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("四个站点都需要重新登录，App 内不会保留任何账号信息。")
            }
        }
    }

    // MARK: - 顶部卡片

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent, Color(red: 0.10, green: 0.62, blue: 0.60)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppInfo.displayName)
                        .font(.headline)
                    Text(AppInfo.tagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(SiteID.allCases) { site in
                    HStack(spacing: 4) {
                        Image(systemName: site.symbol)
                            .font(.system(size: 9, weight: .semibold))
                        Text(site.shortName)
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(site.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(site.tint.opacity(0.12), in: Capsule())
                }
            }

            Text("非官方客户端。App 只作为四个官方网页的浏览容器，不读取、不上传任何账号数据。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .cardBackground()
    }

    // MARK: - 站点行

    private func siteRow(_ site: SiteID) -> some View {
        Button {
            app.openSite(site)
        } label: {
            HStack(spacing: 12) {
                SiteBadge(site: site, size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(site.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(statusText(site))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(site.tint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingClearSite = site
                showClearSiteDialog = true
            } label: {
                Label("清除", systemImage: "trash")
            }

            Button {
                app.siteInfo = site
            } label: {
                Label("说明", systemImage: "info.circle")
            }
            .tint(Theme.accent)
        }
    }

    private func statusText(_ site: SiteID) -> String {
        guard let hasData = app.storageStates[site] else { return site.host }
        return hasData ? "本机有网页数据（不代表已登录）" : "本机无网页数据"
    }

    // MARK: - 快捷入口

    private func quickLinkRow(_ link: QuickLink) -> some View {
        HStack(spacing: 12) {
            Image(systemName: link.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(link.site.tint)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(link.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(link.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(link.site.shortName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    // MARK: - 设置

    private var settingsSection: some View {
        Section {
            Toggle(isOn: $settings.biometricLockEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("使用\(app.lock.biometryLabel)锁定")
                        Text("切到后台后遮住网页内容")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Theme.accent)
                }
            }
            .disabled(!app.lock.isBiometryAvailable)

            Button(role: .destructive) {
                showClearAllDialog = true
            } label: {
                Label("清除全部网页数据", systemImage: "trash")
            }

            Button {
                settings.resetWelcome()
                app.showWelcome = true
            } label: {
                Label("重新查看首次启动说明", systemImage: "questionmark.circle")
            }
        } header: {
            Text("设置")
        } footer: {
            if app.lock.isBiometryAvailable {
                Text("锁定只影响界面可见性，不参与任何网络请求，也不改变学校的登录状态。")
            } else {
                Text("当前设备未设置面容 ID、触控 ID 或密码，锁定功能不可用。")
            }
        }
    }
}