import QuickLook
import SwiftUI
import UniformTypeIdentifiers

/// Safari 式下载路径：当前响应 → 本机 Downloads → Quick Look / 文件位置选择器。
struct DownloadFloatingPanel: View {
    @ObservedObject var center: DownloadCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var exportURL: URL?
    private var item: DownloadItem? { center.items.first { $0.id == center.presentedID } }

    var body: some View {
        Group {
            if let item {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: item.state == .completed ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            .font(.title3).foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title(item)).font(.subheadline.weight(.semibold))
                            Text(item.filename).font(.caption).lineLimit(2).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button { center.dismissPresentation() } label: {
                            Image(systemName: "xmark").font(.caption.weight(.semibold)).frame(width: 44, height: 44)
                        }.buttonStyle(.plain).accessibilityLabel("收起下载窗口")
                    }
                    if item.state == .downloading {
                        ProgressView(value: item.progress).tint(Theme.accent)
                        HStack {
                            Text(item.progress > 0 ? "\(Int(item.progress * 100))%" : "正在连接…")
                                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            Spacer()
                            Button("取消") { center.cancel(item.id) }.font(.caption).frame(minHeight: 32)
                        }
                    } else if item.state == .completed, let url = center.fileURL(for: item) {
                        HStack(spacing: 12) {
                            Button { center.open(item) } label: { Label("预览", systemImage: "doc.text.magnifyingglass") }
                            Spacer(minLength: 0)
                            Button { exportURL = url; center.dismissPresentation() } label: { Label("存储到…", systemImage: "folder") }
                        }.font(.caption.weight(.semibold)).frame(minHeight: 36)
                        Text(item.destinationBookmark == nil ? "已保存到本机 Downloads" : "已保存到所选文件夹").font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text(item.error ?? "下载已取消").font(.caption).foregroundStyle(.secondary)
                        if center.canRetry(item.id) {
                            Button("继续下载") { center.retry(item.id) }.font(.subheadline).frame(minHeight: 36)
                        }
                    }
                }
                .padding(14).frame(width: 280, alignment: .leading)
                .modifier(DownloadGlassSurface())
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
        }
        .tint(Theme.accent)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.25), value: center.presentedID)
        .sheet(isPresented: Binding(get: { exportURL != nil }, set: { if !$0 { exportURL = nil } })) {
            if let exportURL { DownloadExportPicker(url: exportURL) }
        }
    }
    private func title(_ item: DownloadItem) -> String {
        switch item.state {
        case .downloading: return "正在下载"
        case .completed: return "下载完成"
        case .failed: return "下载未完成"
        case .cancelled: return "下载已取消"
        }
    }
}

/// 只保留一个反馈出口：下载有专属面板时，普通 Toast 不与它叠放。
struct BrowserFeedbackOverlay: View {
    @ObservedObject var center: DownloadCoordinator
    let toastText: String?
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if center.presentsOnRoot {
                DownloadFloatingPanel(center: center)
                if center.presentedID == nil, let toastText {
                    ToastView(text: toastText).allowsHitTesting(false)
                }
            }
        }
    }
}

private struct DownloadGlassSurface: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(Theme.sky.opacity(0.2)).interactive(),
                in: RoundedRectangle(cornerRadius: 22))
        } else {
            content
                .background(Theme.sky.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        }
    }
}

private struct DownloadExportPicker: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
}
