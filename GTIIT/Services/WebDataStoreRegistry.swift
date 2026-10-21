import Foundation
import WebKit

struct SiteStorageSummary {
    var records = 0
    var cookies = 0
    var types: [String] = []
    var hasData: Bool { records > 0 || cookies > 0 }
}
@MainActor final class WebDataStoreRegistry {
    static let shared = WebDataStoreRegistry()
    private let defaults = UserDefaults.standard
    private var stores: [SiteID: WKWebsiteDataStore] = [:]
    private init() {}
    private func identifier(for site: SiteID) -> UUID {
        let key = "web.dataStore.identifier.\(site.rawValue)"
        if let raw = defaults.string(forKey: key), let uuid = UUID(uuidString: raw) { return uuid }
        let uuid = UUID()
        defaults.set(uuid.uuidString, forKey: key)
        return uuid
    }
    func store(for site: SiteID) -> WKWebsiteDataStore {
        if let existing = stores[site] { return existing }
        let value = WKWebsiteDataStore(forIdentifier: identifier(for: site))
        stores[site] = value
        return value
    }
    static let cacheTypes: Set<String> = [
        WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeOfflineWebApplicationCache,
    ]
    func clearData(for site: SiteID, cacheOnly: Bool = false) async {
        let dataStore = store(for: site)
        let types = cacheOnly ? Self.cacheTypes : WKWebsiteDataStore.allWebsiteDataTypes()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            dataStore.removeData(ofTypes: types, modifiedSince: .distantPast) { continuation.resume() }
        }
        // 按来源再清理残留索引；部分 WebKit 版本在按时间删除后仍返回 DiskCache 记录。
        let records: [WKWebsiteDataRecord] = await withCheckedContinuation { continuation in
            dataStore.fetchDataRecords(ofTypes: types) { continuation.resume(returning: $0) }
        }
        if !records.isEmpty {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                dataStore.removeData(ofTypes: types, for: records) { continuation.resume() }
            }
        }
    }
    private let retiredKey = "web.dataStore.retiredIdentifiers"
    var pendingCleanupCount: Int { defaults.stringArray(forKey: retiredKey)?.count ?? 0 }
    /// 切到全新容器，使延迟写入旧缓存的网络进程无法污染清理后的会话。
    func resetStore(for site: SiteID) async {
        let old = identifier(for: site)
        await clearData(for: site)
        stores.removeValue(forKey: site)
        defaults.set(UUID().uuidString, forKey: "web.dataStore.identifier.\(site.rawValue)")
        var retired = defaults.stringArray(forKey: retiredKey) ?? []
        if !retired.contains(old.uuidString) { retired.append(old.uuidString) }
        defaults.set(retired, forKey: retiredKey)
        await cleanupRetiredStores()
    }
    func cleanupRetiredStores() async {
        let active = Set(SiteID.allCases.map { identifier(for: $0).uuidString })
        var removedIDs: Set<String> = []
        for raw in defaults.stringArray(forKey: retiredKey) ?? [] {
            guard !active.contains(raw), let id = UUID(uuidString: raw) else { continue }
            let removed: Bool = await withCheckedContinuation { continuation in
                WKWebsiteDataStore.remove(forIdentifier: id) { error in
                    continuation.resume(returning: error == nil)
                }
            }
            if removed { removedIDs.insert(raw) }
        }
        // await 期间可能新增旧容器；只移除已成功处理的条目，保留并发追加的数据。
        let current = defaults.stringArray(forKey: retiredKey) ?? []
        defaults.set(current.filter { !removedIDs.contains($0) }, forKey: retiredKey)
    }
    func summary(for site: SiteID) async -> SiteStorageSummary {
        let store = store(for: site)
        let records: [WKWebsiteDataRecord] = await withCheckedContinuation { continuation in
            store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) {
                continuation.resume(returning: $0)
            }
        }
        let cookies: [HTTPCookie] = await withCheckedContinuation { continuation in
            store.httpCookieStore.getAllCookies { continuation.resume(returning: $0) }
        }
        return SiteStorageSummary(
            records: records.count, cookies: cookies.count,
            types: Array(Set(records.flatMap { $0.dataTypes })).sorted())
    }
    func hasStoredData(for site: SiteID) async -> Bool { await summary(for: site).hasData }
}
