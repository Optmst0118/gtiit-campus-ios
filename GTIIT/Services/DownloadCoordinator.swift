import Foundation
import WebKit

struct DownloadItem: Identifiable, Codable {
    enum State: String, Codable { case downloading, completed, failed, cancelled }
    let id: UUID
    let site: SiteID
    var filename: String
    let createdAt: Date
    var state: State
    var progress: Double = 0
    var bytes: Int64 = 0
    var error: String?
}

/// 文件和元数据只保存在本机缓存。请求 URL、Cookie 与断点凭证不落盘。
@MainActor final class DownloadCoordinator: NSObject, ObservableObject, WKDownloadDelegate {
    @Published private(set) var items: [DownloadItem] = []
    var onFinish: ((URL) -> Void)?
    var onFailure: ((Error) -> Void)?
    private var active: [ObjectIdentifier: (WKDownload, UUID)] = [:]
    private var observations: [UUID: NSKeyValueObservation] = [:]
    private var resumptions: [UUID: (Data, WeakWebView)] = [:]
    private let directory: URL
    private var started = false
    private final class WeakWebView {
        weak var value: WKWebView?
        init(_ value: WKWebView) { self.value = value }
    }

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GTIITDownloads", isDirectory: true)
        super.init()
    }
    func start(retention: DownloadRetention) {
        guard !started else { return }
        started = true
        // 兼容旧版的临时分享目录。
        try? FileManager.default.removeItem(
            at: FileManager.default.temporaryDirectory.appendingPathComponent("GTIITDownloads"))
        if let data = try? Data(contentsOf: directory.appendingPathComponent("index.json")),
            let saved = try? JSONDecoder().decode([DownloadItem].self, from: data)
        {
            items = saved
        }
        for index in items.indices where items[index].state == .downloading {
            items[index].state = .failed
            items[index].error = "上次下载未完成，请重新打开来源站点"
        }
        let expired = items.filter {
            retention == .session || Date().timeIntervalSince($0.createdAt) > retention.seconds
        }.map(\.id)
        for id in expired { remove(id) }
        items.removeAll { $0.state == .completed && fileURL(for: $0) == nil }
        persist()
    }
    func track(_ download: WKDownload, webView: WKWebView, site: SiteID, resuming id: UUID? = nil) {
        let id = id ?? UUID()
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].state = .downloading
            items[index].error = nil
        } else {
            items.insert(
                DownloadItem(id: id, site: site, filename: "准备下载…", createdAt: Date(), state: .downloading),
                at: 0)
        }
        resumptions.removeValue(forKey: id)
        active[ObjectIdentifier(download)] = (download, id)
        download.delegate = self
        observations[id] = download.progress.observe(\.fractionCompleted, options: [.new]) {
            [weak self] progress, _ in
            let rawFraction = progress.fractionCompleted
            let fraction = rawFraction.isFinite ? min(max(rawFraction, 0), 1) : 0
            let count = progress.completedUnitCount
            Task { @MainActor in
                guard let self,
                    let index = self.items.firstIndex(where: { $0.id == id && $0.state == .downloading })
                else { return }
                self.items[index].progress = fraction
                self.items[index].bytes = count
            }
        }
        persist()
    }
    func download(
        _ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        guard let (_, id) = active[ObjectIdentifier(download)],
            let index = items.firstIndex(where: { $0.id == id })
        else {
            completionHandler(nil)
            return
        }
        let folder = directory.appendingPathComponent(id.uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: folder, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete])
            let name = Self.sanitize(suggestedFilename)
            items[index].filename = name
            persist()
            completionHandler(folder.appendingPathComponent(name))
        } catch {
            items[index].state = .failed
            items[index].error = "无法创建下载文件"
            onFailure?(error)
            completionHandler(nil)
            persist()
        }
    }
    func downloadDidFinish(_ download: WKDownload) {
        guard let (_, id) = active.removeValue(forKey: ObjectIdentifier(download)),
            let index = items.firstIndex(where: { $0.id == id })
        else { return }
        observations.removeValue(forKey: id)
        items[index].state = .completed
        items[index].progress = 1
        if let url = fileURL(for: items[index]) {
            items[index].bytes =
                (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            onFinish?(url)
        } else {
            items[index].state = .failed
            items[index].error = "下载文件已被系统清理"
        }
        persist()
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let (_, id) = active.removeValue(forKey: ObjectIdentifier(download)),
            let index = items.firstIndex(where: { $0.id == id })
        else { return }
        observations.removeValue(forKey: id)
        items[index].state = .failed
        items[index].error = "下载中断，请检查网络后重试"
        if let data = resumeData, let webView = download.webView {
            resumptions[id] = (data, WeakWebView(webView))
        } else {
            removePartialFile(id)
        }
        onFailure?(error)
        persist()
    }
    func cancel(_ id: UUID) {
        guard let pair = active.first(where: { $0.value.1 == id }) else { return }
        active.removeValue(forKey: pair.key)
        observations.removeValue(forKey: id)
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].state = .cancelled
            items[index].error = nil
        }
        pair.value.0.cancel { [weak self, weak webView = pair.value.0.webView] data in
            guard let self, self.items.contains(where: { $0.id == id }) else { return }
            if let data, let webView {
                self.resumptions[id] = (data, WeakWebView(webView))
            } else {
                self.removePartialFile(id)
            }
            self.persist()
        }
        persist()
    }
    func canRetry(_ id: UUID) -> Bool { resumptions[id]?.1.value != nil }
    func retry(_ id: UUID) {
        guard let (data, reference) = resumptions[id], let webView = reference.value,
            let item = items.first(where: { $0.id == id }), item.state != .downloading
        else { return }
        // 避免双击导致并发恢复同一个文件。
        if let index = items.firstIndex(where: { $0.id == id }) { items[index].state = .downloading }
        webView.resumeDownload(fromResumeData: data) { [weak self, weak webView] download in
            guard let self, let webView, self.items.contains(where: { $0.id == id }) else {
                download.cancel(nil)
                return
            }
            self.track(download, webView: webView, site: item.site, resuming: id)
        }
    }
    func fileURL(for item: DownloadItem) -> URL? {
        let url = directory.appendingPathComponent(item.id.uuidString).appendingPathComponent(item.filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    var totalBytes: Int64 {
        items.reduce(0) { result, item in
            guard let url = fileURL(for: item) else { return result }
            return result + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }
    func remove(_ id: UUID) {
        cancel(id)
        resumptions.removeValue(forKey: id)
        observations.removeValue(forKey: id)
        removePartialFile(id)
        items.removeAll { $0.id == id }
        persist()
    }
    func invalidateSession(for site: SiteID) {
        let ids = Set(items.filter { $0.site == site }.map(\.id))
        for pair in active.filter({ ids.contains($0.value.1) }) {
            pair.value.0.delegate = nil
            pair.value.0.cancel(nil)
            active.removeValue(forKey: pair.key)
            observations.removeValue(forKey: pair.value.1)
            if let index = items.firstIndex(where: { $0.id == pair.value.1 }) {
                items[index].state = .cancelled
            }
            removePartialFile(pair.value.1)
        }
        for id in ids { resumptions.removeValue(forKey: id) }
        persist()
    }
    func clear() { for id in items.map(\.id) { remove(id) } }
    private func removePartialFile(_ id: UUID) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(id.uuidString))
    }
    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete])
            try JSONEncoder().encode(items).write(
                to: directory.appendingPathComponent("index.json"),
                options: [.atomic, .completeFileProtection])
        } catch { /* 下载文件仍可分享；下次启动以缓存实际存在情况为准。 */  }
    }
    static func sanitize(_ name: String) -> String {
        let clean = String(name.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var filename = clean.isEmpty || clean == "." || clean == ".." ? "download" : clean
        while filename.utf8.count > 220 { filename.removeLast() }
        return filename
    }
}
