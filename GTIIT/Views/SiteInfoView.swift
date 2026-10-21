import SwiftUI

/// 单站说明卡：用途、首版边界、已知前提、入口地址与数据清理。
struct SiteInfoView: View {
    @EnvironmentObject private var app: AppModel
    let site: SiteID

    @Environment(\.dismiss) private var dismiss
    @State private var showClearDialog = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        SiteBadge(site: site, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.displayName)
                                .font(.headline)
                            Text(site.host)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("用途") {
                    Text(site.purpose)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("首版边界") {
                    ForEach(Array(site.capabilityNotes.enumerated()), id: \.offset) { _, note in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(site.tint)
                                .padding(.top, 6)
                            Text(note)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Section("已知前提") {
                    ForEach(Array(site.prerequisites.enumerated()), id: \.offset) { _, note in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                            Text(note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Section("入口") {
                    Text(site.homeURLString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Section {
                    Button {
                        dismiss()
                        app.openSite(site)
                    } label: {
                        Label("打开该站点", systemImage: "arrow.up.forward.app")
                    }

                    Button(role: .destructive) {
                        showClearDialog = true
                    } label: {
                        Label("清除本站网页数据", systemImage: "trash")
                    }
                } footer: {
                    Text("清除后该站点需要重新登录，其他站点不受影响。App 不是学校官方客户端，登录与业务操作都在官方网页里完成。")
                }
            }
            .navigationTitle(site.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .confirmationDialog(
                "清除「\(site.displayName)」的网页数据？",
                isPresented: $showClearDialog,
                titleVisibility: .visible
            ) {
                Button("清除并重新登录", role: .destructive) {
                    Task { await app.clearData(for: site) }
                }
                Button("取消", role: .cancel) {}
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
