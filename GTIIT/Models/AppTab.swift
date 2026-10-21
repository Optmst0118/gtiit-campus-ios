import Foundation

/// 底部四个一级入口。研究建议的「今日」由学生门户 Dashboard 网页承担，
/// 因此这里保留「门户 / 学习 / 预约 / 我的」四个一级容器。
enum AppTab: String, CaseIterable, Identifiable {
    case portal
    case learning
    case booking
    case me

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portal: return "门户"
        case .learning: return "学习"
        case .booking: return "预约"
        case .me: return "我的"
        }
    }

    var symbol: String {
        switch self {
        case .portal: return "house.fill"
        case .learning: return "book.closed.fill"
        case .booking: return "calendar.badge.clock"
        case .me: return "person.crop.circle.fill"
        }
    }

    /// 「预约」Tab 内部的两个网页分段。
    var primarySite: SiteID? {
        switch self {
        case .portal: return .portal
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
        case .rooms: return "练习房 / 讨论室"
        case .sports: return "体育场馆"
        }
    }

    var shortTitle: String {
        switch self {
        case .rooms: return "练习房"
        case .sports: return "体育"
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
