import PDFKit
import SwiftUI

struct DocumentPreviewView: View {
    @Environment(\.locale) private var nativeLocale
    @ObservedObject var session: PDFPreviewSession
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
                if session.document != nil, session.saveAction != nil {
                    VStack(alignment: .trailing, spacing: 12) {
                        if let error = session.error {
                            Text(error).font(.caption).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)).frame(maxWidth: 280)
                        }
                        Button { session.saveAction?() } label: {
                            Group {
                                if session.state == .saving { ProgressView() }
                                else { Image(systemName: session.state == .saved ? "checkmark" : "arrow.down").font(.system(size: 23, weight: .semibold)) }
                            }.frame(width: PDFDownloadPlacement.diameter, height: PDFDownloadPlacement.diameter)
                        }
                        .buttonStyle(.plain).foregroundStyle(session.state == .saved ? Color.white : Theme.accent)
                        .modifier(PDFDownloadGlass(saved: session.state == .saved))
                        .disabled(session.state == .saving)
                        .allowsHitTesting(session.canSave)
                        .accessibilityLabel(session.state == .saved ? L10n.tr("已下载") : session.state == .saving ? L10n.tr("正在保存") : L10n.tr("下载 PDF"))
                    }
                    .padding(.trailing, placement.trailingPadding)
                    .padding(.bottom, placement.bottomPadding)
                }
                }
            }
            .navigationTitle(session.filename).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("完成")) { session.closeAction?() }.disabled(session.state == .saving) } }
        }.tint(Theme.accent)
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
private struct PDFDownloadGlass: ViewModifier {
    let saved: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(saved ? Theme.accent : Color.white.opacity(0.15)).interactive(), in: Circle())
        } else {
            content.background(saved ? Theme.accent : Color.white.opacity(0.15), in: Circle())
                .background(.regularMaterial, in: Circle())
        }
    }
}
