import SwiftUI

/// The campus destination owns complete websites and service routes. A website
/// is pushed into this stack, so Back always returns to the service directory.
struct CampusServicesView: View {
    @EnvironmentObject private var app: AppModel
    @State private var path: [CampusWebRoute] = []
    @State private var rootVisible = true
    @State private var navigationEpoch = UUID()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    NativePageIcon(symbol: "building.2.fill", tint: Theme.accent)
                    CampusLinkSection(title: "办事服务", ids: ["servicehub.home", "portal.leave", "portal.apps"])
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.tr("校园工具")).font(.headline)
                        NavigationLink { CampusDetailPage(destination: .academicCalendar) } label: {
                            CampusMenuRow(title: "校历", symbol: "calendar")
                        }
                        Link(destination: URL(string: "https://outlook.office.com/mail/")!) {
                            CampusMenuRow(title: "邮箱助手", symbol: "envelope")
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.tr("完整网站")).font(.headline)
                        ForEach(SiteID.allCases) { site in
                            Button { app.openSite(site) } label: {
                                CampusMenuRow(title: site.displayName, symbol: "safari")
                            }
                        }
                    }
                }.buttonStyle(CardPressStyle()).padding(20).frame(maxWidth: 720).frame(maxWidth: .infinity)
                    .id("campus.top")
            }.background(Theme.pageBackground)
                .onAppear { rootVisible = true }.onDisappear { rootVisible = false }
                .modifier(PrimaryPageScrollToTop(tab: .portal, anchor: "campus.top"))
                .navigationTitle(L10n.tr("校园")).navigationBarTitleDisplayMode(.large).nativeNavigationSurface(large: true)
                .navigationDestination(isPresented: Binding(get: { !path.isEmpty }, set: { if !$0 { path = [] } })) {
                    if let route = path.last {
                        if route.site == .serviceHub { ServiceCenterView(url: route.url) }
                        else { NativeWebPageView(site: route.site, title: route.title, url: route.url) }
                    }
                }
                .onChange(of: app.pendingWebRoute, initial: true) { _, route in
                    guard let route, route.site == .portal || route.site == .serviceHub else { return }
                    path = [route]; app.pendingWebRoute = nil
                }
        }
        .id(navigationEpoch)
        .onChange(of: app.tabReselectToken) { _, _ in
            guard app.tabReselectTarget == .portal, !rootVisible else { return }
            path = []; navigationEpoch = UUID()
        }
    }
}

struct CampusMenuRow: View {
    let title: String
    let symbol: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 26)
            Text(L10n.tr(title)).foregroundStyle(.primary)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }.padding(16).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).cardBackground()
    }
}

/// Direct navigation keeps academic tasks in Learning instead of switching tabs
/// solely because the underlying website is Student.
struct CampusLinkSection: View {
    let title: String
    let ids: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr(title)).font(.headline)
            ForEach(ids.compactMap { QuickLinkCatalog.link(for: $0) }) { link in
                if let url = link.url {
                    NavigationLink {
                        if link.site == .serviceHub { ServiceCenterView(url: url) }
                        else { NativeWebPageView(site: link.site, title: link.title, url: url) }
                    } label: { CampusMenuRow(title: link.title, symbol: link.symbol) }
                }
            }
        }.buttonStyle(CardPressStyle())
    }
}

struct AcademicServicesSection: View {
    var body: some View {
        CampusLinkSection(title: "学业事务", ids: ["portal.grades", "portal.enrollments", "portal.checklist", "portal.attendance", "portal.credits", "portal.eval"])
    }
}

struct StudyDestinationsView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 3), spacing: 10) {
            destination(.timetable, title: "课表", symbol: "calendar")
            destination(.assignments, title: "作业", symbol: "checklist")
            destination(.exams, title: "考试", symbol: "pencil.and.list.clipboard")
        }.buttonStyle(CardPressStyle())
    }
    private func destination(_ destination: CampusDetail, title: String, symbol: String) -> some View {
        NavigationLink { CampusDetailPage(destination: destination) } label: {
            VStack(spacing: 10) {
                Image(systemName: symbol).font(.title2)
                Text(L10n.tr(title)).font(.subheadline.weight(.semibold))
            }.foregroundStyle(Theme.accent).frame(maxWidth: .infinity, minHeight: 88).cardBackground()
        }
    }
}

struct UpcomingReservationsCard: View {
    @ObservedObject var sync: CampusSessionSync
    @EnvironmentObject private var app: AppModel
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let upcoming = CampusInboxPolicy.reservations(sync.reservations, now: context.date)
            if let item = upcoming.first {
                Button {
                    if let url = CachedRoomReservation.safeURL(item.url) {
                        app.openWeb(url, site: .rooms, title: L10n.tr("我的预约"))
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(L10n.tr("近期预约"), systemImage: "calendar.badge.clock").font(.headline).foregroundStyle(Theme.accent)
                        Text(item.title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                        Text(item.start.gtiitFormatted()).font(.subheadline).foregroundStyle(.secondary)
                        if !item.location.isEmpty { Label(item.location, systemImage: "mappin.and.ellipse").font(.subheadline).foregroundStyle(.secondary) }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
                }.buttonStyle(CardPressStyle())
            }
        }
    }
}
