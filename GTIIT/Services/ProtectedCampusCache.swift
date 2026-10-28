import Foundation

/// Common disk mechanics only. Each store still owns its schema, validation,
/// freshness and explicit-clear policy; existing paths remain unchanged.
enum ProtectedCampusCache {
    static func read<Value: Decodable>(_ type: Value.Type, from url: URL, maxBytes: Int) -> Value? {
        guard maxBytes > 0,
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size < maxBytes,
              let data = try? Data(contentsOf: url), data.count < maxBytes else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func write<Value: Encodable>(_ value: Value, to url: URL) throws {
        // Encode before changing anything on disk. Atomic writes preserve the
        // previous valid snapshot if encoding or replacing the file fails.
        let data = try JSONEncoder().encode(value)
        var folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}
