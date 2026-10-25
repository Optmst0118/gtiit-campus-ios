import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct DocumentPreviewView: View {
    @Environment(\.locale) private var nativeLocale
    @ObservedObject var session: PDFPreviewSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showFileLocation = false
    var body: some View {
        let _ = nativeLocale.identifier

        NavigationStack {
            GeometryReader { geometry in
                let placement = PDFDownloadPlacement(bottomSafeArea: geometry.safeAreaInsets.bottom, trailingSafeArea: geometry.safeAreaInsets.trailing)
                ZStack(alignment: .bottomTrailing) {
                Color(uiColor: .secondarySystemBackground).ignoresSafeArea()
                if let document = session.document {
                    PDFCanvas(document: document).ignoresSafeArea(edges: .bottom)
                } else if session.state == .failed {
                    ContentUnavailableView(L10n.tr("无法预览 PDF"), systemImage: "doc.badge.exclamationmark", description: Text(session.error ?? L10n.tr("请返回课程后重试。")))
                } else {
                    VStack(spacing: 16) { ProgressView(value: session.progress); Text(L10n.tr("正在加载预览…")).font(.subheadline).foregroundStyle(.secondary) }.padding(40)
                }
                if session.document != nil, session.saveAction != nil || session.savedURL != nil {
                    VStack(alignment: .trailing, spacing: 12) {
                        if let error = session.error {
                            Text(error).font(.caption).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)).frame(maxWidth: 280)
                        }
                        PDFSaveControl(session: session, showFileLocation: $showFileLocation,
                            maximumWidth: geometry.size.width - placement.trailingPadding - 20)


                    }
                    .padding(.trailing, placement.trailingPadding)
                    .padding(.bottom, placement.bottomPadding)
                }
                }
            }
            .navigationTitle(session.filename).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("完成")) { session.closeAction?() }.disabled(session.state == .saving) } }
        }.tint(Theme.accent)
            .sheet(isPresented: $showFileLocation) {
                if let url = session.savedURL { PDFSavedLocationPicker(url: url) }
            }
            .onChange(of: session.error) { _, error in if error != nil { Haptics.error() } }
            .onChange(of: session.state) { _, state in
                if state == .saved { Haptics.success() }
                else if state == .failed { Haptics.error() }
            }
    }
}
private struct PDFDownloadPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 1.065 : 1)
            .brightness(configuration.isPressed ? 0.025 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
private struct PDFCanvas: UIViewRepresentable {
    let document: PDFDocument
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView(); view.autoScales = true; view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical; view.document = document
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document; view.autoScales = true }
    }
}
/// 使用公开安全区计算对称的屏幕边距；不依赖设备型号或私有屏幕圆角 API。
struct PDFDownloadPlacement {
    static let diameter: CGFloat = 60
    let trailingPadding: CGFloat
    let bottomPadding: CGFloat
    init(bottomSafeArea: CGFloat, trailingSafeArea: CGFloat) {
        let edge = max(20, max(bottomSafeArea, trailingSafeArea))
        trailingPadding = max(0, edge - trailingSafeArea)
        bottomPadding = max(0, edge - bottomSafeArea)
    }
}
/// A persistent glass surface changes width and curvature instead of replacing
/// two unrelated controls. Content fades inside the same trailing-anchored lens.
private struct PDFSaveControl: View {
    @ObservedObject var session: PDFPreviewSession
    @Binding var showFileLocation: Bool
    let maximumWidth: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var saved: Bool { session.state == .saved && session.savedURL != nil }
    var body: some View {
        ZStack {
            Button { Haptics.medium(); session.saveAction?() } label: {
                Group {
                    if session.state == .saving { ProgressView() }
                    else { Image(systemName: "arrow.down").font(.system(size: 23, weight: .semibold)) }
                }.frame(width: 60, height: 60)
            }.disabled(!session.canSave).opacity(saved ? 0 : 1)
                .allowsHitTesting(!saved).accessibilityHidden(saved)
                .accessibilityLabel(session.state == .saving ? L10n.tr("正在保存") : L10n.tr("下载 PDF"))
            HStack(spacing: 8) {
                Label(L10n.tr("已下载"), systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Divider().frame(height: 22)
                if let url = session.url ?? session.savedURL {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up").font(.title3.weight(.semibold)).frame(width: 44, height: 44)
                    }.accessibilityLabel(L10n.tr("分享"))
                }
                Button { Haptics.selection(); showFileLocation = true } label: {
                    Image(systemName: "folder").font(.title3.weight(.semibold)).frame(width: 44, height: 44)
                }.accessibilityLabel(L10n.tr("在文件中显示"))
            }.padding(.horizontal, 14).frame(width: min(278, maximumWidth), height: 60)
                .opacity(saved ? 1 : 0).allowsHitTesting(saved).accessibilityHidden(!saved)
        }
        .frame(width: saved ? min(278, maximumWidth) : 60, height: 60)
        .clipped()
        .foregroundStyle(saved ? Color.white : Theme.accent)
        .modifier(PDFMorphingGlass(saved: saved))
        .buttonStyle(PDFDownloadPressStyle())
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.42, dampingFraction: 0.82), value: saved)
    }
}
private struct PDFMorphingGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let saved: Bool
    @ViewBuilder func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: saved ? 22 : 30, style: .continuous)
        if reduceTransparency {
            content.background(saved ? Theme.accent : Theme.cardBackground, in: shape)
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(saved ? Theme.accent : Color.white.opacity(0.15)).interactive(), in: shape)
        } else {
            content.background(saved ? Theme.accent : Color.white.opacity(0.15), in: shape)
                .background(.regularMaterial, in: shape)
        }
    }
}
/// Uses the system Files interface at the original saved directory; no new copy or download.
private struct PDFSavedLocationPicker: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: false)
        controller.directoryURL = url.deletingLastPathComponent()
        controller.shouldShowFileExtensions = true
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { controller.dismiss(animated: true) }
    }
}
