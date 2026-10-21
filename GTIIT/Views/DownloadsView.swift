import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var center: DownloadCoordinator
    @State private var pendingDelete: UUID?
    var body: some View {
        List {
            Section {
                SettingsChoicePicker(
                    "临时文件保留", selection: $settings.downloadRetention, choices: DownloadRetention.allCases,
                    title: { $0.title })
            } footer: {
                Text("下次启动时清理过期文件；系统也可能提前回收缓存。需要长期保留的资料，请使用分享菜单中的“存储到文件”。")
            }
            if center.items.isEmpty {
                ContentUnavailableView(
                    "暂无下载", systemImage: "arrow.down.circle", description: Text("在校园网页中下载的文件会显示在这里。")
                )
                .listRowBackground(Color.clear)
            } else {
                Section("下载记录") {
                    ForEach(center.items) { item in
                        VStack(alignment: .leading, spacing: 10) {
                            Label(
                                item.filename,
                                systemImage: item.state == .completed ? "doc" : "arrow.down.doc"
                            )
                            .font(.body).lineLimit(3)
                            HStack {
                                Text(item.site.displayName)
                                Spacer()
                                Text(status(item))
                            }.font(.caption).foregroundStyle(.secondary)
                            if item.state == .downloading {
                                ProgressView(value: item.progress)
                                Button("取消下载") { center.cancel(item.id) }
                            } else {
                                if let error = item.error {
                                    Text(error).font(.caption).foregroundStyle(.secondary)
                                }
                                HStack(spacing: 20) {
                                    if item.state == .completed, let url = center.fileURL(for: item) {
                                        ShareLink(item: url) {
                                            Label("分享或存储", systemImage: "square.and.arrow.up")
                                        }
                                    } else if center.canRetry(item.id) {
                                        Button("继续下载") { center.retry(item.id) }
                                    } else {
                                        Button("打开来源站点") { app.openSite(item.site) }
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        pendingDelete = item.id
                                    } label: {
                                        Image(systemName: "trash").frame(minWidth: 44, minHeight: 44)
                                    }
                                    .accessibilityLabel("删除\(item.filename)")
                                }.buttonStyle(.borderless)
                            }
                        }.padding(.vertical, 6)
                    }
                }
            }
        }.navigationTitle("下载管理").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "删除此临时下载？",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    if let id = pendingDelete { center.remove(id) }
                    pendingDelete = nil
                }
                Button("取消", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("已保存到“文件”的副本不受影响。")
            }
    }
    private func status(_ item: DownloadItem) -> String {
        switch item.state {
        case .downloading: return item.progress > 0 ? "\(Int(item.progress * 100))%" : "下载中"
        case .completed: return ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file)
        case .failed: return "未完成"
        case .cancelled: return "已取消"
        }
    }
}
