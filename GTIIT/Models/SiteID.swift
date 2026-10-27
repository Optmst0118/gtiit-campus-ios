import SwiftUI

/// 四个校园系统。URL 取自 2026-10-21 的研究快照
/// （GTIIT-iOS/research 与 GTIIT-iOS-续研/capability-matrix.json）。
enum SiteID: String, CaseIterable, Identifiable, Codable {
    case portal
    case moodle
    case rooms
    case sports
    case serviceHub

    static let onboardingSites: [SiteID] = [.portal, .moodle, .rooms, .sports]

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .portal: return L10n.tr("学生门户")
        case .moodle: return "Moodle"
        case .rooms: return L10n.tr("练习房预约")
        case .sports: return L10n.tr("体育中心")
        case .serviceHub: return L10n.tr("服务中心")
        }
    }

    /// Stable native navigation titles, independent of the current HTML document.
    var nativeTitle: String {
        switch self {
        case .portal: return "Student"
        case .moodle: return "Moodle dashboard"
        case .rooms: return "GTIIT Room Booking"
        case .sports: return "GTIIT Sports Center"
        case .serviceHub: return L10n.tr("服务中心")
        }
    }

    var shortName: String {
        switch self {
        case .portal: return L10n.tr("门户")
        case .moodle: return L10n.tr("学习")
        case .rooms: return L10n.tr("练习房")
        case .sports: return L10n.tr("体育")
        case .serviceHub: return L10n.tr("服务中心")
        }
    }

    var host: String {
        URL(string: homeURLString)?.host ?? ""
    }

    /// 站点首页。Moodle 与 Booked 都带路径前缀，不能只用域名。
    var homeURLString: String {
        switch self {
        case .portal: return "https://students.gtiit.edu.cn/"
        case .moodle: return "https://moodle.gtiit.edu.cn/moodle/my/"
        case .rooms: return "https://roombooking.gtiit.edu.cn/Web/dashboard.php"
        case .sports: return "https://gtiit.mike-x.com/0x2Rg"
        case .serviceHub: return "https://servicehub.gtiit.edu.cn/#ticket/view/my_tickets_as_customer"
        }
    }

    var homeURL: URL {
        URL(string: homeURLString) ?? URL(string: "about:blank")!
    }

    /// 用于跨站路由识别的域名（含别名后缀）。
    var aliases: [String] {
        switch self {
        case .portal: return ["students.gtiit.edu.cn"]
        case .moodle: return ["moodle.gtiit.edu.cn"]
        case .rooms: return ["roombooking.gtiit.edu.cn"]
        case .sports: return ["gtiit.mike-x.com"]
        case .serviceHub: return ["servicehub.gtiit.edu.cn"]
        }
    }

    var symbol: String {
        switch self {
        case .portal: return "person.text.rectangle.fill"
        case .moodle: return "book.closed.fill"
        case .rooms: return "calendar.badge.clock"
        case .sports: return "figure.badminton"
        case .serviceHub: return "bubble.left.and.bubble.right.fill"
        }
    }

    var tint: Color {
        switch self {
        case .portal, .rooms, .serviceHub: return Theme.accent
        case .moodle, .sports: return Theme.orange
        }
    }

    /// 站点说明卡里的首版能力边界（来自研究资料，不是实现承诺）。
    var capabilityNotes: [String] {
        switch self {
        case .portal:
            return [
                L10n.tr("登录由学校统一身份认证完成，会话只保存在本机的网页数据容器内。"),
                L10n.tr("成绩、选课、考勤、培养计划的原生读取尚无获准接口，首版一律以官方网页呈现。"),
                L10n.tr("请假、额外学分、教学评价等业务不代填、不代提交。"),
            ]
        case .moodle:
            return [
                L10n.tr("使用学校配置的浏览器登录（含 Office 365 / SAML2 入口），App 不接管 Moodle 移动令牌。"),
                L10n.tr("作业可能同时存在 Assignment 与 Quiz 两类，作答与提交仍在官方页面完成。"),
                L10n.tr("课程资料下载交给系统文件分享，App 不额外上传文件。"),
            ]
        case .rooms:
            return [
                L10n.tr("Booked 标准 API 在本校为关闭状态，首版只做官方网页容器与本地快捷入口。"),
                L10n.tr("可用性颜色与冲突校验以服务器结果为准，App 不预判空闲时段。"),
                L10n.tr("练习房管理规定来自官方文件（工作日 09:00–22:00、最多提前两天等），文件未标注生效日期。"),
            ]
        case .serviceHub: return []
        case .sports:
            return [
                L10n.tr("体育中心需要会员邮箱登录，会员权限、时段与票券规则都在官方页面内。"),
                L10n.tr("场馆目录来自公开入口，公开可见不代表本人可预约。"),
                L10n.tr("预约、取消与签到均不代提交。"),
            ]
        }
    }

    /// 站点用途（供说明卡使用）。
    var purpose: String {
        switch self {
        case .portal: return L10n.tr("查看学期课程、成绩与考试、刷卡考勤、选课与周课表、请假与额外学分申请、培养计划和教学评价。")
        case .moodle: return L10n.tr("查看课程概览、章节与资料、Assignment / Quiz 待办、分组与课程考勤、学校自定义课表与日历导出。")
        case .rooms: return L10n.tr("查看可预约资源、新建与查询预约、查看个人日历，以及按条件查找空闲时段。")
        case .sports: return L10n.tr("查看体育中心场馆入口、开放时间，以及各场馆的会员预约流程。")
        case .serviceHub: return L10n.tr("查看与跟进服务工单，提交校园服务请求并浏览知识库。")
        }
    }

    /// 已知前提（说明卡使用；都来自研究资料，未验证的部分不写成结论）。
    var prerequisites: [String] {
        switch self {
        case .portal:
            return [
                L10n.tr("需要能访问 students.gtiit.edu.cn 的校园网络或学校认可的访问方式。"),
                L10n.tr("登录由学校统一身份认证完成（可能跳转到 Office 365 页面）。"),
                L10n.tr("成绩页首次进入可能要求先同意 Code of Conduct；App 不会代替你同意。"),
            ]
        case .moodle:
            return [
                L10n.tr("需要能访问 moodle.gtiit.edu.cn。"),
                L10n.tr("登录方式为浏览器登录（学校配置了 Office 365 / SAML2 入口），App 不生成或接管移动令牌。"),
                L10n.tr("资料与作业附件通过系统下载与分享，不在 App 内建离线库。"),
            ]
        case .rooms:
            return [
                L10n.tr("需要能访问 roombooking.gtiit.edu.cn，并使用本站账号登录。"),
                L10n.tr("Booked 标准 API 在本校为关闭状态，App 不会预判可用性或冲突。"),
                L10n.tr("练习房的时间窗与配额以官方管理规定文件为准，文件未标注生效日期。"),
            ]
        case .serviceHub: return []
        case .sports:
            return [
                L10n.tr("需要能访问 gtiit.mike-x.com。"),
                L10n.tr("多数场馆要求会员邮箱登录后才能看到真实时段。"),
                L10n.tr("票券、取消与签到规则以各场馆页面为准，App 不代操作。"),
            ]
        }
    }

    /// 首次启动说明与站点页脚用的一句话边界。
    var oneLineBoundary: String {
        switch self {
        case .portal: return L10n.tr("成绩、考勤、培养计划等敏感页面只在本机浏览，App 不落库、不上传。")
        case .moodle: return L10n.tr("作业提交与测验作答请回到官方页面完成。")
        case .rooms: return L10n.tr("预约与取消均以官方页面结果为准。")
        case .sports: return L10n.tr("会员资格与票券规则以官方页面为准。")
        case .serviceHub: return L10n.tr("服务中心")
        }
    }

    /// 站内快捷入口默认落点。
    var defaultLandingTitle: String {
        switch self {
        case .portal: return L10n.tr("门户首页")
        case .moodle: return L10n.tr("我的课程")
        case .rooms: return L10n.tr("预约面板")
        case .sports: return L10n.tr("体育中心")
        case .serviceHub: return L10n.tr("服务中心")
        }
    }

    /// 由 URL 反查站点，用于跨站跳转路由。
    static func site(for url: URL) -> SiteID? {
        guard let host = url.host?.lowercased(), !host.isEmpty else { return nil }
        return allCases.first { site in
            site.aliases.contains { alias in
                host == alias || host.hasSuffix("." + alias)
            }
        }
    }
}