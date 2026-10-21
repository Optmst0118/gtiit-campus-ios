import Foundation
import WebKit

/// 把网页里的文件下载落到 App 临时目录，完成后交给系统分享面板。
/// 研究结论：Moodle 的 pluginfile.php 资源与作业附件都属于下载型导航，
/// 首版只做「下载 + 系统分享」，不做离线库或自动上传。
@MainActor
final class DownloadCoordinator: NSObject, WKDownloadDelegate {
    var onFinish: ((URL) -> Void)?
    var onFailure: ((Error) -> Void)?

    private var destinations: [ObjectIdentifier: URL] = [:]

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GTIITDownloads", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            onFailure?(error)
            completionHandler(nil)
            return
        }

        let filename = Self.sanitize(suggestedFilename)
        var destination = directory.appendingPathComponent(filename)
        let base = destination.deletingPathExtension().lastPathComponent
        let ext = destination.pathExtension
        var index = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            let name = ext.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(ext)"
            destination = directory.appendingPathComponent(name)
            index += 1
        }

        destinations[ObjectIdentifier(download)] = destination
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        let key = ObjectIdentifier(download)
        if let url = destinations[key] {
            onFinish?(url)
        }
        destinations.removeValue(forKey: key)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        destinations.removeValue(forKey: ObjectIdentifier(download))
        onFailure?(error)
    }

    private static func sanitize(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "download" : cleaned
    }
}
