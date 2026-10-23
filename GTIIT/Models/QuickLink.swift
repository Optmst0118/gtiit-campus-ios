import SwiftUI

/// 站点内的深浅链入口。路径全部来自研究资料的已读页面（2026-10-21），
/// 只做导航，不携带任何个人数据。
struct QuickLink: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let site: SiteID
    let urlString: String

    var url: URL? { URL(string: urlString) }
}

struct QuickLinkGroup: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let links: [QuickLink]
}

enum QuickLinkCatalog {
    static var groups: [QuickLinkGroup] { [
        QuickLinkGroup(
            id: "study",
            title: L10n.tr("学习与课程"),
            symbol: "graduationcap.fill",
            links: [
                QuickLink(id: "moodle.home", title: L10n.tr("我的课程"), subtitle: L10n.tr("Dashboard / 最近访问"), symbol: "book.closed.fill", site: .moodle, urlString: "https://moodle.gtiit.edu.cn/moodle/my/"),
                QuickLink(id: "moodle.upcoming", title: L10n.tr("截止与日历"), subtitle: "Upcoming events", symbol: "calendar.day.timeline.left", site: .moodle, urlString: "https://moodle.gtiit.edu.cn/moodle/calendar/view.php?view=upcoming"),
                QuickLink(id: "moodle.export", title: L10n.tr("导出日历"), subtitle: L10n.tr("官方 iCal 订阅入口"), symbol: "square.and.arrow.up", site: .moodle, urlString: "https://moodle.gtiit.edu.cn/moodle/calendar/export.php"),
                QuickLink(id: "moodle.timetable", title: L10n.tr("学校课表"), subtitle: L10n.tr("GTIIT Calendar 插件"), symbol: "tablecells", site: .moodle, urlString: "https://moodle.gtiit.edu.cn/moodle/local/calendar/index.php")
            ]
        ),
        QuickLinkGroup(
            id: "academics",
            title: L10n.tr("学业与成绩"),
            symbol: "doc.text.fill",
            links: [
                QuickLink(id: "portal.grades", title: L10n.tr("成绩"), subtitle: L10n.tr("Grades / 考试记录"), symbol: "chart.bar.doc.horizontal", site: .portal, urlString: "https://students.gtiit.edu.cn/grades"),
                QuickLink(id: "portal.enrollments", title: L10n.tr("选课与周课表"), subtitle: "Enrollments", symbol: "calendar", site: .portal, urlString: "https://students.gtiit.edu.cn/enrollments"),
                QuickLink(id: "portal.checklist", title: L10n.tr("培养计划"), subtitle: L10n.tr("PCC / PEC / GE / MOE 清单"), symbol: "checklist", site: .portal, urlString: "https://students.gtiit.edu.cn/checklist"),
                QuickLink(id: "portal.attendance", title: L10n.tr("刷卡考勤"), subtitle: "Summary / Records / Leave", symbol: "checkmark.circle", site: .portal, urlString: "https://students.gtiit.edu.cn/attendance")
            ]
        ),
        QuickLinkGroup(
            id: "services",
            title: L10n.tr("校园服务"),
            symbol: "building.columns.fill",
            links: [
                QuickLink(id: "portal.apps", title: L10n.tr("申请与下载"), subtitle: "Applications", symbol: "tray.full", site: .portal, urlString: "https://students.gtiit.edu.cn/apps"),
                QuickLink(id: "portal.leave", title: L10n.tr("请假申请"), subtitle: "Leave Request", symbol: "bed.double", site: .portal, urlString: "https://students.gtiit.edu.cn/apps/leave"),
                QuickLink(id: "portal.credits", title: L10n.tr("额外学分"), subtitle: "Additional Credits", symbol: "plus.forwardslash.minus", site: .portal, urlString: "https://students.gtiit.edu.cn/apps/addcredits"),
                QuickLink(id: "portal.eval", title: L10n.tr("教学评价"), subtitle: L10n.tr("开放时间以页面提示为准"), symbol: "star.bubble", site: .portal, urlString: "https://students.gtiit.edu.cn/evaluations")
            ]
        ),
        QuickLinkGroup(
            id: "booking",
            title: L10n.tr("场地与预约"),
            symbol: "calendar.badge.clock",
            links: [
                QuickLink(id: "rooms.dashboard", title: L10n.tr("预约面板"), subtitle: L10n.tr("Upcoming / 可用性"), symbol: "rectangle.grid.1x2", site: .rooms, urlString: "https://roombooking.gtiit.edu.cn/Web/dashboard.php"),
                QuickLink(id: "rooms.mine", title: L10n.tr("我的预约"), subtitle: "My Calendar", symbol: "calendar.badge.checkmark", site: .rooms, urlString: "https://roombooking.gtiit.edu.cn/Web/my-calendar.php"),
                QuickLink(id: "rooms.find", title: L10n.tr("查找空闲"), subtitle: "Find A Time", symbol: "magnifyingglass.circle", site: .rooms, urlString: "https://roombooking.gtiit.edu.cn/Web/search-availability.php"),
                QuickLink(id: "rooms.rid78", title: L10n.tr("D4-103-9 练习房"), subtitle: L10n.tr("原始目标资源 rid=78"), symbol: "pianokeys", site: .rooms, urlString: "https://roombooking.gtiit.edu.cn/Web/reservation.php?rid=78"),
                QuickLink(id: "sports.home", title: L10n.tr("体育中心首页"), subtitle: L10n.tr("场馆入口与开放时间"), symbol: "sportscourt", site: .sports, urlString: "https://gtiit.mike-x.com/0x2Rg"),
                QuickLink(id: "sports.badminton", title: L10n.tr("羽毛球馆"), subtitle: L10n.tr("会员登录入口"), symbol: "figure.badminton", site: .sports, urlString: "https://gtiit.mike-x.com/kcr2S")
            ]
        )
    ] }

    static var all: [QuickLink] { groups.flatMap(\.links) }

    /// 首页展示的 8 个高频入口。
    static var highlights: [QuickLink] {
        let ids = ["moodle.home", "moodle.upcoming", "portal.grades",
                   "portal.attendance", "portal.checklist", "rooms.dashboard", "rooms.find"]
        return all.filter { ids.contains($0.id) }
    }

    static func link(for id: String) -> QuickLink? {
        all.first { $0.id == id }
    }
}
struct CampusShortcut: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let link: QuickLink?
    static var all: [CampusShortcut] {
        let links = QuickLinkCatalog.highlights + QuickLinkCatalog.all.filter { item in
            !QuickLinkCatalog.highlights.contains(where: { $0.id == item.id })
        }
        return [CampusShortcut(id: "native.calendar", title: L10n.tr("校历"), symbol: "calendar", link: nil),
                CampusShortcut(id: "native.shuttle", title: L10n.tr("校园班车"), symbol: "bus.fill", link: nil)]
            + links.map { CampusShortcut(id: $0.id, title: $0.title, symbol: $0.symbol, link: $0) }
            + [CampusShortcut(id: "native.mail", title: L10n.tr("邮箱助手"), symbol: "envelope.fill", link: nil)]
    }
    static var defaults: Set<String> {
        Set(["native.calendar", "native.shuttle", "native.mail"] + QuickLinkCatalog.highlights.map(\.id))
    }
}
