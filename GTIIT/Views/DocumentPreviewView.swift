import PDFKit
import SwiftUI

struct DocumentPreviewView: View {
    @ObservedObject var session: PDFPreviewSession
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(uiColor: .secondarySystemBackground).ignoresSafeArea()
                if let document = session.document {
                    PDFCanvas(document: document).ignoresSafeArea(edges: .bottom)
                } else if session.state == .failed {
                    ContentUnavailableView("无法预览 PDF", systemImage: "doc.badge.exclamationmark", description: Text(session.error ?? "请返回课程后重试。"))
                } else {
                    VStack(spacing: 16) { ProgressView(value: session.progress); Text("正在加载预览…").font(.subheadline).foregroundStyle(.secondary) }.padding(40)
                }
                if session.document != nil, session.saveAction != nil {
                    VStack(alignment: .trailing, spacing: 12) {
                        if let error = session.error {
                            Text(error).font(.caption).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)).frame(maxWidth: 280)
                        }
                        Button { session.saveAction?() } label: {
                            Group {
                                if session.state == .saving { ProgressView() }
                                else { Image(systemName: session.state == .saved ? "checkmark" : "arrow.down").font(.system(size: 20, weight: .semibold)) }
                            }.frame(width: 48, height: 48)
                        }
                        .buttonStyle(.plain).foregroundStyle(Theme.accent)
                        .modifier(PDFDownloadGlass())
                        .disabled(!session.canSave)
                        .accessibilityLabel(session.state == .saved ? "已下载" : session.state == .saving ? "正在保存" : "下载 PDF")
                    }.padding(20)
                }
            }
            .navigationTitle(session.filename).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { session.closeAction?() }.disabled(session.state == .saving) } }
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
private struct PDFDownloadGlass: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) { content.glassEffect(.regular.tint(Theme.sky.opacity(0.28)).interactive(), in: Circle()) }
        else { content.background(Theme.sky.opacity(0.15), in: Circle()).background(.regularMaterial, in: Circle()) }
    }
}
