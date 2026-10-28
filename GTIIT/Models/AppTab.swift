import Foundation

/// Stable raw values retain preferences while the 2.1 navigation is task-oriented.
enum AppTab: String, CaseIterable, Identifiable {
    case me
    case learning
    case shuttle
    case booking
    case portal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shuttle: return L10n.tr("班车")
        case .portal: return L10n.tr("校园")
        case .learning: return L10n.tr("学习")
        case .booking: return L10n.tr("预约")
        case .me: return L10n.tr("首页")
        }
    }

    var symbol: String {
        switch self {
        case .shuttle: return "bus.fill"
        case .portal: return "building.2.fill"
        case .learning: return "book.closed.fill"
        case .booking: return "calendar.badge.clock"
        case .me: return "house.fill"
        }
    }

    /// 「预约」Tab 内部的两个网页分段。
    var primarySite: SiteID? {
        switch self {
        case .shuttle: return nil
        case .portal: return nil
        case .learning: return .moodle
        case .booking: return nil
        case .me: return nil
        }
    }

    static func tab(for site: SiteID) -> AppTab {
        switch site {
        case .portal: return .portal
        case .moodle: return .learning
        case .rooms, .sports: return .booking
        case .serviceHub: return .portal
        }
    }
}

/// 「预约」Tab 顶部的分段：练习房（Booked）与体育中心（mike-x）。
enum BookingSegment: String, CaseIterable, Identifiable {
    case rooms
    case sports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rooms: return L10n.tr("练习房 / 讨论室")
        case .sports: return L10n.tr("体育场馆")
        }
    }

    var shortTitle: String {
        switch self {
        case .rooms: return L10n.tr("练习房")
        case .sports: return L10n.tr("体育")
        }
    }

    var site: SiteID {
        switch self {
        case .rooms: return .rooms
        case .sports: return .sports
        }
    }

    static func segment(for site: SiteID) -> BookingSegment? {
        switch site {
        case .rooms: return .rooms
        case .sports: return .sports
        default: return nil
        }
    }
}
