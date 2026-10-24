import Combine
import PDFKit
import QuickLook
import SwiftUI
import WebKit

@MainActor final class PDFPreviewSession: ObservableObject, Identifiable {
    enum State: Equatable { case loading, readable, saving, saved, failed }
    let id = UUID()
    let site: SiteID
    @Published var filename = L10n.tr("PDF 预览")
    @Published var state: State = .loading
    @Published var progress: Double = 0
    @Published var error: String?
    @Published var document: PDFDocument?
    var url: URL?
    var savedURL: URL?
    var temporaryFolder: URL?
    var saveAction: (() -> Void)?
    var closeAction: (() -> Void)?
    var canSave: Bool { state == .readable && saveAction != nil }
    init(site: SiteID) { self.site = site }
    func read(_ url: URL, alreadySaved: Bool = false) {
        guard let document = PDFDocument(url: url), document.pageCount > 0, !document.isLocked else {
            error = L10n.tr("无法读取此 PDF。文件可能不完整、需要密码，或服务器返回了登录页面。")
            state = .failed
            return
        }
        self.url = url
        self.document = document
        state = alreadySaved ? .saved : .readable
    }
}

/// 独立于会自动消失的浮窗；原 WebKit 响应仅接收一次。
@MainActor final class PDFPreviewCoordinator: NSObject, WKDownloadDelegate {
    weak var center: DownloadCoordinator?
    private var pending: [ObjectIdentifier: (WKDownload, SiteID, WKWebView)] = [:]
    private var sessions: [ObjectIdentifier: PDFPreviewSession] = [:]
    private var observations: [ObjectIdentifier: NSKeyValueObservation] = [:]
    private var openingFile = false
    private var controllers: [UUID: UIViewController] = [:]
    private var visibleSessions: [UUID: PDFPreviewSession] = [:]
    var currentSession: PDFPreviewSession? { visibleSessions.values.first }
    let temporaryRoot: URL
    init(center: DownloadCoordinator) {
        self.center = center
        temporaryRoot = FileManager.default.temporaryDirectory.appendingPathComponent("GTIITPDFPreviews", isDirectory: true)
        super.init()
        // 新进程不会复用此前未保存的预览。
        try? FileManager.default.removeItem(at: temporaryRoot)
    }
    func receive(_ download: WKDownload, webView: WKWebView, site: SiteID) {
        pending[ObjectIdentifier(download)] = (download, site, webView)
        download.delegate = self
    }
    static func isPDF(_ response: URLResponse, filename: String) -> Bool {
        response.mimeType?.lowercased() == "application/pdf" || URL(fileURLWithPath: filename).pathExtension.lowercased() == "pdf"
    }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let key = ObjectIdentifier(download)
        guard let (_, site, webView) = pending.removeValue(forKey: key), let center else { completionHandler(nil); return }
        guard Self.isPDF(response, filename: suggestedFilename) else {
            center.track(download, webView: webView, site: site)
            center.download(download, decideDestinationUsing: response, suggestedFilename: suggestedFilename, completionHandler: completionHandler)
            return
        }
        let session = PDFPreviewSession(site: site)
        var name = DownloadCoordinator.sanitize(suggestedFilename)
        if URL(fileURLWithPath: name).pathExtension.lowercased() != "pdf" { name += ".pdf" }
        session.filename = name
        let folder = temporaryRoot.appendingPathComponent(session.id.uuidString, isDirectory: true)
        session.temporaryFolder = folder
        session.url = folder.appendingPathComponent(name)
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]) }
        catch { completionHandler(nil); return }
        sessions[key] = session
        observations[key] = download.progress.observe(\.fractionCompleted, options: [.new]) { [weak session] progress, _ in
            let fraction = progress.fractionCompleted
            Task { @MainActor in session?.progress = fraction.isFinite ? min(1, max(0, fraction)) : 0 }
        }
        session.saveAction = { [weak self, weak session] in
            guard let self, let session, session.canSave, let source = session.url, let center = self.center else { return }
            session.state = .saving
            session.error = nil
            Task {
                do {
                    let item = try await center.savePreview(source, filename: session.filename, site: session.site)
                    session.savedURL = center.fileURL(for: item)
                    session.state = .saved
                } catch {
                    session.state = .readable
                    session.error = L10n.format("未能保存，请检查下载位置后重试。%@", String(describing: error.localizedDescription))
                }
            }
        }
        // 新窗口下载可能在其呈现动画完成前响应；等待当前宿主稳定，不丢掉原响应。
        pending[key] = (download, site, webView)
        Task {
            let deadline = Date().addingTimeInterval(2)
            while sessions[key] === session {
                if show(session) { completionHandler(session.url); return }
                if Date() >= deadline { break }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            cleanup(session)
            completionHandler(nil)
        }
    }
    func downloadDidFinish(_ download: WKDownload) {
        let key = ObjectIdentifier(download)
        pending.removeValue(forKey: key); observations.removeValue(forKey: key)
        guard let session = sessions.removeValue(forKey: key), let url = session.url else { return }
        session.read(url)
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let key = ObjectIdentifier(download)
        pending.removeValue(forKey: key); observations.removeValue(forKey: key)
        guard let session = sessions.removeValue(forKey: key) else { return }
        session.error = L10n.format("PDF 加载失败，请返回课程后重新打开。%@", String(describing: error.localizedDescription))
        session.state = .failed
    }
    @discardableResult func show(_ session: PDFPreviewSession) -> Bool {
        let controller = UIHostingController(rootView: DocumentPreviewView(session: session))
        controller.modalPresentationStyle = .fullScreen
        session.closeAction = { [weak self, weak session, weak controller] in
            guard let self, let session, session.state != .saving else { return }
            controller?.dismiss(animated: true) { self.cleanup(session) }
        }
        guard center?.presentController?(controller) == true else { return false }
        visibleSessions[session.id] = session
        controllers[session.id] = controller
        return true
    }
    private func showWhenReady(_ session: PDFPreviewSession) async -> Bool {
        let deadline = Date().addingTimeInterval(2)
        repeat {
            if show(session) { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        } while !Task.isCancelled && Date() < deadline
        return false
    }
    func open(_ item: DownloadItem) {
        guard !openingFile else { return }
        guard let center, let url = center.fileURL(for: item) else { center?.reportError(L10n.tr("文件不存在或下载位置已失效，请重新选择位置。")); return }
        openingFile = true
        center.dismissPresentation()
        let folder = temporaryRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        // File Provider 协调读会等待云端文件就绪，不在主线程阻塞。
        Task {
            defer { openingFile = false }
            do {
                let copy = try await Task.detached { try DownloadFileAccess.readableCopy(url, to: folder) }.value
                if copy.pathExtension.lowercased() == "pdf" {
                    let session = PDFPreviewSession(site: item.site)
                    session.filename = item.filename; session.temporaryFolder = folder; session.savedURL = url
                    session.read(copy, alreadySaved: true)
                    if !(await showWhenReady(session)) {
                        try? FileManager.default.removeItem(at: folder)
                        center.reportError(L10n.tr("预览窗口暂时无法打开，请稍后重试。"))
                    }
                } else {
                    let preview = StableQuickLookController(url: copy, folder: folder)
                    let deadline = Date().addingTimeInterval(2)
                    var shown = false
                    repeat {
                        if center.presentController?(preview) == true { shown = true; break }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    } while !Task.isCancelled && Date() < deadline
                    if !shown {
                        try? FileManager.default.removeItem(at: folder)
                        center.reportError(L10n.tr("预览窗口暂时无法打开，请稍后重试。"))
                    }
                }
            } catch {
                try? FileManager.default.removeItem(at: folder)
                center.reportError(L10n.format("无法打开文件：%@", String(describing: error.localizedDescription)))
            }
        }
    }
    func invalidate(site: SiteID) {
        for session in Array(visibleSessions.values) where session.site == site && session.state != .saved {
            controllers[session.id]?.dismiss(animated: false)
            cleanup(session)
        }
        for (key, entry) in pending where entry.1 == site {
            entry.0.delegate = nil; entry.0.cancel(nil)
            pending.removeValue(forKey: key); sessions.removeValue(forKey: key); observations.removeValue(forKey: key)
        }
    }
    private func cleanup(_ session: PDFPreviewSession) {
        for (key, value) in sessions where value === session {
            pending[key]?.0.delegate = nil; pending[key]?.0.cancel(nil)
            pending.removeValue(forKey: key); observations.removeValue(forKey: key); sessions.removeValue(forKey: key)
        }
        session.document = nil
        if let folder = session.temporaryFolder { try? FileManager.default.removeItem(at: folder) }
        session.saveAction = nil; session.closeAction = nil
        visibleSessions.removeValue(forKey: session.id); controllers.removeValue(forKey: session.id)
    }
}

@MainActor private final class StableQuickLookController: QLPreviewController, QLPreviewControllerDataSource {
    let url: URL
    let folder: URL
    init(url: URL, folder: URL) { self.url = url; self.folder = folder; super.init(nibName: nil, bundle: nil); dataSource = self }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    deinit { try? FileManager.default.removeItem(at: folder) }
}
