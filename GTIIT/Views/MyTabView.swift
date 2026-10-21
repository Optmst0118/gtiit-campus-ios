import SwiftUI

struct MyTabView: View {
    @EnvironmentObject private var app: AppModel
    @State private var showSettings = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("GTIIT 校园助手").font(.headline)
                            Text("校园服务，随手可达").font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "building.columns").font(.title2).foregroundStyle(Theme.accent)
                            .frame(width: 40, height: 44)
                    }
                    .padding(.vertical, 8)
                }
                Section("常用入口") {
                    ForEach(QuickLinkCatalog.highlights) { link in
                        Button {
                            app.open(link)
                        } label: {
                            HStack {
                                Label(link.title, systemImage: link.symbol)
                                Spacer()
                                Text(link.site.shortName).font(.subheadline).foregroundStyle(.secondary)
                            }.foregroundStyle(.primary).frame(minHeight: 32)
                        }
                    }
                }
                Section("校园网站") {
                    ForEach(SiteID.allCases) { site in
                        Button {
                            app.openSite(site)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: site.symbol).foregroundStyle(Theme.accent).frame(width: 24)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(site.displayName).foregroundStyle(.primary)
                                    Text(site.host).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.forward").font(.caption).foregroundStyle(
                                    .tertiary)
                            }.padding(.vertical, 3)
                        }
                    }
                }
                Section {
                    NavigationLink {
                        DownloadsView(center: app.downloads)
                    } label: {
                        Label("下载管理", systemImage: "arrow.down.circle")
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("设置", systemImage: "gearshape")
                    }
                    NavigationLink {
                        HelpView()
                    } label: {
                        Label("帮助与诊断", systemImage: "questionmark.circle")
                    }
                } footer: {
                    Text("非官方校园客户端。登录与业务操作在官方网页中完成。")
                }
            }
            .navigationTitle("我的")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("设置")
                }
            }
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
            .task {
                #if DEBUG
                    if ProcessInfo.processInfo.environment["GTIIT_SETTINGS"] == "1" { showSettings = true }
                #endif
            }
        }
    }
}
