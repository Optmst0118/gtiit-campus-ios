import SwiftUI

/// 「预约」Tab 的原生首页（alpha）：练习房与体育中心各有一套原生界面，
/// 最终预约仍交给学校官方网页完成，不读取、不伪造任何接口数据。
struct BookingTabView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @State private var official: BookingDestination?

    var body: some View {
        let _ = nativeLocale.identifier

        Group {
            if settings.nativeBookingEnabled {
                nativeBooking
            } else {
                // Old alpha / 1.x experience: the original wrapped web pages.
                SiteBrowserView(site: app.bookingSegment == .rooms ? .rooms : .sports)
            }
        }
        .sheet(item: $official) { destination in
            BookingOfficialSheet(destination: destination)
                .environmentObject(app)
        }
        .onAppear { consumePendingLink() }
        .onChange(of: app.pendingBookingLink) { _, _ in consumePendingLink() }
    }

    private var nativeBooking: some View {
        NavigationStack {
            Group {
                if app.bookingSegment == .rooms {
                    RoomBookingHomeView(open: open)
                } else {
                    SportsCenterHomeView(open: open)
                }
            }
            .id(app.bookingSegment)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { BookingSiteMenu() }
            }
        }
    }

    private var title: String {
        app.bookingSegment == .rooms ? "GTIIT Room Booking" : "GTIIT Sports Center"
    }

    private func open(_ destination: BookingDestination) {
        official = destination
    }

    /// Shortcuts from My/Settings still open the exact official page, now in a
    /// native sheet instead of loading a hidden background WebView.
    private func consumePendingLink() {
        guard let link = app.pendingBookingLink, let url = link.url else { return }
        app.pendingBookingLink = nil
        official = BookingDestination(site: link.site, title: link.title, url: url)
    }
}

private struct BookingSiteMenu: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        Menu {
            Picker(L10n.tr("预约场所"), selection: $app.bookingSegment) {
                ForEach(BookingSegment.allCases) { segment in
                    Label(segment.title, systemImage: segment == .rooms ? "door.left.hand.open" : "sportscourt")
                        .tag(segment)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: app.bookingSegment == .rooms ? "door.left.hand.open" : "sportscourt")
                    .font(.system(size: 15, weight: .medium))
                Text(app.bookingSegment == .rooms ? L10n.tr("练习房") : L10n.tr("体育场馆"))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.tr("切换预约场所"))
        .menuOrder(.fixed)
    }
}

// MARK: - Shared alpha chrome

struct AlphaBadge: View {
    var body: some View {
        Text("ALPHA")
            .font(.caption2.weight(.bold))
            .tracking(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(Theme.orange)
            .background(Theme.orange.opacity(0.14), in: Capsule())
            .accessibilityLabel(L10n.tr("Alpha 预览版"))
    }
}

private struct BookingHeader: View {
    let symbol: String
    let eyebrow: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 54)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                Spacer(minLength: 8)
                AlphaBadge()
            }
            Text(eyebrow)
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(tint)
            Text(title)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [tint.opacity(0.17), tint.opacity(0.04)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(tint.opacity(0.12))
        }
    }
}

private struct BookingAction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let destination: BookingDestination
}

private struct BookingActionCard: View {
    let action: BookingAction
    let onOpen: (BookingDestination) -> Void

    var body: some View {
        Button { onOpen(action.destination) } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: action.symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 38, height: 38)
                    .background(Theme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(action.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Text(action.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .padding(16)
            .cardBackground()
        }
        .buttonStyle(CardPressStyle())
    }
}

private struct BookingLinkRowContent: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    var accessory: String = "arrow.up.right"

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: accessory).font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(corner: 16)
    }
}

private struct BookingLinkRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            BookingLinkRowContent(title: title, subtitle: subtitle, symbol: symbol, tint: tint)
        }
        .buttonStyle(CardPressStyle())
    }
}

// MARK: - Room booking

struct RoomBookingHomeView: View {
    @Environment(\.locale) private var nativeLocale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let open: (BookingDestination) -> Void

    var body: some View {
        let _ = nativeLocale.identifier

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                BookingHeader(
                    symbol: "door.left.hand.open",
                    eyebrow: L10n.tr("GTIIT ROOM BOOKING"),
                    title: L10n.tr("练习房与讨论室"),
                    subtitle: "",
                    tint: Theme.accent
                )

                LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(actions) { action in
                        BookingActionCard(action: action, onOpen: open)
                    }
                }

                sectionTitle(L10n.tr("房间目录"), symbol: "square.grid.2x2")
                VStack(spacing: 10) {
                    ForEach(BookingDirectory.roomCategories) { category in
                        NavigationLink {
                            RoomCategoryDetailView(category: category, open: open)
                        } label: {
                            BookingLinkRowContent(
                                title: category.title,
                                subtitle: "\(category.rooms.count) \(L10n.tr("间"))",
                                symbol: category.symbol,
                                tint: Theme.accent,
                                accessory: "chevron.right"
                            )
                        }
                        .buttonStyle(CardPressStyle())
                    }
                }

            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.pageBackground)
    }

    private var actions: [BookingAction] {
        [
            BookingAction(title: L10n.tr("查找可用时间"), subtitle: L10n.tr("按日期、时长与房间筛选"), symbol: "magnifyingglass.circle", destination: BookingDestination(site: .rooms, title: L10n.tr("查找可用时间"), url: BookingDirectory.roomsSearchURL)),
            BookingAction(title: L10n.tr("我的预约"), subtitle: L10n.tr("官方个人日历与预约记录"), symbol: "calendar.badge.checkmark", destination: BookingDestination(site: .rooms, title: L10n.tr("我的预约"), url: BookingDirectory.roomsMyCalendarURL)),
            BookingAction(title: L10n.tr("预约查询"), subtitle: L10n.tr("查看已有预约状态"), symbol: "text.magnifyingglass", destination: BookingDestination(site: .rooms, title: L10n.tr("预约查询"), url: BookingDirectory.roomsSearchReservationsURL)),
            BookingAction(title: L10n.tr("公开排程"), subtitle: L10n.tr("查看房间与排程目录"), symbol: "calendar", destination: BookingDestination(site: .rooms, title: L10n.tr("公开排程"), url: BookingDirectory.roomsPublicScheduleURL))
        ]
    }

    private func sectionTitle(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.title3.weight(.semibold))
            .padding(.top, 2)
    }
}

private struct RoomCategoryDetailView: View {
    @Environment(\.locale) private var nativeLocale
    let category: RoomCategory
    let open: (BookingDestination) -> Void

    var body: some View {
        let _ = nativeLocale.identifier
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(category.rooms) { room in
                    BookingLinkRow(title: room.name, subtitle: "", symbol: category.symbol, tint: Theme.accent) {
                        open(BookingDestination(site: .rooms, title: room.name, url: BookingDirectory.roomReservation(room.rid)))
                    }
                }            }
            .padding(20)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.pageBackground)
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sports centre

struct SportsCenterHomeView: View {
    @Environment(\.locale) private var nativeLocale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let open: (BookingDestination) -> Void

    var body: some View {
        let _ = nativeLocale.identifier

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                BookingHeader(
                    symbol: "sportscourt",
                    eyebrow: L10n.tr("GTIIT SPORTS CENTER"),
                    title: L10n.tr("广东以色列理工学院体育中心"),
                    subtitle: "",
                    tint: Theme.orange
                )

                sectionTitle(L10n.tr("场馆预约"), symbol: "square.grid.2x2")
                LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Array(BookingDirectory.sports.enumerated()), id: \.element.id) { index, venue in
                        SportsVenueTile(venue: venue, tone: index) {
                            open(BookingDestination(site: .sports, title: venue.title, url: venue.url))
                        }
                    }
                }

                hours
                membership
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.pageBackground)
    }

    private var hours: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.tr("开放时间"), systemImage: "clock.fill")
                .font(.headline)
                .foregroundStyle(Theme.accent)
            ForEach(BookingDirectory.openingHours) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.title).font(.subheadline.weight(.semibold))
                        Spacer(minLength: 12)
                    }
                    Text(row.value).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if row.id != BookingDirectory.openingHours.last?.id { Divider() }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private var membership: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("会员与预约")).font(.headline)
            BookingLinkRow(title: L10n.tr("会员登录"), subtitle: L10n.tr("进入体育中心官方预约页"), symbol: "person.crop.circle.badge.checkmark", tint: Theme.orange) {
                open(BookingDestination(site: .sports, title: L10n.tr("会员登录"), url: BookingDirectory.sportsHomeURL))
            }
            BookingLinkRow(title: L10n.tr("注册会员"), subtitle: L10n.tr("新会员注册与身份验证"), symbol: "person.badge.plus", tint: Theme.orange) {
                open(BookingDestination(site: .sports, title: L10n.tr("注册会员"), url: BookingDirectory.sportsRegistrationURL))
            }
        }
    }

    private func sectionTitle(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.title3.weight(.semibold))
            .padding(.top, 2)
    }
}

private struct SportsVenueTile: View {
    let venue: SportsVenue
    let tone: Int
    let onOpen: () -> Void
    private var tint: Color { tone.isMultiple(of: 2) ? Theme.accent : Theme.orange }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: venue.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                Text(venue.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(venue.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(15)
            .cardBackground()
        }
        .buttonStyle(CardPressStyle())
        .accessibilityLabel("\(venue.title), \(venue.subtitle)")
    }
}

// MARK: - Official web sheet

struct BookingDestination: Identifiable {
    let id = UUID()
    let site: SiteID
    let title: String
    let url: URL
}

private struct BookingOfficialSheet: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    let destination: BookingDestination

    var body: some View {
        NavigationStack {
            WebViewContainer(model: app.browser(for: destination.site))
                .navigationTitle(destination.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.tr("完成")) { dismiss() }
                    }
                }
                .onAppear {
                    let browser = app.browser(for: destination.site)
                    if browser.webView.url?.absoluteString != destination.url.absoluteString {
                        browser.load(destination.url)
                    }
                }
        }
    }
}

// MARK: - Local directory (from the 2026-10 public research snapshot)

struct RoomOption: Identifiable {
    let id: String
    let name: String
    let note: String
    let rid: Int
}

struct RoomCategory: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let rooms: [RoomOption]
}

struct SportsVenue: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let url: URL
}

struct OpeningHourRow: Identifiable {
    let id: String
    let title: String
    let value: String
}

enum BookingDirectory {
    static let roomsSearchURL = URL(string: "https://roombooking.gtiit.edu.cn/Web/search-availability.php")!
    static let roomsMyCalendarURL = URL(string: "https://roombooking.gtiit.edu.cn/Web/my-calendar.php")!
    static let roomsSearchReservationsURL = URL(string: "https://roombooking.gtiit.edu.cn/Web/search-reservations.php")!
    static let roomsPublicScheduleURL = URL(string: "https://roombooking.gtiit.edu.cn/Web/view-calendar.php")!
    static let roomsScheduleURL = URL(string: "https://roombooking.gtiit.edu.cn/Web/view-calendar.php")!

    static func roomSchedule(_ sid: Int) -> URL {
        URL(string: "https://roombooking.gtiit.edu.cn/Web/view-calendar.php?sid=\(sid)")!
    }

    static func roomReservation(_ rid: Int) -> URL {
        URL(string: "https://roombooking.gtiit.edu.cn/Web/reservation.php?rid=\(rid)")!
    }
    static let sportsHomeURL = URL(string: "https://gtiit.mike-x.com/0x2Rg")!
    static let sportsRegistrationURL = URL(string: "https://gtiit.mike-x.com/VK31S")!

    static var roomCategories: [RoomCategory] { [
        RoomCategory(
            id: "practice", title: L10n.tr("练习房"), subtitle: L10n.tr("乐器练习与电子琴房"), symbol: "pianokeys",
            rooms: [
                room(78, "D4-103-9（电子琴）", L10n.tr("电子琴练习室")),
                room(77, "D4-103-10（自带乐器）", L10n.tr("乐器练习")),
                room(80, "D4-103-3（自带乐器）", L10n.tr("乐器练习")),
                room(79, "D4-103-4（架子鼓）", L10n.tr("架子鼓练习")),
                room(83, "D5-101-2（钢琴）", L10n.tr("钢琴练习")),
                room(71, "Dorm B, First floor, NC", L10n.tr("乐器练习")),
                room(70, "E602", L10n.tr("乐器练习")),
                room(72, "E604", L10n.tr("乐器练习"))
            ]),
        RoomCategory(
            id: "hub", title: L10n.tr("南校区学生中心"), subtitle: L10n.tr("自习与小组讨论"), symbol: "building.2.fill",
            rooms: [
                room(84, "SC Student hub-Room 1", L10n.tr("房间")),
                room(94, "SC Student hub-Room 2-Table 1", L10n.tr("桌位")),
                room(100, "SC Student hub-Room 2-Table 2", L10n.tr("桌位")),
                room(106, "SC Student hub-Room 3-Table 1", L10n.tr("桌位")),
                room(112, "SC Student hub-Room 3-Table 2", L10n.tr("桌位")),
                room(114, "SC Student hub-Room 4-Table 1", L10n.tr("桌位")),
                room(119, "SC Student hub-Room 4-Table 2", L10n.tr("桌位")),
                room(123, "SC Student hub-Room 5-Table 1", L10n.tr("桌位")),
                room(127, "SC Student hub-Room 5-Table 2", L10n.tr("桌位"))
            ]),
        RoomCategory(
            id: "discussion-main", title: L10n.tr("北校区讨论室"), subtitle: L10n.tr("E105 小组讨论空间"), symbol: "bubble.left.and.bubble.right.fill",
            rooms: [
                room(64, "E105-1", L10n.tr("小组讨论")),
                room(65, "E105-2", L10n.tr("小组讨论")),
                room(66, "E105-3", L10n.tr("小组讨论")),
                room(67, "E105-4", L10n.tr("小组讨论")),
                room(68, "E105-5", L10n.tr("小组讨论")),
                room(69, "E105-6", L10n.tr("小组讨论"))
            ]),
        RoomCategory(
            id: "discussion-sc", title: L10n.tr("南校区教室"), subtitle: L10n.tr("SC E1/E2 教室"), symbol: "door.left.hand.open",
            rooms: [
                room(128, "SC E1-402", L10n.tr("小组讨论")),
                room(129, "SC E1-403", L10n.tr("小组讨论")),
                room(130, "SC E1-404", L10n.tr("小组讨论")),
                room(132, "SC E1-405", L10n.tr("小组讨论")),
                room(133, "SC E1-407", L10n.tr("小组讨论")),
                room(134, "SC E2-407", L10n.tr("小组讨论")),
                room(135, "SC E2-408", L10n.tr("小组讨论")),
                room(136, "SC E2-409", L10n.tr("小组讨论")),
                room(137, "SC E1-202", L10n.tr("小组讨论")),
                room(138, "SC E1-203", L10n.tr("小组讨论")),
                room(139, "SC E1-204", L10n.tr("小组讨论")),
                room(140, "SC E1-205", L10n.tr("小组讨论"))
            ]),
        RoomCategory(
            id: "activity", title: L10n.tr("学生活动室"), subtitle: L10n.tr("社团与学生活动空间"), symbol: "party.popper.fill",
            rooms: [
                room(81, "D5-101-3", L10n.tr("活动室")),
                room(82, "D5-101-5", L10n.tr("活动室"))
            ])
    ] }

    private static func room(_ rid: Int, _ name: String, _ note: String) -> RoomOption {
        RoomOption(id: "r\(rid)", name: name, note: note, rid: rid)
    }

    static var sports: [SportsVenue] { [
        SportsVenue(id: "north-tt", title: L10n.tr("北校区乒乓球室"), subtitle: "North Campus Table Tennis Room", symbol: "figure.table.tennis", url: URL(string: "https://gtiit.mike-x.com/0TZPp")!),
        SportsVenue(id: "outdoor-tennis", title: L10n.tr("室外网球场"), subtitle: "Outdoor Tennis Court", symbol: "figure.tennis", url: URL(string: "https://gtiit.mike-x.com/ACOAm")!),
        SportsVenue(id: "south-tt", title: L10n.tr("南校区乒乓球台"), subtitle: "South Campus Table Tennis", symbol: "figure.table.tennis", url: URL(string: "https://gtiit.mike-x.com/J8PeH")!),
        SportsVenue(id: "small-football", title: L10n.tr("小足球场"), subtitle: "Small Football Pitch", symbol: "figure.soccer", url: URL(string: "https://gtiit.mike-x.com/KeoJR")!),
        SportsVenue(id: "basketball", title: L10n.tr("室内篮球半场"), subtitle: "Indoor Basketball Half-Court", symbol: "figure.basketball", url: URL(string: "https://gtiit.mike-x.com/N9MTj")!),
        SportsVenue(id: "volleyball", title: L10n.tr("室内排球场"), subtitle: "Indoor Volleyball Court", symbol: "figure.volleyball", url: URL(string: "https://gtiit.mike-x.com/NqBp3")!),
        SportsVenue(id: "climbing", title: L10n.tr("攀岩墙"), subtitle: "Climbing Wall", symbol: "figure.climbing", url: URL(string: "https://gtiit.mike-x.com/QuPzR")!),
        SportsVenue(id: "swimming", title: L10n.tr("游泳馆"), subtitle: "Swimming Pool", symbol: "figure.pool.swim", url: URL(string: "https://gtiit.mike-x.com/SKANr")!),
        SportsVenue(id: "south-yoga", title: L10n.tr("南校区瑜伽房"), subtitle: "South Campus Yoga Room", symbol: "figure.yoga", url: URL(string: "https://gtiit.mike-x.com/ZbkLQ")!),
        SportsVenue(id: "north-yoga", title: L10n.tr("北校区瑜伽室"), subtitle: "North Campus Yoga Room", symbol: "figure.yoga", url: URL(string: "https://gtiit.mike-x.com/bMWdH")!),
        SportsVenue(id: "badminton", title: L10n.tr("羽毛球场"), subtitle: "Badminton Court", symbol: "figure.badminton", url: URL(string: "https://gtiit.mike-x.com/kcr2S")!),
        SportsVenue(id: "pilates", title: L10n.tr("普拉提晚场"), subtitle: "Pilates Center Evening", symbol: "figure.pilates", url: URL(string: "https://gtiit.mike-x.com/o2DRD")!),
        SportsVenue(id: "pickleball", title: L10n.tr("匹克球场"), subtitle: "Pickleball Court", symbol: "figure.tennis", url: URL(string: "https://gtiit.mike-x.com/ogyYI")!),
        SportsVenue(id: "main-football", title: L10n.tr("大足球场"), subtitle: "Main Football Pitch", symbol: "figure.soccer", url: URL(string: "https://gtiit.mike-x.com/ypF4B")!),
        SportsVenue(id: "d3-tt", title: L10n.tr("D3 栋乒乓球台"), subtitle: "D3 Table Tennis", symbol: "figure.table.tennis", url: URL(string: "https://gtiit.mike-x.com/yspKN")!)
    ] }

    static var openingHours: [OpeningHourRow] { [
        OpeningHourRow(id: "courts", title: L10n.tr("球类场地"), value: L10n.tr("周一至周五 11:30–21:30；周六、周日 08:00–21:30")),
        OpeningHourRow(id: "gym", title: L10n.tr("健身房与瑜伽室"), value: L10n.tr("每天 08:00–21:30")),
        OpeningHourRow(id: "pool", title: L10n.tr("游泳馆"), value: L10n.tr("周一关闭；周二至周五 17:00–21:30；周六、周日 15:00–21:00")),
        OpeningHourRow(id: "climb", title: L10n.tr("攀岩墙"), value: L10n.tr("周一至周五关闭；周六 14:00–17:00；周日关闭")),
        OpeningHourRow(id: "pilates", title: L10n.tr("普拉提中心"), value: L10n.tr("周一、周三、周五晚场；其余时间关闭"))
    ] }
}
