import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Image("CampusMark").resizable().scaledToFit().frame(width: 62, height: 62)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YOUR CAMPUS, CONNECTED").font(.system(size: 9, weight: .semibold))
                            .tracking(1.3).foregroundStyle(Theme.accent)
                        Text("GTIIT 校园助手").font(.headline)
                        Text("学习、生活，一路相连。").font(.subheadline).foregroundStyle(.secondary)
                        Text(AppInfo.versionText).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 16)
            }
            Section {
                NavigationLink {
                    PrivacyAndSafetyView()
                } label: {
                    Label("隐私与安全", systemImage: "lock.shield")
                }
                NavigationLink {
                    TechnicalLogView()
                } label: {
                    Label("技术日志", systemImage: "doc.text")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.pageBackground)
        .navigationTitle("关于 GTIIT")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyAndSafetyView: View {
    var body: some View { AboutDetailsView(privacy: true) }
}
struct TechnicalLogView: View {
    var body: some View { AboutDetailsView(privacy: false) }
}

private struct AboutDetailsView: View {
    let privacy: Bool
    var body: some View {
        List {
            if privacy {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("非官方客户端")
                        .font(.headline)
                    Text(
                        "这是学生自制的客户端，不是 GTIIT（广东以色列理工学院）发布的官方 App，也与学校没有隶属或合作关系。它将校园网站与班车时刻表集中到一个 App。"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }

            Section("App 不做什么") {
                bullet("xmark.circle", "不读取、不解析、不落库任何学业数据（成绩、考勤、课表、预约记录）。", color: .red)
                bullet("xmark.circle", "不保存账号密码，不接管学校登录，不索要验证码。", color: .red)
                bullet("xmark.circle", "不代填、不代提交任何表单（请假、评价、选课、预约、作业）。", color: .red)
                bullet("xmark.circle", "不做埋点、不做第三方统计、不上传页面内容。", color: .red)
            }

            Section("数据与隐私") {
                PrivacyLine(title: "网页数据", detail: "Cookie、缓存与本地存储由 WebKit 保存在本机沙盒内，四个站点各用独立容器，可单独清除。")
                PrivacyLine(
                    title: "下载文件",
                    detail: "Moodle PDF 先进入临时预览，点击下载后才保存。默认保存在本机 Documents/Downloads，可在下载管理更改新文件的保存位置。已有文件不迁移；外部文件夹不参与自动清理。临时预览关闭后清理，断点凭证只留在当前运行内存中。")
                PrivacyLine(title: "账号凭据", detail: "由学校官方页面自行处理，App 代码不接触、不记录、不发送。")
                PrivacyLine(
                    title: "本机偏好",
                    detail: "保存显示、启动、浏览、锁定及下载保留偏好、四站容器标识。开启恢复页面时，仅保存不含参数的站内普通地址，不保存表单、认证地址或账号密码。")
                PrivacyLine(title: "生物识别", detail: "由 iOS 系统校验面容 ID / 触控 ID / 设备密码，App 只收到成功或失败，接触不到生物特征数据。")
                PrivacyLine(
                    title: "网络请求",
                    detail: "网页会访问所打开的站点、页面资源与登录服务。主动运行诊断时，向四站公开首页发送不带 Cookie 的 HEAD 请求。没有自建后端和统计 SDK。网页暗色适配会按需读取当前页面已引用的 CSS，不加载远程配色脚本、不分析图片、不读取表单值。")
                PrivacyLine(title: "隐私清单", detail: "App 声明不追踪、不收集数据；唯一声明的 API 用途是 UserDefaults（保存本机偏好）。")
            }

            } else {
            Section("App 做什么") {
                bullet("square.grid.2x2", "用底部五个标签承载班车、门户、Moodle、预约与我的。", color: Theme.accent)
                bullet("bus", "班车按提供的时刻表计算计划发车倒计时，不是实时到站信息。", color: Theme.orange)
                bullet("safari", "每个标签加载对应官方网页，页面布局、登录和业务操作都不改造。", color: Theme.accent)
                bullet("bolt", "冷启动并行预加载四站，恢复有效会话；密码、验证码及二次验证由你在学校页面完成。", color: Theme.accent)
                bullet("arrow.triangle.branch", "主动点击普通跨站链接时切换标签；表单、登录与新窗口保留原认证上下文。", color: Theme.accent)
                bullet("lock.shield", "四个站点各自持久保存网页会话，可单独清除，也可用面容 ID 遮挡。", color: Theme.accent)
            }

            Section("技术实现") {
                bullet(
                    "iphone", "SwiftUI + WKWebView，最低 iOS 17（使用带标识符的持久化 WKWebsiteDataStore）。",
                    color: .secondary)
                bullet("square.stack.3d.up", "四站独立数据容器，切换标签不重新加载页面。", color: .secondary)
                bullet("arrow.down.doc", "网页文件保存在本机，支持进度、取消、可用时续传、预览及系统另存。", color: .secondary)
                bullet("moon", "网页暗色适配使用本地 Dark Reader 4.9.133（MIT）。隔离脚本世界运行，禁用页面 JS 原型代理，可逐站恢复原色。", color: .secondary)
            }

            Section("已知限制（研究快照 \(AppInfo.researchDate)）") {
                limitation("登录后的全量盘点尚未完成，页面结构可能变化。")
                limitation("门户、房间、体育都没有获准的原生接口；Booked 标准 API 在本校为关闭状态。")
                limitation("Moodle 移动令牌、自有回调尚未验证，因此首版不提供原生课程数据。")
                limitation("没有后台推送与定时轮询；打开 App 才能看到最新页面。")
                limitation("校园站点通常需要校内网络或学校认可的访问方式，境外/公共网络可能无法解析。")
                limitation("App 不会绕过证书校验，也不会自动填写账号。")
            }

            Section("版本") {
                HStack {
                    Text("版本号")
                    Spacer()
                    Text(AppInfo.versionText).foregroundStyle(.secondary)
                }
                HStack {
                    Text("资料来源")
                    Spacer()
                    Text("GTIIT iOS 调研包").foregroundStyle(.secondary)
                }
            }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.pageBackground)
        .navigationTitle(privacy ? "隐私与安全" : "技术日志")
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
    let title: String
    let detail: String

    var body: some View {
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
