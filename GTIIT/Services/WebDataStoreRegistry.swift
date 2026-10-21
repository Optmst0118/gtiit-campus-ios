import Foundation
import WebKit

/// 每个站点一个独立的持久化网页数据容器（iOS 17+ 的
/// `WKWebsiteDataStore(forIdentifier:)`），这样四站会话互不干扰，
/// 重启 App 后仍保留各自的登录状态。
///
/// 研究结论（可行性分析 3.2）要求把「多站点持久会话」作为最低系统版本的决策依据，
/// 因此本工程把最低版本定为 iOS 17。
@MainActor
final class WebDataStoreRegistry {
    static let shared = WebDataStoreRegistry()

    private let defaults = UserDefaults.standard
    private var stores: [SiteID: WKWebsiteDataStore] = [:]

    private init() {}

    private func identifier(for site: SiteID) -> UUID {
        let key = "web.dataStore.identifier.\(site.rawValue)"
        if let raw = defaults.string(forKey: key), let uuid = UUID(uuidString: raw) {
            return uuid
        }
        let uuid = UUID()
        defaults.set(uuid.uuidString, forKey: key)
        return uuid
    }

    func store(for site: SiteID) -> WKWebsiteDataStore {
        if let existing = stores[site] { return existing }
        let store = WKWebsiteDataStore(forIdentifier: identifier(for: site))
        stores[site] = store
        return store
    }

    /// 清空该站点的 Cookie、缓存与本地存储，但保留数据容器标识。
    /// 调用后需要重新登录该站点。
    func clearData(for site: SiteID) async {
        let dataStore = store(for: site)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            dataStore.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: .distantPast
            ) {
                continuation.resume()
            }
        }
    }

    /// 该容器是否已经有数据（用是否存在存储文件粗判，仅用于「我的」页状态展示）。
    func hasStoredData(for site: SiteID) async -> Bool {
        let dataStore = store(for: site)
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                continuation.resume(returning: !records.isEmpty)
            }
        }
    }
}