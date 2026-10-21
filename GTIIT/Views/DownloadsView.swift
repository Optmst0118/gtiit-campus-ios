import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct DownloadsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var center: DownloadCoordinator
    @AppStorage("downloads.grid") private var grid = false
    @AppStorage("downloads.sort") private var sortRaw = DownloadSort.time.rawValue
    @AppStorage("downloads.ascending") private var ascending = false
    @State private var pendingDelete: UUID?
    @State private var chooseFolder = false
    private var sortedItems: [DownloadItem] { (DownloadSort(rawValue: sortRaw) ?? .time).ordered(center.items, ascending: ascending) }

    var body: some View {
        VStack(spacing: 0) {
            Button { chooseFolder = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "folder").foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("下载位置").font(.subheadline)
                        Text(center.defaultLocationTitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }.padding(.horizontal, 20).padding(.vertical, 10).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityHint("选择之后新下载文件的默认文件夹")
            Divider()
            if center.items.isEmpty {
                ContentUnavailableView("暂无下载", systemImage: "arrow.down.circle", description: Text("保存的文件会显示在这里。"))
            } else if grid {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 105, maximum: 160), spacing: 20)], spacing: 24) {
                        ForEach(sortedItems) { item in
                            fileButton(item, grid: true)
                        }
                    }.padding(20)
                }
            } else {
                List(sortedItems) { item in fileButton(item, grid: false) }
                    .listStyle(.plain)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("下载管理").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { grid.toggle() } label: {
                    Image(systemName: grid ? "list.bullet" : "square.grid.2x2")
                }.accessibilityLabel(grid ? "切换列表视图" : "切换网格视图")
                Menu {
                    Picker("排序方式", selection: $sortRaw) {
                        ForEach(DownloadSort.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    Picker("顺序", selection: $ascending) {
                        Text("升序").tag(true); Text("降序").tag(false)
                    }
                    Divider()
                    Picker("文件保留（仅本机）", selection: $settings.downloadRetention) {
                        ForEach(DownloadRetention.allCases) { Text($0.title).tag($0) }
                    }
                    Button("更改下载位置", systemImage: "folder") { chooseFolder = true }
                    if center.defaultFolderBookmark != nil {
                        Button("恢复默认 Downloads 位置") { center.resetDefaultFolder() }
                    }
                } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("排序与下载选项")
            }
        }
        .sheet(isPresented: $chooseFolder) {
            DownloadFolderPicker { url in
                do { try center.selectDefaultFolder(url) }
                catch { center.reportError("无法使用此文件夹，请重新选择。\(error.localizedDescription)") }
            }
        }
        .confirmationDialog("删除此下载文件？", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("删除文件", role: .destructive) {
                if let id = pendingDelete { Task { await center.removeFile(id) } }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: { Text("仅删除这条记录对应的文件，其他文件及另存副本不受影响。") }
        .alert("文件操作未完成", isPresented: Binding(get: { center.locationError != nil }, set: { if !$0 { center.locationError = nil } })) {
            Button("好") { center.locationError = nil }
        } message: { Text(center.locationError ?? "") }
    }
    private func fileButton(_ item: DownloadItem, grid: Bool) -> some View {
        Button {
            if item.state == .completed { center.open(item) }
            else if center.canRetry(item.id) { center.retry(item.id) }
            else if item.state != .downloading { app.openSite(item.site) }
        } label: {
            Group {
                if grid {
                    VStack(spacing: 10) {
                        DownloadThumbnail(url: item.state == .completed ? center.fileURL(for: item) : nil)
                            .frame(width: 72, height: 88)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 4))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(uiColor: .separator).opacity(0.4), lineWidth: 0.5))
                        Text(item.filename).font(.caption).lineLimit(2).multilineTextAlignment(.center)
                        if item.state == .downloading { ProgressView(value: item.progress).frame(width: 72) }
                        else if item.state != .completed { Image(systemName: "exclamationmark.circle").foregroundStyle(.secondary) }
                    }.frame(maxWidth: .infinity, alignment: .top)
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: item.state == .completed ? "doc" : "arrow.down.doc")
                            .foregroundStyle(Theme.accent).frame(width: 24)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.filename).font(.body).lineLimit(1)
                            if item.state == .downloading { ProgressView(value: item.progress) }
                        }
                        Spacer(minLength: 0)
                        if item.state == .failed || item.state == .cancelled {
                            Image(systemName: "exclamationmark.circle").foregroundStyle(.secondary)
                        }
                    }.frame(minHeight: 36).contentShape(Rectangle())
                }
            }.foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.filename)
        .accessibilityValue(item.state == .completed ? ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file) : item.state == .downloading ? "下载中" : "未完成")
        .contextMenu {
            if item.state == .completed {
                Button("预览", systemImage: "doc.text.magnifyingglass") { center.open(item) }
                if let url = center.fileURL(for: item) { ShareLink(item: url) { Label("分享", systemImage: "square.and.arrow.up") } }
            } else if item.state == .downloading {
                Button("取消下载", systemImage: "xmark.circle") { center.cancel(item.id) }
            } else if center.canRetry(item.id) {
                Button("继续下载", systemImage: "arrow.clockwise") { center.retry(item.id) }
            } else {
                Button("打开来源站点", systemImage: "safari") { app.openSite(item.site) }
            }
            Button("删除", systemImage: "trash", role: .destructive) { pendingDelete = item.id }
        }
    }
}

private struct DownloadThumbnail: View {
    let url: URL?
    @State private var image: UIImage?
    var body: some View {
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
