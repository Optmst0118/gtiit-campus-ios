import Foundation

enum CampusSummaryStatus {
    case notConnected, loading, refreshing, current, partial, stale, needsLogin, failed
    var title: String {
        switch self {
        case .notConnected: return L10n.tr("连接 Moodle 后查看近期作业")
        case .loading: return L10n.tr("正在更新…")
        case .refreshing: return L10n.tr("正在更新…")
        case .current: return L10n.tr("暂无近期事项")
        case .partial: return L10n.tr("部分更新")
        case .stale: return L10n.tr("显示上次更新内容")
        case .needsLogin: return L10n.tr("需要登录 Moodle")
        case .failed: return L10n.tr("更新未完成，点按重试")
        }
    }
}
