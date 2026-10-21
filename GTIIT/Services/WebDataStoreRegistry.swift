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
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store(for: site).removeData(
                ofTypes: cacheOnly ? Self.cacheTypes : WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: .distantPast
            ) { continuation.resume() }
        }
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
