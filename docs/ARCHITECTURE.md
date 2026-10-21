# 架构说明 · 1.4

## 应用与界面

`GTIITApp` 创建共享的 `AppSettings` 和 `AppModel`。设置保存在本机 UserDefaults；外观即时生效，启动标签和默认预约分类在下次启动使用。首次引导完成并通过启用的隐私锁后，`LaunchPreparation` 并行准备四站，`LaunchPreloadView` 为实际 WKWebView 提供布局和窗口。进入标签时复用同一 BrowserModel 与 WKWebView。独立 10 秒截止任务与“直接进入”避免等待阻塞；关闭预加载时保留原有按需创建行为。首次引导完成前不预加载。

每进程只执行一次预加载，不清理 Cookie 或缓存。普通登录重定向由网站处理；Moodle 只在官方登录页尝试一次既有 HTTPS SAML 入口。可见密码／验证码表单或认证地址显示“需要登录”；页面就绪不等于认证成功。探测仅读取链接和字段可见性，不读取账号、密码、Cookie 或表单值。

原生界面采用 SwiftUI NavigationStack、List、Form、语义字体和自适应系统颜色。“我的”提供常用入口及设置齿轮；SettingsView 将通用、隐私、浏览、站点、存储、下载、帮助和关于分别展开。辅助功能字号下，SettingsChoicePicker 使用可换行的独立选项列表，避免菜单当前值被截短。

## 四站会话与清理

WebDataStoreRegistry 为四站管理独立的 `WKWebsiteDataStore(forIdentifier:)`，标识保存在 UserDefaults，正常启动复用原标识以保留会话。Safari、内置 Safari 和四站容器之间不自动迁移 Cookie。

清登录数据的流程：

1. 停止本站下载与浏览交互，空白化主文档及子窗口；只匹配本次空白导航的完成回调，忽略旧导航的取消事件。
2. 移除旧 WebView 的视图、代理和观察，将占位视图暂时置于非持久化容器，释放对旧数据容器的引用。
3. 清除原容器数据，并为该入口切换到新 UUID。调用 WebKit 的 `remove(forIdentifier:)` 删除旧持久化容器，避免延迟缓存写入重新进入新的会话。
4. 创建新的网页内核，历史为空；显示“重新打开网站”，不自动访问首页。

若旧文档无法退出，清理中止并明确提示，不把失败记为成功。如果系统暂时仍占用旧容器，其标识进入清理队列：启动时或“存储空间”中重试，界面说明旧缓存尚待释放。队列更新在异步操作后与最新记录合并，避免并发清理丢失条目。

“仅清理缓存”只删除 WebKit 的磁盘、内存和离线网页缓存类型，保留 Cookie/LocalStorage，不刷新正在编辑的页面。记录数量和 Cookie 数不代表已登录；WebKit 不提供准确的分站字节数，界面不虚构该数值。

## 网页导航与窗口

BrowserModel 持有每个入口的主 WebView，BrowserRouter 向 AppModel 请求标签切换、呈现、下载和清理。

- 只有用户主动点击的主框架普通 GET 链接参与跨站切标签，每次均取消来源导航，不使用导致第二次放行的时间防抖。
- POST、表单重提、登录和服务端重定向保留原上下文；不把请求体重建成 GET。
- 子窗口使用 WebKit 提供的 WKWebViewConfiguration 创建，由原内核管理，保留 opener、postMessage 和 window.close。
- `blob:`、`data:`、`about:` 在 WebKit 内处理；受支持的系统 App scheme 仅在用户点击时交给系统。
- 外站普通链接按偏好留在当前网页、进入内置 Safari，或交给默认浏览器。网页菜单对两个浏览器出口分别命名；内部预览不能直接分享或外部打开时隐藏/禁用相应动作。
- 顶栏只显示可点击回主页的标题和更多菜单，网址、前后退与一级刷新已移除，菜单按钮至少 44×44 点。WebKitErrorDomain:102 的正常策略中断不显示网络错误。

KVO 值由安全的主线程桥接写入 Published 状态。WebViewContainer 使用稳定宿主重新挂载内核。网页进程被系统回收时显示重载入口，不无提示地刷新可能正在编辑的表单。

## 下载

AppModel 持有单个 DownloadCoordinator；WebKit 在原会话中处理下载请求，不另建会丢失 Cookie 的下载会话。Coordinator 强持有活动 WKDownload，观察 Progress，支持取消和服务器提供 resumeData 时的续传。断点数据仅留在进程内存，无法续传时给出打开来源站点的入口，不重放可能有副作用的 POST。

本机下载以 UUID 创建独立目录，文件名去除路径字符并按 UTF-8 字节限制长度，使用 complete 数据保护。默认位于 Documents/Downloads。索引迁入固定 Application Support/GTIITDownloads/index.json，兼容旧 Codable 记录和旧目录。选择外部位置后，任务捕获当时的目录授权书签，接收仍使用本机任务目录，完成后通过 NSFileCoordinator 在后台复制到授权目录；成功后移除本机中转。外部同名文件添加编号，使用本次独有的中转文件再移动，不覆盖其他文件。外部文件不参加自动保留期限清理，用户明确删除时只针对该记录文件。

目录使用系统文件夹选择器和持久授权书签；每条外部记录保留自己的位置引用，改变默认目录不迁移旧文件。目录失效明确失败，不静默回退。记录不保存源 URL、Cookie 或断点凭证。

Moodle 的 WKDownload 先交给 PDFPreviewCoordinator，依据响应 MIME／建议文件名识别 PDF；非 PDF 回交正常下载。PDF 接收至独立临时目录，PDFPreviewSession 持有加载、阅读、保存、成功及失败状态。PDFKit 校验并呈现实际文件，用户点击按钮才调用 savePreview 并生成正式记录；关闭后清理临时内容。仍使用原响应，POST／一次性链接不重放。

预览由独立 UIHostingController／QLPreviewController 呈现，不随 DownloadFloatingPanel 隐藏而消失。新窗口或菜单关闭的呈现过渡允许最多 2 秒就绪等待；重复点击打开同一批文件被合并。已存外部文件先在后台协调读取至临时预览副本，避免主线程等待 File Provider。下载管理提供列表／缩略图网格和三类双向排序，偏好使用 AppStorage 持久保存。

其他页面的 PDF 仍直接转下载，右下角 DownloadFloatingPanel 提供稳定预览与 UIDocumentPicker 另存入口。默认永久保存，限时清理为显式选项。完成面板 4 秒后渐隐，切页时收起；计时任务按任务标识取消，旧任务不会隐藏新任务的面板。清除站点登录会取消其活动下载，保留已完成文件；清理下载才删除本机副本。

## 原生班车与图标

ShuttleSchedule 的 58 个独立车次来自用户源表，按 Asia/Shanghai Calendar 计算，2 号车受教学周开关和指定星期约束。同一时间不同车辆保留独立 ID；过末班寻找次日，明确只做计划发车倒计时。ShuttleView 左右两列显示两个方向；TimelineView 每秒更新，numericText 遵循减弱动态效果。AppIcon.icon 包含透明校徽改绘层和背景填充，由 Apple actool 统一编译 Liquid Glass；备用 PNG 无预制角蒙版。

## 本地锁与后台遮挡

AppLockController 通过 SystemAuthenticator 使用 LocalAuthentication 的 deviceOwnerAuthentication，支持生物识别与设备密码。失败、取消或暂不可用时保持锁定；AppModel 转发锁变化，以同步触控和辅助功能状态。

PrivacyShieldController 使用独立的高层 UIWindow，覆盖 App 自己的 Safari、分享和网页窗口。进入 inactive/background 时先遮挡；返回后按 0/60/300 秒阈值决定是否认证。系统认证引起的短暂 inactive 不会重复启动新锁定周期。锁定仅保护本机界面，不参与学校认证。

## 网络诊断与页面恢复

NetworkDiagnostics 使用 ephemeral URLSession，显式关闭 Cookie、URL 缓存和重定向，向公开首页发 HEAD；结果只证明服务器有无响应。摘要不包含完整 URL、账号、Cookie 或网页内容。

恢复页面只保存同站普通 HTTPS 地址：排除查询、片段、认证/表单等路径，以及其他来源。不跨启动保存草稿或滚动位置。

## 验证

Tests 和 Tools 提供独立测试入口，不进入产品 Sources。回归运行于独立测试 App 和可丢弃模拟器，覆盖真实 WebKit 行为、合成 Cookie 隔离、实际缓存命中/清理、下载及隐私状态。认证状态用可注入接口测试，生产入口固定使用系统认证。

参考 Apple 官方设计与接口说明：[Settings](https://developer.apple.com/design/human-interface-guidelines/settings)、[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)、[WKUIDelegate 子窗口](https://developer.apple.com/documentation/webkit/wkuidelegate/webview(_:createwebviewwith:for:windowfeatures:))。最新验证范围与限制见 `RELEASE-1.2.md`；1.1 记录保留在 `IMPROVEMENTS-20261021.md`。
