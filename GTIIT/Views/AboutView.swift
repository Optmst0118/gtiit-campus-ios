import SwiftUI

struct AboutView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    private var campusMark: UIImage {
        if let url = Bundle.main.url(forResource: "CampusMark", withExtension: "png", subdirectory: "CampusData"), let image = UIImage(contentsOfFile: url.path) { return image }
        return UIImage(named: "CampusMark") ?? UIImage()
    }
    var body: some View {
        let _ = nativeLocale.identifier

        List {
            Section {
                HStack(spacing: 16) {
                    Image(uiImage: campusMark).resizable().renderingMode(.original).scaledToFit().frame(width: 62, height: 62).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YOUR CAMPUS, CONNECTED").font(.system(size: 9, weight: .semibold))
                            .tracking(1.3).foregroundStyle(Theme.accent)
                        Text(L10n.tr("GTIIT 校园助手")).font(.headline)
                        Text(L10n.tr("学习、生活，一路相连。")).font(.subheadline).foregroundStyle(.secondary)
                        Text(AppInfo.versionText).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 16).contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .global) { point in app.yilong.tap(at: point, settings: settings) }
            }
            Section {
                NavigationLink {
                    PrivacyAndSafetyView()
                } label: {
                    Label(L10n.tr("隐私与安全"), systemImage: "lock.shield")
                }
                NavigationLink {
                    TechnicalLogView()
                } label: {
                    Label(L10n.tr("技术日志"), systemImage: "doc.text")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.pageBackground)
        .navigationTitle(L10n.tr("关于 GTIIT"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) {
            Text(L10n.tr("关于 GTIIT")).font(.headline).padding(8).contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .global) { point in app.yilong.tap(at: point, settings: settings) }
        } }
    }
}

struct PrivacyAndSafetyView: View {
    @Environment(\.locale) private var nativeLocale
    var body: some View {
        let _ = nativeLocale.identifier
 AboutDetailsView(privacy: true) }
}
struct TechnicalLogView: View {
    @Environment(\.locale) private var nativeLocale
    var body: some View {
        let _ = nativeLocale.identifier
 AboutDetailsView(privacy: false) }
}

private struct AboutDetailsView: View {
    @Environment(\.locale) private var nativeLocale
    let privacy: Bool
    var body: some View {
        let _ = nativeLocale.identifier

        List {
            if privacy {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("非官方客户端"))
                        .font(.headline)
                    Text(
                        L10n.tr("这是学生自制的客户端，不是 GTIIT（广东以色列理工学院）发布的官方 App，也与学校没有隶属或合作关系。它将校园网站与班车时刻表集中到一个 App。")
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }

            Section(L10n.tr("App 不做什么")) {
                bullet("xmark.circle", L10n.tr("不会自动读取成绩、考勤或预约记录。只有你主动提取并确认时，课程名称、星期、时间与教室才保存在本机。"), color: .red)
                bullet("xmark.circle", L10n.tr("不保存账号密码，不接管学校登录，不索要验证码。"), color: .red)
                bullet("xmark.circle", L10n.tr("不代填、不代提交任何表单（请假、评价、选课、预约、作业）。"), color: .red)
                bullet("xmark.circle", L10n.tr("不做埋点、不做第三方统计、不上传页面内容。"), color: .red)
            }

            Section(L10n.tr("数据与隐私")) {
                PrivacyLine(title: L10n.tr("本地课表"), detail: L10n.tr("仅主动提取门户正式选课的课程、班组、时间与教室，确认后存于本机受文件保护的 Application Support，排除系统备份。不保存账号、成绩或网页原文，可在设置中删除。课表为离线快照，变更后需重新提取。"))
                PrivacyLine(title: L10n.tr("Moodle 临近日程"), detail: L10n.tr("进入我的页面后，使用学习页面现有会话，只读核对 Moodle 日历及各课程作业的名称、开放与截止时间、提交状态。摘要仅在当前运行内存中使用；清除 Moodle 登录数据时同步清除，不保存作业正文、成绩或附件。"))
                PrivacyLine(title: L10n.tr("网页数据"), detail: L10n.tr("Cookie、缓存与本地存储由 WebKit 保存在本机沙盒内，四个站点各用独立容器，可单独清除。"))
                PrivacyLine(
                    title: L10n.tr("下载文件"),
                    detail: L10n.tr("Moodle PDF 先进入临时预览，点击下载后才保存。默认保存在本机 Documents/Downloads，可在下载管理更改新文件的保存位置。已有文件不迁移；外部文件夹不参与自动清理。临时预览关闭后清理，断点凭证只留在当前运行内存中。"))
                PrivacyLine(title: L10n.tr("账号凭据"), detail: L10n.tr("学校页面与 WebKit 持有登录会话。原生层不读取或保存账号密码、会话密钥；日程请求仅在学校同域网页会话内完成。"))
                PrivacyLine(
                    title: L10n.tr("本机偏好"),
                    detail: L10n.tr("保存显示、启动、浏览、锁定及下载保留偏好、四站容器标识。开启恢复页面时，仅保存不含参数的站内普通地址，不保存表单、认证地址或账号密码。"))
                PrivacyLine(title: L10n.tr("生物识别"), detail: L10n.tr("由 iOS 系统校验面容 ID / 触控 ID / 设备密码，App 只收到成功或失败，接触不到生物特征数据。"))
                PrivacyLine(
                    title: L10n.tr("网络请求"),
                    detail: L10n.tr("网页会访问所打开的站点、页面资源与登录服务。主动运行诊断时，向四站公开首页发送不带 Cookie 的 HEAD 请求。没有自建后端和统计 SDK。网页暗色适配会按需读取当前页面已引用的 CSS，不加载远程配色脚本、不分析图片、不读取表单值。"))
                PrivacyLine(title: L10n.tr("隐私清单"), detail: L10n.tr("App 声明不追踪、不收集数据；唯一声明的 API 用途是 UserDefaults（保存本机偏好）。"))
            }

            } else {
            Section(L10n.tr("App 做什么")) {
                bullet("square.grid.2x2", L10n.tr("用底部五个标签承载班车、门户、Moodle、预约与我的。"), color: Theme.accent)
                bullet("bus", L10n.tr("班车按提供的时刻表计算计划发车倒计时，不是实时到站信息。"), color: Theme.orange)
                bullet("safari", L10n.tr("每个标签加载对应官方网页，页面布局、登录和业务操作都不改造。"), color: Theme.accent)
                bullet("bolt", L10n.tr("冷启动并行预加载四站，恢复有效会话；密码、验证码及二次验证由你在学校页面完成。"), color: Theme.accent)
                bullet("arrow.triangle.branch", L10n.tr("主动点击普通跨站链接时切换标签；表单、登录与新窗口保留原认证上下文。"), color: Theme.accent)
                bullet("lock.shield", L10n.tr("四个站点各自持久保存网页会话，可单独清除，也可用面容 ID 遮挡。"), color: Theme.accent)
            }

            Section(L10n.tr("技术实现")) {
                bullet(
                    "iphone", L10n.tr("SwiftUI + WKWebView，最低 iOS 17（使用带标识符的持久化 WKWebsiteDataStore）。"),
                    color: .secondary)
                bullet("square.stack.3d.up", L10n.tr("四站独立数据容器，切换标签不重新加载页面。"), color: .secondary)
                bullet("arrow.down.doc", L10n.tr("网页文件保存在本机，支持进度、取消、可用时续传、预览及系统另存。"), color: .secondary)
                bullet("moon", L10n.tr("网页暗色适配使用本地 Dark Reader 4.9.133（MIT）。隔离脚本世界运行，禁用页面 JS 原型代理，可逐站恢复原色。"), color: .secondary)
            }

            Section(L10n.format("已知限制（研究快照 %@）", String(describing: AppInfo.researchDate))) {
                limitation(L10n.tr("登录后的全量盘点尚未完成，页面结构可能变化。"))
                limitation(L10n.tr("门户、房间、体育都没有获准的原生接口；Booked 标准 API 在本校为关闭状态。"))
                limitation(L10n.tr("Moodle 移动令牌、自有回调尚未验证，因此首版不提供原生课程数据。"))
                limitation(L10n.tr("没有后台推送与定时轮询；打开 App 才能看到最新页面。"))
                limitation(L10n.tr("校园站点通常需要校内网络或学校认可的访问方式，境外/公共网络可能无法解析。"))
                limitation(L10n.tr("App 不会绕过证书校验，也不会自动填写账号。"))
            }

            Section(L10n.tr("版本")) {
                HStack {
                    Text(L10n.tr("版本号"))
                    Spacer()
                    Text(AppInfo.versionText).foregroundStyle(.secondary)
                }
                HStack {
                    Text(L10n.tr("资料来源"))
                    Spacer()
                    Text(L10n.tr("GTIIT iOS 调研包")).foregroundStyle(.secondary)
                }
            }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.pageBackground)
        .navigationTitle(privacy ? L10n.tr("隐私与安全") : L10n.tr("技术日志"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bullet(_ symbol: String, _ text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 20)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func limitation(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 18)
                .padding(.top, 2)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

private struct PrivacyLine: View {
    @Environment(\.locale) private var nativeLocale
    let title: String
    let detail: String

    var body: some View {
        let _ = nativeLocale.identifier

        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}
