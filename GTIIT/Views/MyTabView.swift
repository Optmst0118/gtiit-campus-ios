import SwiftUI

struct MyTabView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @State private var showSettings = false
    var body: some View {
        let _ = nativeLocale.identifier

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LocalTimetableEntry(store: app.timetable)
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
                    MoodleUpcomingEntry(store: app.upcoming)
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                    Text(L10n.tr("常用入口")).font(.headline).padding(.top, 12).padding(.horizontal, 2)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        NavigationLink { AcademicCalendarView() } label: {
                            CampusShortcutTile(title: L10n.tr("校历"), symbol: "calendar.circle", tone: 0)
                        }
                        Button { app.select(tab: .shuttle) } label: {
                            CampusShortcutTile(title: L10n.tr("校园班车"), symbol: "bus.fill", tone: 1)
                        }
                        ForEach(Array(QuickLinkCatalog.highlights.enumerated()), id: \.element.id) { index, link in
                            Button { app.open(link) } label: {
                                CampusShortcutTile(title: link.title, symbol: link.symbol, tone: index + 2)
                            }
                        }
                    }.buttonStyle(.plain)

                    VStack(spacing: 0) {
                        NavigationLink { DownloadsView(center: app.downloads) } label: {
                            MyUtilityRow(title: L10n.tr("下载管理"), symbol: "arrow.down.circle")
                        }
                        Divider().padding(.leading, 50)
                        NavigationLink { SettingsView() } label: {
                            MyUtilityRow(title: L10n.tr("设置"), symbol: "gearshape")
                        }
                        Divider().padding(.leading, 50)
                        NavigationLink { HelpView() } label: {
                            MyUtilityRow(title: L10n.tr("帮助与诊断"), symbol: "questionmark.circle")
                        }
                    }.buttonStyle(.plain).cardBackground().padding(.top, 8)
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 20)
                .frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
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

/// A restrained blue family: small changes in luminance and saturation, with
/// consistent deep-blue labels and no secondary actions or source badges.
private struct CampusShortcutTile: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let symbol: String
    let tone: Int
    private var colors: [Color] {
        let palette: [(Double, Double, Double)] = [
            (0.65, 0.83, 0.96), (0.71, 0.86, 0.97),
            (0.62, 0.81, 0.95), (0.69, 0.85, 0.96),
            (0.64, 0.84, 0.97), (0.72, 0.86, 0.96)
        ]
        let c = palette[tone % palette.count]
        let r = c.0 - (scheme == .dark ? 0.24 : 0)
        let g = c.1 - (scheme == .dark ? 0.22 : 0)
        let b = c.2 - (scheme == .dark ? 0.18 : 0)
        return [Color(red: r + 0.035, green: g + 0.025, blue: min(1, b + 0.025)),
                Color(red: r - 0.02, green: g - 0.02, blue: b - 0.01)]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: symbol).font(.system(size: 25, weight: .medium)).accessibilityHidden(true)
            Text(title).font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(16).foregroundStyle(Color(red: 0.02, green: 0.145, blue: 0.245))
        .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct MyUtilityRow: View {
    let title: String
    let symbol: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 24)
            Text(title).foregroundStyle(.primary)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }.font(.body).frame(minHeight: 50).padding(.horizontal, 16).padding(.vertical, 2)
            .contentShape(Rectangle())
    }
}
