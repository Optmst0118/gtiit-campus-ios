import PDFKit
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
    @State private var pendingDelete: UUID?
    @State private var chooseFolder = false
    private var sortedItems: [DownloadItem] {
        (DownloadSort(rawValue: sortRaw) ?? .time).ordered(center.items, ascending: ascending)
    }

    var body: some View {
        let _ = nativeLocale.identifier

        List {
            Section {
                Button { chooseFolder = true } label: { locationRow }
                    .buttonStyle(.plain)
                    .accessibilityHint(L10n.tr("选择之后新下载文件的默认文件夹"))
            }

            Section {
                if center.items.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.tr("暂无下载"), systemImage: "arrow.down.circle")
                    } description: {
                        Text(L10n.tr("保存的文件会显示在这里。"))
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if grid {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 105, maximum: 160), spacing: 20)],
                        spacing: 24
                    ) {
                        ForEach(sortedItems) { item in fileCell(item) }
                    }
                    .padding(.vertical, 14)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                } else {
                    ForEach(sortedItems) { item in
                        fileRow(item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDelete = item.id
                                } label: {
                                    Label(L10n.tr("删除"), systemImage: "trash")
                                }
                            }
                    }
                }
            } header: {
                Text(center.items.isEmpty ? L10n.tr("文件") : L10n.format("文件 · %@", String(describing: center.items.count)))
            } footer: {
                if !center.items.isEmpty {
                    Text(grid ? L10n.tr("点按文件可预览或继续操作。") : L10n.tr("左滑文件可以删除；删除只影响本机文件与这条记录。"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.pageBackground)
        .navigationTitle(L10n.tr("下载管理"))
        .navigationBarTitleDisplayMode(.inline)
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
        .confirmationDialog(
            L10n.tr("删除此下载文件？"),
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L10n.tr("删除文件"), role: .destructive) {
                if let id = pendingDelete { Task { await center.removeFile(id) } }
                pendingDelete = nil
            }
            Button(L10n.tr("取消"), role: .cancel) { pendingDelete = nil }
        } message: { Text(L10n.tr("仅删除这条记录对应的文件，其他文件及另存副本不受影响。")) }
        .alert(L10n.tr("文件操作未完成"), isPresented: Binding(get: { center.locationError != nil }, set: { if !$0 { center.locationError = nil } })) {
            Button(L10n.tr("好")) { center.locationError = nil }
        } message: { Text(center.locationError ?? "") }
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
        .contextMenu { contextMenu(for: item) }
    }

    private func fileCell(_ item: DownloadItem) -> some View {
        Button { activate(item) } label: {
            VStack(spacing: 10) {
                DownloadThumbnail(url: item.state == .completed ? center.fileURL(for: item) : nil)
                    .frame(width: 72, height: 88)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 4))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(uiColor: .separator).opacity(0.4), lineWidth: 0.5))
                Text(item.filename).font(.caption).lineLimit(2).multilineTextAlignment(.center)
                if item.state == .downloading { ProgressView(value: item.progress).frame(width: 72) }
                else if item.state != .completed { Image(systemName: "exclamationmark.circle").foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.filename)
        .accessibilityValue(detail(item))
        .contextMenu { contextMenu(for: item) }
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
        Button(L10n.tr("删除"), systemImage: "trash", role: .destructive) { pendingDelete = item.id }
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
            let date = item.createdAt.formatted(date: .abbreviated, time: .shortened)
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
