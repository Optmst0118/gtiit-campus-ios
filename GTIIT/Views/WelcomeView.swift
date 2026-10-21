import SwiftUI

/// 首次启动说明：把「非官方 + 只做容器 + 不采集 + 显式确认」讲清楚。
struct WelcomeView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var hasConfirmed = false
    @State private var showAbout = false

    private struct Point: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
    }

    private let points: [Point] = [
        Point(
            symbol: "square.grid.2x2.fill", title: "四个官方网页，一个入口",
            detail: "从门户、学习和预约分区，快速打开学生门户、Moodle、房间预约和体育中心。"),
        Point(symbol: "safari.fill", title: "页面保持原样", detail: "App 不改写网页布局；登录、提交、预约都在官方页面完成。"),
        Point(symbol: "lock.shield.fill", title: "会话各管各的", detail: "每个站点使用独立的持久网页容器，可单独清除，互不影响。"),
        Point(symbol: "hand.raised.fill", title: "不采集数据", detail: "没有账号密码存储、没有埋点、没有自建后端。"),
        Point(symbol: "wifi.exclamationmark", title: "网络有前提", detail: "校园站点通常需要校内网络或学校认可的访问方式。"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(points) { point in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: point.symbol)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 28, height: 28)
                                .background(
                                    Theme.accent.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(point.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(point.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    disclaimerCard
                }
                .padding(20)
            }
        }
        .background(Theme.pageBackground)
        .safeAreaInset(edge: .bottom) {
            footer
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showAbout) {
            NavigationStack {
                AboutView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showAbout = false }
                        }
                    }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.accent)
                .frame(width: 78, height: 78)
                .overlay(
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                )

            VStack(spacing: 4) {
                Text(AppInfo.displayName)
                    .font(.title2.weight(.bold))
                Text(AppInfo.tagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(SiteID.allCases) { site in
                    Image(systemName: site.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(site.tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(.top, 2)
        }
        .padding(.top, 34)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Theme.accent.opacity(0.10), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("这是非官方客户端", systemImage: "exclamationmark.shield.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.orange)

            Text(
                "本应用由学生个人开发，非广东以色列理工学院官方应用，与学校无隶属关系。它只是四个官方网页的浏览入口，不修改任何学校功能。登录与网页数据仅保存在本机，开发者不采集、不上传。选课、申请、评价、预约等业务请在官方网页内自行确认并提交，本应用不代填、不代提交。使用需能访问校园网络及相关校内域名，网络受限时可能打不开。"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if !settings.hasSeenWelcome {
                Button {
                    hasConfirmed.toggle()
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: hasConfirmed ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(hasConfirmed ? Theme.accent : Color.secondary)

                        Text("我已阅读并了解：本应用不是学校官方应用，仅作为官方网页入口，不采集数据、不代填、不代提交。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button {
                guard hasConfirmed || settings.hasSeenWelcome else { return }
                settings.markWelcomeSeen()
                app.showWelcome = false
                dismiss()
            } label: {
                Text(settings.hasSeenWelcome ? "完成" : "我已了解，开始使用")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!hasConfirmed && !settings.hasSeenWelcome)

            Button("查看完整说明与隐私") {
                showAbout = true
            }
            .font(.footnote)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            Theme.pageBackground
                .overlay(alignment: .top) { Divider() }
        )
    }
}
