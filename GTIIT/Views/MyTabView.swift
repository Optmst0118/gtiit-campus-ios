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

                    CampusShortcutsSection()
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

/// Shared by the Me page and the isolated visual review host.
struct CampusShortcutsSection: View {
    @EnvironmentObject private var app: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.tr("常用入口")).font(.headline).padding(.top, 12).padding(.horizontal, 2)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        NavigationLink { AcademicCalendarView() } label: {
                            CampusShortcutTile(title: L10n.tr("校历"), symbol: "calendar", tone: 0)
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
        }.sheet(isPresented: $importing) { TimetableImportView(automatic: true) }
    }
}

/// A blue palette with a clear progression between rows and consistent white ink.
private struct CampusShortcutTile: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let symbol: String
    let tone: Int
    private var colors: [Color] {
        let rows: [(Double, Double, Double)] = scheme == .dark ? [
            (0.025, 0.23, 0.46), (0.035, 0.27, 0.51), (0.045, 0.31, 0.56),
            (0.055, 0.35, 0.61), (0.070, 0.39, 0.66)
        ] : [
            (0.030, 0.30, 0.60), (0.040, 0.345, 0.65), (0.050, 0.39, 0.70),
            (0.070, 0.43, 0.74), (0.090, 0.465, 0.77)
        ]
        let c = rows[min(tone / 2, rows.count - 1)]
        let right = tone % 2 == 1
        let r = c.0 + (right ? 0.018 : 0)
        let g = c.1 - (right ? 0.018 : 0)
        let b = c.2 + (right ? 0.025 : 0)
        return [Color(red: r + 0.012, green: g + 0.012, blue: b + 0.015),
                Color(red: max(0, r - 0.020), green: g - 0.020, blue: b - 0.015)]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: symbol)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 25, weight: .medium))
                .frame(width: 30, height: 30, alignment: .leading)
                .accessibilityHidden(true)
            Text(title).font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(16).foregroundStyle(.white)
        .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(scheme == .dark ? 0.12 : 0.28), lineWidth: 0.5)
        }
        .shadow(color: colors.first!.opacity(scheme == .dark ? 0.20 : 0.23), radius: 9, x: 0, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
