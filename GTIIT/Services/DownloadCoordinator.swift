import Foundation
import WebKit
import UIKit

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
    var destinationBookmark: Data? = nil
}

/// 文件保存到“文件 → 我的 iPhone → GTIIT → Downloads”。请求 URL、Cookie 与断点凭证不落盘。
@MainActor final class DownloadCoordinator: NSObject, ObservableObject, WKDownloadDelegate {
    @Published private(set) var items: [DownloadItem] = []
    @Published private(set) var presentedID: UUID?
    private var dismissTask: Task<Void, Never>?
    @Published private(set) var popupPresenters: Set<UUID> = []
    var presentsOnRoot: Bool { popupPresenters.isEmpty }
    func setPopupPresenter(_ id: UUID, visible: Bool) {
        if visible { popupPresenters.insert(id) } else { popupPresenters.remove(id) }
    }
    var onFinish: ((URL) -> Void)?
    var onFailure: ((Error) -> Void)?
    private var active: [ObjectIdentifier: (WKDownload, UUID)] = [:]
    private var finalizing: Set<UUID> = []
    private var observations: [UUID: NSKeyValueObservation] = [:]
    private var resumptions: [UUID: (Data, WeakWebView)] = [:]
    var presentController: ((UIViewController) -> Bool)?
    var onMessage: ((String) -> Void)?
    @Published var locationError: String?
    @Published private(set) var defaultFolderBookmark: Data?
    private let defaults: UserDefaults
    private let indexURL: URL
    private var folders: [Data: ScopedDownloadFolder] = [:]
    private lazy var previews = PDFPreviewCoordinator(center: self)
    private let directory: URL
    private var started = false
    private final class WeakWebView {
        weak var value: WKWebView?
        init(_ value: WKWebView) { self.value = value }
    }

    init(directory: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaultFolderBookmark = defaults.data(forKey: "downloads.folderBookmark")
        self.directory = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        indexURL = directory != nil ? self.directory.appendingPathComponent("index.json") :
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("GTIITDownloads/index.json")
        super.init()
        if directory == nil {
            let previous = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("GTIITDownloads", isDirectory: true)
            if FileManager.default.fileExists(atPath: previous.path),
                !FileManager.default.fileExists(atPath: self.directory.path) {
                try? FileManager.default.moveItem(at: previous, to: self.directory)
            }
        }
    }
    func start(retention: DownloadRetention) {
        guard !started else { return }
        started = true
        // 兼容旧版的临时分享目录。
        try? FileManager.default.removeItem(
            at: FileManager.default.temporaryDirectory.appendingPathComponent("GTIITDownloads"))
        let legacyIndex = directory.appendingPathComponent("index.json")
        if !FileManager.default.fileExists(atPath: indexURL.path),
            let legacy = try? Data(contentsOf: legacyIndex) {
            try? FileManager.default.createDirectory(at: indexURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? legacy.write(to: indexURL, options: [.atomic, .completeFileProtection])
        }
        if let data = try? Data(contentsOf: indexURL),
            let saved = try? JSONDecoder().decode([DownloadItem].self, from: data)
        {
            items = saved
        }
        for index in items.indices where items[index].state == .downloading {
            items[index].state = .failed
            items[index].error = L10n.tr("上次下载未完成，请重新打开来源站点")
        }
        let expired = items.filter {
            $0.destinationBookmark == nil && (retention == .session || Date().timeIntervalSince($0.createdAt) > retention.seconds)
        }.map(\.id)
        for id in expired { remove(id) }
        items.removeAll { $0.destinationBookmark == nil && $0.state == .completed && fileURL(for: $0) == nil }
        persist()
    }
    func track(_ download: WKDownload, webView: WKWebView, site: SiteID, resuming id: UUID? = nil) {
        let id = id ?? UUID()
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].state = .downloading
            items[index].error = nil
        } else {
            items.insert(
                DownloadItem(id: id, site: site, filename: L10n.tr("准备下载…"), createdAt: Date(), state: .downloading, destinationBookmark: defaultFolderBookmark),
                at: 0)
        }
        resumptions.removeValue(forKey: id)
        dismissTask?.cancel()
        presentedID = id
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
            items[index].error = L10n.format("无法创建下载文件（%@）", String(describing: (error as NSError).code))
            onFailure?(error)
            completionHandler(nil)
            persist()
        }
    }
    func downloadDidFinish(_ download: WKDownload) {
        guard let (_, id) = active.removeValue(forKey: ObjectIdentifier(download)),
            let item = items.first(where: { $0.id == id }) else { return }
        observations.removeValue(forKey: id)
        finalizing.insert(id)
        let local = localURL(for: item)
        Task {
            defer { finalizing.remove(id) }
            do {
                var filename = item.filename
                if let bookmark = item.destinationBookmark {
                    let folder = try folderURL(bookmark)
                    let saved = try await Task.detached { try DownloadFileAccess.copy(local, to: folder, filename: filename) }.value
                    guard let index = items.firstIndex(where: { $0.id == id && $0.state == .downloading }) else {
                        try? DownloadFileAccess.remove(saved.url); removePartialFile(id); return
                    }
                    filename = saved.filename
                    items[index].filename = filename
                }
                guard let index = items.firstIndex(where: { $0.id == id && $0.state == .downloading }) else { return }
                let bytes = Int64((try local.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                items[index].state = .completed; items[index].progress = 1; items[index].bytes = bytes
                if item.destinationBookmark != nil { removePartialFile(id) }
                if let url = fileURL(for: items[index]) { onFinish?(url) }
                scheduleDismiss(id, after: 4)
            } catch {
                if let index = items.firstIndex(where: { $0.id == id && $0.state == .downloading }) {
                    items[index].state = .failed
                    items[index].error = L10n.format("无法保存，请检查下载位置后重新下载。%@", String(describing: error.localizedDescription))
                }
                onFailure?(error); scheduleDismiss(id, after: 8)
            }
            persist()
        }
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let (_, id) = active.removeValue(forKey: ObjectIdentifier(download)),
            let index = items.firstIndex(where: { $0.id == id })
        else { return }
        observations.removeValue(forKey: id)
        items[index].state = .failed
        items[index].error = L10n.format("下载中断（%@:%@），请检查网络后重试", String(describing: (error as NSError).domain), String(describing: (error as NSError).code))
        if let data = resumeData, let webView = download.webView {
            resumptions[id] = (data, WeakWebView(webView))
        } else {
            removePartialFile(id)
        }
        onFailure?(error)
        scheduleDismiss(id, after: 8)
        persist()
    }
    func cancel(_ id: UUID) {
        guard let pair = active.first(where: { $0.value.1 == id }) else {
            if finalizing.contains(id), let index = items.firstIndex(where: { $0.id == id && $0.state == .downloading }) {
                items[index].state = .cancelled; items[index].error = nil
                scheduleDismiss(id, after: 4); persist()
            }
            return
        }
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
        scheduleDismiss(id, after: 4)
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
    private func localURL(for item: DownloadItem) -> URL {
        directory.appendingPathComponent(item.id.uuidString).appendingPathComponent(item.filename)
    }
    func folderURL(_ bookmark: Data) throws -> URL {
        if let folder = folders[bookmark] {
            return folder.url
        }
        let folder = try ScopedDownloadFolder(bookmark: bookmark)
        folders[bookmark] = folder
        return folder.url
    }
    func fileURL(for item: DownloadItem) -> URL? {
        if item.state == .completed, let bookmark = item.destinationBookmark {
            guard let folder = try? folderURL(bookmark) else { return nil }
            // 文件可能仅在云端占位；读取时由 File Coordinator 获取。
            return folder.appendingPathComponent(item.filename)
        }
        let url = localURL(for: item)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    var defaultLocationTitle: String {
        guard let bookmark = defaultFolderBookmark else { return L10n.tr("我的 iPhone · GTIIT / Downloads") }
        return (try? folderURL(bookmark).lastPathComponent) ?? L10n.tr("位置不可用，轻点重新选择")
    }
    func selectDefaultFolder(_ url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        _ = try folderURL(bookmark)
        defaultFolderBookmark = bookmark
        defaults.set(bookmark, forKey: "downloads.folderBookmark")
    }
    func resetDefaultFolder() {
        defaultFolderBookmark = nil; defaults.removeObject(forKey: "downloads.folderBookmark")
    }
    func reportError(_ message: String) { locationError = message; onMessage?(message) }
    func receiveForPreview(_ download: WKDownload, webView: WKWebView, site: SiteID) {
        previews.receive(download, webView: webView, site: site)
    }
    var activePreview: PDFPreviewSession? { previews.currentSession }
    func open(_ item: DownloadItem) { previews.open(item) }
    @discardableResult func savePreview(_ source: URL, filename: String, site: SiteID) async throws -> DownloadItem {
        let id = UUID()
        let bookmark = defaultFolderBookmark
        let target: URL
        if let bookmark { target = try folderURL(bookmark) }
        else { target = directory.appendingPathComponent(id.uuidString, isDirectory: true) }
        let safeName = Self.sanitize(filename)
        let saved = try await Task.detached { try DownloadFileAccess.copy(source, to: target, filename: safeName, createFolder: bookmark == nil) }.value
        let bytes = Int64((try? saved.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        let item = DownloadItem(id: id, site: site, filename: saved.filename, createdAt: Date(), state: .completed,
            progress: 1, bytes: bytes, destinationBookmark: bookmark)
        items.insert(item, at: 0); persist()
        return item
    }
    func removeFile(_ id: UUID) async {
        guard let item = items.first(where: { $0.id == id }) else { return }
        if item.destinationBookmark != nil, item.state == .completed {
            guard let url = fileURL(for: item) else { reportError(L10n.tr("下载位置不可用，无法删除文件。")); return }
            do { try await Task.detached { try DownloadFileAccess.remove(url) }.value }
            catch {
                let failure = error as NSError
                if failure.domain != NSCocoaErrorDomain || ![NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(failure.code) {
                    reportError(L10n.format("无法删除文件：%@", String(describing: error.localizedDescription))); return
                }
            }
        }
        remove(id)
    }
    var totalBytes: Int64 {
        items.reduce(0) { result, item in
            guard item.destinationBookmark == nil, let url = fileURL(for: item) else { return result }
            return result + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }
    func remove(_ id: UUID) {
        cancel(id)
        resumptions.removeValue(forKey: id)
        observations.removeValue(forKey: id)
        removePartialFile(id)
        items.removeAll { $0.id == id }
        if presentedID == id { dismissPresentation() }
        persist()
    }
    /// 收起提示与取消下载是两个不同操作，收起不会删除文件或中止传输。
    func dismissPresentation() {
        dismissTask?.cancel()
        dismissTask = nil
        presentedID = nil
    }
    func dismissCompletedPresentation() {
        guard let id = presentedID,
            let item = items.first(where: { $0.id == id }), item.state != .downloading else { return }
        dismissPresentation()
    }
    private func scheduleDismiss(_ id: UUID, after seconds: Double) {
        guard presentedID == id else { return }
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled, let self, self.presentedID == id else { return }
            self.presentedID = nil
            self.dismissTask = nil
        }
    }
    func invalidateSession(for site: SiteID) {
        previews.invalidate(site: site)
        let ids = Set(items.filter { $0.site == site }.map(\.id))
        if let id = presentedID, ids.contains(id) { dismissPresentation() }
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
    func clear() { for id in items.filter({ $0.destinationBookmark == nil }).map(\.id) { remove(id) } }
    private func removePartialFile(_ id: UUID) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(id.uuidString))
    }
    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: indexURL.deletingLastPathComponent(), withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete])
            try JSONEncoder().encode(items).write(
                to: indexURL,
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
