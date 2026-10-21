import Foundation

/// 用户授权的文件夹；作用域与持有对象生命周期一致。
final class ScopedDownloadFolder {
    let url: URL
    private let scoped: Bool
    init(bookmark: Data) throws {
        var stale = false
        url = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        scoped = url.startAccessingSecurityScopedResource()
        guard FileManager.default.fileExists(atPath: url.path) else {
            if scoped { url.stopAccessingSecurityScopedResource() }
            throw CocoaError(.fileNoSuchFile)
        }
    }
    deinit { if scoped { url.stopAccessingSecurityScopedResource() } }
}

struct SavedDownloadFile {
    let url: URL
    let filename: String
}

enum DownloadFileAccess {
    static func copy(_ source: URL, to folder: URL, filename: String, createFolder: Bool = false) throws -> SavedDownloadFile {
        var result: Result<SavedDownloadFile, Error>?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: folder, options: [], error: &coordinationError) { directory in
            result = Result {
                let manager = FileManager.default
                if createFolder { try manager.createDirectory(at: directory, withIntermediateDirectories: true) }
                guard manager.fileExists(atPath: directory.path) else { throw CocoaError(.fileNoSuchFile) }
                let original = URL(fileURLWithPath: filename)
                let stem = original.deletingPathExtension().lastPathComponent
                let suffix = original.pathExtension
                var candidate = directory.appendingPathComponent(filename)
                var number = 2
                while manager.fileExists(atPath: candidate.path) {
                    candidate = directory.appendingPathComponent(stem + " (\(number))" + (suffix.isEmpty ? "" : "." + suffix))
                    number += 1
                }
                // 只清理本次操作自己创建的临时文件，避免竞争失败时删除他人的同名文件。
                let staging = directory.appendingPathComponent(".GTIIT-" + UUID().uuidString + ".part")
                defer { try? manager.removeItem(at: staging) }
                try manager.copyItem(at: source, to: staging)
                try manager.moveItem(at: staging, to: candidate)
                return SavedDownloadFile(url: candidate, filename: candidate.lastPathComponent)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileWriteUnknown) }
        return try result.get()
    }
    static func remove(_ url: URL) throws {
        var operationError: Error?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) { target in
            do { try FileManager.default.removeItem(at: target) } catch { operationError = error }
        }
        if let error = coordinationError ?? operationError as NSError? { throw error }
    }
    static func readableCopy(_ url: URL, to folder: URL) throws -> URL {
        var result: Result<URL, Error>?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { target in
            result = Result {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let copy = folder.appendingPathComponent(target.lastPathComponent)
                try FileManager.default.copyItem(at: target, to: copy)
                return copy
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }
}

enum DownloadSort: String, CaseIterable, Identifiable {
    case name, size, time
    var id: String { rawValue }
    var title: String { switch self { case .name: return "名称"; case .size: return "大小"; case .time: return "时间" } }
    func ordered(_ items: [DownloadItem], ascending: Bool) -> [DownloadItem] {
        items.sorted { a, b in
            let comparison: ComparisonResult
            switch self {
            case .name: comparison = a.filename.localizedStandardCompare(b.filename)
            case .size: comparison = a.bytes == b.bytes ? .orderedSame : a.bytes < b.bytes ? .orderedAscending : .orderedDescending
            case .time: comparison = a.createdAt.compare(b.createdAt)
            }
            if comparison == .orderedSame { return a.id.uuidString < b.id.uuidString }
            return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
    }
}
