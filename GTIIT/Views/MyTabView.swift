import SwiftUI

struct MyTabView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @State private var showSettings = false
    var body: some View {
        let _ = nativeLocale.identifier

        NavigationStack {
            List {
                Section {
                    LocalTimetableEntry(store: app.timetable)
                    MoodleUpcomingEntry(store: app.upcoming)
                    NavigationLink { AcademicCalendarView() } label: { Label(L10n.tr("校历"), systemImage: "calendar.circle") }
                }
                Section(L10n.tr("常用入口")) {
                    Button { app.select(tab: .shuttle) } label: {
                        HStack {
                            Label(L10n.tr("校园班车"), systemImage: "bus.fill").foregroundStyle(Theme.accent)
                            Spacer()
                            Text(L10n.tr("南北校区")).font(.subheadline).foregroundStyle(.secondary)
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
                        Label(L10n.tr("下载管理"), systemImage: "arrow.down.circle")
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label(L10n.tr("设置"), systemImage: "gearshape")
                    }
                    NavigationLink {
                        HelpView()
                    } label: {
                        Label(L10n.tr("帮助与诊断"), systemImage: "questionmark.circle")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.pageBackground)
            .navigationTitle(L10n.tr("我的"))
            .onAppear { app.downloads.dismissCompletedPresentation() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(L10n.tr("设置"))
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

private struct LocalTimetableEntry: View {
    @Environment(\.locale) private var nativeLocale
    @ObservedObject var store: LocalTimetableStore
    @State private var importing = false
    var body: some View {
        let _ = nativeLocale.identifier
        Group {
            if store.snapshot != nil {
                NavigationLink { LocalTimetableView(store: store) } label: { TodayTimetableCard(store: store) }
                    .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    TodayTimetableCard(store: store)
                    Button { importing = true } label: {
                        Label(L10n.tr("从门户导入课表"), systemImage: "square.and.arrow.down")
                    }.buttonStyle(.borderedProminent).tint(Theme.accent)
                }.padding(.vertical, 6)
            }
        }.sheet(isPresented: $importing) {
            NavigationStack {
                TimetableImportView(automatic: true)
                    .toolbar { ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.tr("完成")) { importing = false }
                    } }
            }
        }
    }
}
