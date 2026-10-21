# 架构说明 · 1.1

## 应用与界面

`GTIITApp` 创建共享的 `AppSettings` 和 `AppModel`。设置保存在本机 UserDefaults；外观即时生效，启动标签和默认预约分类在下次启动使用。`RootTabView` 首次进入标签时才创建网页，首次引导完成前不创建网页内核。

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
- 浏览栏不使用与真实 TLS 状态无关的锁图标。所有导航按钮至少 44×44 点，辅助功能字号下把次要动作收进菜单。

KVO 值由安全的主线程桥接写入 Published 状态。WebViewContainer 使用稳定宿主重新挂载内核。网页进程被系统回收时显示重载入口，不无提示地刷新可能正在编辑的表单。

## 下载

AppModel 持有单个 DownloadCoordinator；WebKit 在原会话中处理下载请求，不另建会丢失 Cookie 的下载会话。Coordinator 强持有活动 WKDownload，观察 Progress，支持取消和服务器提供 resumeData 时的续传。断点数据仅留在进程内存，无法续传时给出打开来源站点的入口，不重放可能有副作用的 POST。

每个任务以 UUID 创建独立目录，因此同名文件不会竞争路径。文件名去除路径字符并按 UTF-8 字节限制长度。文件使用 complete 数据保护，位于 App 缓存目录；元数据只含任务标识、站点、文件名、状态、大小和创建时间，不保存下载请求 URL、Cookie 或断点凭证。

文件可通过系统分享面板保存到“文件”。默认下次启动清理，也可选择 1 天或 7 天；系统可能提前回收。清除站点登录会取消其活动下载，保留已完成的文件；清理下载则停止任务并删除缓存副本。

## 本地锁与后台遮挡

AppLockController 通过 SystemAuthenticator 使用 LocalAuthentication 的 deviceOwnerAuthentication，支持生物识别与设备密码。失败、取消或暂不可用时保持锁定；AppModel 转发锁变化，以同步触控和辅助功能状态。

PrivacyShieldController 使用独立的高层 UIWindow，覆盖 App 自己的 Safari、分享和网页窗口。进入 inactive/background 时先遮挡；返回后按 0/60/300 秒阈值决定是否认证。系统认证引起的短暂 inactive 不会重复启动新锁定周期。锁定仅保护本机界面，不参与学校认证。

## 网络诊断与页面恢复

NetworkDiagnostics 使用 ephemeral URLSession，显式关闭 Cookie、URL 缓存和重定向，向公开首页发 HEAD；结果只证明服务器有无响应。摘要不包含完整 URL、账号、Cookie 或网页内容。

恢复页面只保存同站普通 HTTPS 地址：排除查询、片段、认证/表单等路径，以及其他来源。不跨启动保存草稿或滚动位置。

## 验证

Tests 和 Tools 提供独立测试入口，不进入产品 Sources。回归运行于独立测试 App 和可丢弃模拟器，覆盖真实 WebKit 行为、合成 Cookie 隔离、实际缓存命中/清理、下载及隐私状态。认证状态用可注入接口测试，生产入口固定使用系统认证。

参考 Apple 官方设计与接口说明：[Settings](https://developer.apple.com/design/human-interface-guidelines/settings)、[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)、[WKUIDelegate 子窗口](https://developer.apple.com/documentation/webkit/wkuidelegate/webview(_:createwebviewwith:for:windowfeatures:))。最终验证范围和外部限制见 `IMPROVEMENTS-20261021.md`。
