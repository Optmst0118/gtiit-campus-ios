import SwiftUI

struct MyTabView: View {
    @EnvironmentObject private var app: AppModel
    @State private var showSettings = false
    var body: some View {
        NavigationStack {
            List {
                Section("常用入口") {
                    Button { app.select(tab: .shuttle) } label: {
                        HStack {
                            Label("校园班车", systemImage: "bus.fill").foregroundStyle(Theme.accent)
                            Spacer()
                            Text("南北校区").font(.subheadline).foregroundStyle(.secondary)
                        }.frame(minHeight: 32)
                    }
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
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.pageBackground)
            .navigationTitle("我的")
            .onAppear { app.downloads.dismissCompletedPresentation() }
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
