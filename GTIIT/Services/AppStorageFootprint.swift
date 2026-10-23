import Foundation

/// Total on-disk footprint of the app bundle plus its sandbox container.
enum AppStorageFootprint {
    static func totalBytes() -> Int64 {
        let manager = FileManager.default
        let roots = [
            Bundle.main.bundleURL,
            URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        ]
        var total: Int64 = 0
        for root in roots {
            guard let enumerator = manager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else { continue }
            for case let url as URL in enumerator {
                guard let values = try? url.resourceValues(
                    forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]),
                    values.isRegularFile == true else { continue }
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
        }
        return total
    }

    static func formattedTotal() -> String {
        ByteCountFormatter.string(fromByteCount: totalBytes(), countStyle: .file)
    }
}
