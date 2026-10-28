import PDFKit
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct DownloadsView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var center: DownloadCoordinator
    @AppStorage("downloads.grid") private var grid = false
    @AppStorage("downloads.sort") private var sortRaw = DownloadSort.time.rawValue
    @AppStorage("downloads.ascending") private var ascending = false
    @State private var chooseFolder = false
    private var sortedItems: [DownloadItem] {
        (DownloadSort(rawValue: sortRaw) ?? .time).ordered(center.items, ascending: ascending)
    }

    var body: some View {
        let _ = nativeLocale.identifier

        VStack(alignment: .leading, spacing: 16) {
            Button { chooseFolder = true } label: { locationRow }
                .buttonStyle(.plain)
                .font(.body)
                .padding(16)
                .cardBackground()
                .accessibilityHint(L10n.tr("选择之后新下载文件的默认文件夹"))
            Text(L10n.format("文件 · %@", String(center.items.count)))
                .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4)
            ZStack {
                if center.items.isEmpty {
                    ContentUnavailableView(L10n.tr("暂无下载"), systemImage: "arrow.down.circle")
                } else if grid {
                    DownloadFileGrid(items: sortedItems, center: center,
                        activate: activate, delete: delete,
                        share: { url in app.browserPresentShare(items: [url]) },
                        openSource: { app.openSite($0.site) })
                } else { listContent }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)
        .nativeDetailSurface(title: L10n.tr("下载管理"))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { grid.toggle() } label: {
                    Image(systemName: grid ? "list.bullet" : "square.grid.2x2")
                }.accessibilityLabel(grid ? L10n.tr("切换列表视图") : L10n.tr("切换网格视图"))
                Menu {
                    Picker(L10n.tr("排序方式"), selection: $sortRaw) {
                        ForEach(DownloadSort.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    Picker(L10n.tr("顺序"), selection: $ascending) {
                        Text(L10n.tr("升序")).tag(true); Text(L10n.tr("降序")).tag(false)
                    }
                    Divider()
                    Picker(L10n.tr("文件保留（仅本机）"), selection: $settings.downloadRetention) {
                        ForEach(DownloadRetention.allCases) { Text($0.title).tag($0) }
                    }
                    Button(L10n.tr("更改下载位置"), systemImage: "folder") { chooseFolder = true }
                    if center.defaultFolderBookmark != nil {
                        Button(L10n.tr("恢复默认 Downloads 位置")) { center.resetDefaultFolder() }
                    }
                } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel(L10n.tr("排序与下载选项"))
            }
        }
        .sheet(isPresented: $chooseFolder) {
            DownloadFolderPicker { url in
                do { try center.selectDefaultFolder(url) }
                catch { center.reportError(L10n.format("无法使用此文件夹，请重新选择。%@", String(describing: error.localizedDescription))) }
            }
        }
        .alert(L10n.tr("文件操作未完成"), isPresented: Binding(get: { center.locationError != nil }, set: { if !$0 { center.locationError = nil } })) {
            Button(L10n.tr("好")) { center.locationError = nil }
        } message: { Text(center.locationError ?? "") }
    }

    private var listContent: some View {
        List {
            ForEach(sortedItems) { item in
                fileRow(item)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { delete(item) } label: {
                            Label(L10n.tr("删除"), systemImage: "trash")
                        }.tint(Color(uiColor: .systemRed))
                    }
            }
        }.listStyle(.plain).scrollContentBackground(.hidden)
    }

    private var locationRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("下载位置"))
                    .foregroundStyle(.primary)
                Text(center.defaultLocationTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    private func fileRow(_ item: DownloadItem) -> some View {
        Button { activate(item) } label: {
            HStack(spacing: 12) {
                Image(systemName: rowSymbol(item))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.filename)
                        .font(.body)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Text(detail(item))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if item.state == .downloading {
                    ProgressView(value: item.progress)
                        .frame(width: 44)
                } else if item.state == .failed || item.state == .cancelled {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.filename)
        .accessibilityValue(detail(item))
        .contextMenu { contextMenu(for: item) } preview: {
            if item.state == .completed, let url = center.fileURL(for: item) {
                DownloadContextPreview(source: url, filename: item.filename)
                    .onAppear { app.showContextMenu("download." + item.id.uuidString) }
                    .onDisappear { app.hideContextMenu("download." + item.id.uuidString) }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for item: DownloadItem) -> some View {
        if item.state == .completed {
            Button(L10n.tr("预览"), systemImage: "doc.text.magnifyingglass") { center.open(item) }
            if let url = center.fileURL(for: item) {
                ShareLink(item: url) { Label(L10n.tr("分享"), systemImage: "square.and.arrow.up") }
            }
        } else if item.state == .downloading {
            Button(L10n.tr("取消下载"), systemImage: "xmark.circle") { center.cancel(item.id) }
        } else if center.canRetry(item.id) {
            Button(L10n.tr("继续下载"), systemImage: "arrow.clockwise") { center.retry(item.id) }
        } else {
            Button(L10n.tr("打开来源站点"), systemImage: "safari") { app.openSite(item.site) }
        }
        Button(L10n.tr("删除"), systemImage: "trash", role: .destructive) { delete(item) }
    }

    private func delete(_ item: DownloadItem) {
        Task { await center.removeFile(item.id) }
    }

    private func activate(_ item: DownloadItem) {
        if item.state == .completed { center.open(item) }
        else if center.canRetry(item.id) { center.retry(item.id) }
        else if item.state != .downloading { app.openSite(item.site) }
    }

    private func rowSymbol(_ item: DownloadItem) -> String {
        switch item.state {
        case .downloading: return "arrow.down.doc"
        case .failed, .cancelled: return "exclamationmark.triangle"
        case .completed: return "doc.text"
        }
    }

    private func detail(_ item: DownloadItem) -> String {
        switch item.state {
        case .completed:
            let size = ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file)
            let date = item.createdAt.gtiitFormatted()
            return "\(item.site.shortName) · \(size) · \(date)"
        case .downloading:
            return L10n.format("下载中 %@%", String(describing: Int((item.progress * 100).rounded())))
        case .failed:
            return L10n.tr("下载失败")
        case .cancelled:
            return L10n.tr("已取消")
        }
    }
}

private struct DownloadThumbnail: View {
    @Environment(\.locale) private var nativeLocale
    let url: URL?
    @State private var image: UIImage?
    var body: some View {
        let _ = nativeLocale.identifier

        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { Image(systemName: "doc.fill").resizable().scaledToFit().foregroundStyle(Theme.accent.opacity(0.7)).padding(10) }
        }
        .task(id: url) {
            image = nil
            guard let url, url.pathExtension.lowercased() == "pdf" else { return }
            let data = await Task.detached(priority: .utility) {
                var data: Data?
                var error: NSError?
                NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { file in
                    data = PDFDocument(url: file)?.page(at: 0)?.thumbnail(of: CGSize(width: 144, height: 176), for: .cropBox).pngData()
                }
                return data
            }.value
            guard !Task.isCancelled else { return }
            image = data.flatMap(UIImage.init(data:))
        }
    }
}

private struct DownloadFolderPicker: UIViewControllerRepresentable {
    let picked: (URL) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(picked: picked) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false; picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let picked: (URL) -> Void
        init(picked: @escaping (URL) -> Void) { self.picked = picked }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { picked(url) }
        }
    }
}

/// Context-menu previews use an independent coordinated copy. Their lifetime is
/// owned by the system preview, and cannot dismiss the normal document viewer.
struct DownloadContextPreview: View {
    let source: URL
    let filename: String
    @StateObject private var asset = DownloadPeekAsset()
    var body: some View {
        Group {
            if let document = asset.document { DownloadPeekPDF(document: document) }
            else if asset.url != nil { DownloadPeekController(asset: asset) }
            else {
                VStack(spacing: 16) {
                    if asset.failed { Image(systemName: "doc.text.magnifyingglass").font(.largeTitle) }
                    else { ProgressView() }
                    Text(filename).font(.headline).multilineTextAlignment(.center).lineLimit(3)
                    if asset.failed { Text(L10n.tr("轻点文件可重新尝试预览")).font(.caption).foregroundStyle(.secondary) }
                }.padding(24)
            }
        }
        .frame(width: 300, height: 420)
        .background(Theme.cardBackground)
        .task(id: source) { await asset.load(source) }
    }
}
@MainActor private final class DownloadPeekAsset: ObservableObject {
    @Published private(set) var url: URL?
    @Published private(set) var failed = false
    @Published private(set) var document: PDFDocument?
    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent("file-peek-" + UUID().uuidString)
    func load(_ source: URL) async {
        guard url == nil else { return }
        do {
            let folder = folder
            let copy = try await Task.detached(priority: .userInitiated) { try DownloadFileAccess.readableCopy(source, to: folder) }.value
            guard !Task.isCancelled else { try? FileManager.default.removeItem(at: folder); return }
            if copy.pathExtension.lowercased() == "pdf" { document = PDFDocument(url: copy) }
            url = copy
        } catch { failed = true }
    }
    deinit { try? FileManager.default.removeItem(at: folder) }
}
/// PDFKit avoids waiting for Quick Look's remote helper to cold-start before
/// a PDF can be read in a context menu. Other document types retain Quick Look.
private struct DownloadPeekPDF: UIViewRepresentable {
    let document: PDFDocument
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePageContinuous; view.autoScales = true
        view.displaysPageBreaks = false; view.backgroundColor = .clear
        view.document = document
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document }
    }
}
private struct DownloadPeekController: UIViewControllerRepresentable {
    let asset: DownloadPeekAsset
    func makeCoordinator() -> Coordinator { Coordinator(asset: asset) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let asset: DownloadPeekAsset
        init(asset: DownloadPeekAsset) { self.asset = asset }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { asset.url == nil ? 0 : 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            asset.url! as NSURL
        }
    }
}
