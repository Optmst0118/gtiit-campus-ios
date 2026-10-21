import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("非官方客户端")
                        .font(.headline)
                    Text("这是学生自制的客户端，不是 GTIIT（广东以色列理工学院）发布的官方 App，也与学校没有隶属或合作关系。它的作用只有一个：把四个官方网页放进同一个窗口，减少在浏览器里来回切标签的成本。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }

            Section("App 做什么") {
                bullet("square.grid.2x2", "用底部四个标签承载门户、Moodle、预约与我的。", color: Theme.accent)
                bullet("safari", "每个标签加载对应官方网页，页面布局、登录和业务操作都不改造。", color: Theme.accent)
                bullet("arrow.triangle.branch", "网页之间互相跳转时，自动切到对应标签，不把站点串在一起。", color: Theme.accent)
                bullet("lock.shield", "四个站点各自持久保存网页会话，可单独清除，也可用面容 ID 遮挡。", color: Theme.accent)
            }

            Section("App 不做什么") {
                bullet("xmark.circle", "不读取、不解析、不落库任何学业数据（成绩、考勤、课表、预约记录）。", color: .red)
                bullet("xmark.circle", "不保存账号密码，不接管学校登录，不索要验证码。", color: .red)
                bullet("xmark.circle", "不代填、不代提交任何表单（请假、评价、选课、预约、作业）。", color: .red)
                bullet("xmark.circle", "不做埋点、不做第三方统计、不上传页面内容。", color: .red)
            }

            Section("数据与隐私") {
                PrivacyLine(title: "网页数据", detail: "Cookie、缓存与本地存储由 WebKit 保存在本机沙盒内，四个站点各用独立容器，可单独清除。")
                PrivacyLine(title: "下载文件", detail: "只落在 App 临时目录并交给系统分享面板，不建立离线资料库，也不上传。")
                PrivacyLine(title: "账号凭据", detail: "由学校官方页面自行处理，App 代码不接触、不记录、不发送。")
                PrivacyLine(title: "本机偏好", detail: "UserDefaults 里只有：是否看过启动说明、是否开启锁定，以及四个网页数据容器的 UUID。")
                PrivacyLine(title: "生物识别", detail: "由 iOS 系统校验面容 ID / 触控 ID / 设备密码，App 只收到成功或失败，接触不到生物特征数据。")
                PrivacyLine(title: "网络请求", detail: "只发往四个校园站点的官方页面及其登录跳转域名；App 没有自建后端、没有统计 SDK。")
                PrivacyLine(title: "隐私清单", detail: "App 声明不追踪、不收集数据；唯一声明的 API 用途是 UserDefaults（保存本机偏好）。")
            }

            Section("技术实现") {
                bullet("iphone", "SwiftUI + WKWebView，最低 iOS 17（使用带标识符的持久化 WKWebsiteDataStore）。", color: .secondary)
                bullet("square.stack.3d.up", "四站独立数据容器，切换标签不重新加载页面。", color: .secondary)
                bullet("arrow.down.doc", "网页文件下载走系统临时目录 + 分享面板，不建立离线资料库。", color: .secondary)
            }

            Section("已知限制（研究快照 \(AppInfo.researchDate)）" ) {
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
        .navigationTitle("非官方说明")
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