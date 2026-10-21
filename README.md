# GTIIT 校园助手 · iOS 1.2 (6)

SwiftUI + WKWebView 的非官方校园客户端，最低 iOS 17。原生班车倒计时与五个标签入口；门户、Moodle、练习房/讨论室及体育业务由官方网页提供。最新设计看板与图标源文件见 [设计参考](docs/design/DESIGN.md)。

## 打开与构建

用 Xcode 打开 `GTIIT.xcodeproj`，选择 GTIIT scheme。模拟器可直接构建；真机需在 Signing & Capabilities 中选择自己的开发团队。`Tools/signing.env` 是本机配置，不进入 Git 和更新源码包。

```sh
python3 Tools/gen_project.py
python3 Tools/check_project.py
xcodebuild -project GTIIT.xcodeproj -scheme GTIIT -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

新增源文件后运行工程生成器。生成器从 `DEVELOPMENT_TEAM` 环境变量或本机 `Tools/signing.env` 读取团队配置。

## 本轮改进

- 最左侧新增班车：南→北、北→南双栏，下一班、倒计时、随后班次和完整表。58 个车次来自用户提供的 2026-10-12 时刻表；教学周手动确认，倒计时是计划发车而非实时到站。
- 顶栏移除左右箭头和域名，只显示可点击回主页的标题与“更多”。刷新仅放在“更多”；前进后退仍可从更多访问。
- 校徽改绘采用天蓝／橙色二维制图风格；真正的 AppIcon.icon 分层工程交由 Apple actool 渲染 Liquid Glass，提供浅色、深色及透明外观。
- PDF 自动显示天蓝色下载浮窗，完成后约 4 秒渐隐，继续浏览或切换标签时收起。支持预览、系统文件选择器另存；WebKit 转下载的正常 102 中断不会显示错误页。
- “我的”页提供固定齿轮入口，设置独立分组：通用、隐私与锁定、网页浏览、站点与登录、存储空间、下载、帮助、关于。
- 外观跟随系统/浅色/深色即时生效；启动页面及默认预约分类下次启动生效。
- 可选择其他网站链接的打开方式：当前网页、App 内 Safari、系统默认浏览器。网页菜单也有明确独立的两个浏览器出口。
- 普通跨站 GET 链接切换标签；POST、登录及重定向保留原上下文。新窗口由 WebKit 的原配置创建，保留 opener 和 postMessage。
- blob/data/about 等网页内部资源保留在 WebKit；PDF 当前响应直接进入下载，保留原 Cookie/POST/一次性链接上下文，不重新发起 GET。
- 单站和全站清除会先销毁活动文档、停止相关下载，再清除并更换持久化容器、替换网页内核，移除历史。清除后不会自动访问网站，等待用户重新打开。若旧容器暂被系统占用，会明确提示并提供重试，不假报清理成功。
- 缓存与登录数据分开管理；存储页展示可准确取得的记录/Cookie 数及下载字节数，不虚构 WebKit 缓存大小或登录状态。
- 下载支持进度、取消、服务器支持时续传、同名文件、系统分享和删除。默认永久保存在“文件 → 我的 iPhone → GTIIT → Downloads”；也可显式选择下次启动/1 天/7 天后清理。
- App 锁支持立即/1 分钟/5 分钟，使用系统生物识别或设备密码验证。后台用独立窗口遮挡，覆盖网页窗口、分享和内置 Safari；认证失败、取消或不可用时保持锁定。
- 可选恢复上次普通页面，仅记住同站 HTTPS、不含查询参数且不属于认证/表单的地址；不跨启动保存表单草稿和滚动位置。
- 网络诊断用不带 Cookie 的 HEAD 请求，不跟随认证跳转；可分享只包含版本、站点、状态码和时间的摘要。
- 原生界面统一为天蓝／橙色、纸面背景、系统分组列表和语义字体；顶栏控件至少 44×44 点。动效遵循系统减弱动态效果设置。

## 验证与证据

自动回归在独立测试 App `local.gtiit.regression` 中运行，需自建名称包含 Review 或 Test 的可丢弃模拟器。只使用本地合成数据，测试包与正式 App 数据隔离。

```sh
python3 Tools/run_regression.py <测试模拟器UDID>
python3 Tools/verify_builds.py
```

1.2 验收包含真实 WebKit 集成回归与独立班车检查，机器结果位于 `docs/verification/`。1.1 的 56 项与三种构建记录保留为历史材料；最新交付说明为 `docs/RELEASE-1.2.md`。

脚本编译原产品源码，排除 `GTIITApp.swift` 并替换为测试入口。结果写入 `docs/verification/regression-results.json`。涵盖导航策略和真实 WebKit POST、blob、弹窗、下载、缓存/登录清理、保留期限、诊断以及锁定状态。

`Tests/UIReviewHarness.swift` / `Tools/build_ui_review.py` 是独立视觉检查入口，使用原 RootTabView 和系统 Dynamic Type trait，不进入产品编译目标。旧审查材料保留作历史记录，最新验收以 `docs/IMPROVEMENTS-20261021.md` 为准。

## 已知边界

四站需要在 App 内分别登录，Safari 的会话不会自动迁入。诊断连通性不等于已登录或业务可用。学校 SSO、页面、接口与网络策略可能变化，需在真实账号下复核；本轮没有自动提交真实预约、选课、评价或作业，也没有绕过验证码、证书或学校权限。

没有成绩自动抓取、后台推送、自建后端或统计 SDK。App 锁遮挡界面，不替代学校账号安全机制。续传取决于服务器，断点凭证仅保存在当前进程内存。App 被卸载时其本机下载也会删除，需要独立保留的文件可另存到 iCloud Drive。

## 回溯

项目已初始化独立 Git 仓库。修改前基线是 `0de31f5`，功能实现提交是 `b25fbe1`。后续文档、验证与修复保留独立提交，可用 `git log --oneline` 查看完整记录。

查看改动：

```sh
git diff 0de31f5..HEAD -- GTIIT Tools Tests
```

在新目录恢复基线，不覆盖当前修改：

```sh
git worktree add ../GTIIT-iOS-App-baseline 0de31f5
```

额外的完整修改前压缩快照位于 `backup-archive.tar.gz`，SHA-256：`264279ff86eaad3a4bc6eafdbcf3057a1f23973e84eac18b93a72a3f892d7d1f`。原始 `GTIIT-iOS-App.zip` 保持原样。
