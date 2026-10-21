# 架构说明

## 1. 分层

```
┌──────────────────────────────────────────────────────────────┐
│ 界面层  RootTabView / SiteBrowserView / BookingTabView /     │
│         MyTabView / WelcomeView / SiteInfoView / AboutView   │
│         （原生铬只管导航与状态，不重画网页内容）              │
├──────────────────────────────────────────────────────────────┤
│ 应用状态  AppModel（Tab、Toast、站点注册表、外部呈现）        │
│          AppSettings（UserDefaults） AppLockController        │
├──────────────────────────────────────────────────────────────┤
│ 网页内核  BrowserModel（每站一个）                            │
│          WKWebView + navigationDelegate + uiDelegate          │
│          + KVO 状态 + 下载协调器                              │
├──────────────────────────────────────────────────────────────┤
│ 基础设施  WebDataStoreRegistry（每站独立持久化容器）          │
│          DownloadCoordinator / TopViewController              │
├──────────────────────────────────────────────────────────────┤
│ 站点定义  SiteID / AppTab / QuickLinkCatalog（只有数据，无 IO）│
└──────────────────────────────────────────────────────────────┘
```

没有网络层之外的第三方依赖：不引入 Alamofire、不引入统计 SDK、不引入 JS bridge 框架。

## 2. 关键决策

### 2.1 为什么不是一个 WKWebView 到处跳

四个站点是完全不同的应用（门户是 SPA + 统一身份认证，Moodle 是 PHP 服务端渲染 + SAML2，Booked 是 PHP 传统表单，mike-x 是第三方预约）。合成一个 WebView 会导致：

- Cookie 互相污染，退出一个站影响其他站；
- 后退栈混在一起，用户无法回到"上一个标签的上一页"；
- 跨站单点跳转会丢掉当前页面状态。

因此每站一个 `WKWebView` + 一个 `WKWebsiteDataStore`，Tab 只是切换显示哪一个。

### 2.2 会话隔离与 iOS 17

`WKWebsiteDataStore(forIdentifier: UUID)` 是 WebKit 从 iOS 17 起提供的"持久化带标识数据容器"。App 为四个站点各生成一个 UUID 存在 UserDefaults，之后每次启动都用同一标识取容器，实现「四站会话各自保留、互不可见、可单独清除」。这也是最低系统版本定为 iOS 17 的唯一硬性理由。

```swift
// WebDataStoreRegistry
let store = WKWebsiteDataStore(forIdentifier: identifier(for: site))
```

### 2.3 跨站路由

```
用户点击链接
   │
   ├─ http(s) 且 host 命中另一个已知站点 ──► AppModel.switchTo(target) + target.load(url)
   │                                        （当前 WebView 取消这次导航）
   ├─ target=_blank / window.open ──► 同一 WebView 内加载（保住 SSO 流程）
   ├─ 其他 http(s) ────────────────► 当前 WebView 正常导航
   └─ 非 http(s)（tel/mailto/…）───► 系统 App
```

站点匹配用**精确 host + 别名后缀**（`students.gtiit.edu.cn` / `moodle.gtiit.edu.cn` / `roombooking.gtiit.edu.cn` / `gtiit.mike-x.com`），不用 `gtiit.edu.cn` 后缀，避免三个子域被当成同一个站点。

### 2.4 状态流

```
WKWebView ──KVO──► BrowserModel(@Published) ──► SwiftUI 视图刷新
   ▲                      │
   └── load/reload/clear ─┘
```

KVO 回调（title/url/estimatedProgress/isLoading/canGoBack/canGoForward）由 WebKit 在主线程投递，闭包里用 `MainActor.assumeIsolated` 同步写回 `@Published`，避免 actor hop 造成进度条回跳。

### 2.5 生命周期

- `AppModel` 持有 `[SiteID: BrowserModel]`，同一个站点永远只有一个 WebView；
- `RootTabView` 用 `visitedTabs` 做懒加载：第一次切到某 Tab 才创建内核（冷启动只打门户）；
- `BookingTabView` 在两套预约系统之间切换时，只把另一个 WebView 从视图树摘下，实例仍在 AppModel 里，切回来滚动位置不丢；
- `WebViewContainer` 返回稳定的 `WebViewHostView` 容器：WKWebView 在容器内挂载/重挂载，SwiftUI 从不直接持有 WKWebView，避免 UIView 跨 representable 复用导致白屏。

### 2.6 错误语义

| 情况 | 展示 |
|---|---|
| 首次加载未完成 | 站点徽标 + 转圈 + host |
| `NSURLErrorNotConnectedToInternet` | 没有可用网络… |
| `NSURLErrorCannotFindHost` / DNS | 无法解析域名，说明校园网前提 |
| `NSURLErrorTimedOut` | 连接超时 |
| 证书错误 | 安全连接未建立，不绕过校验 |
| Web 内容进程被回收 | 提示并自动重载 |

错误页始终提供「重试 / 回到首页 / 在 Safari 中打开」三个出口。

### 2.6.1 首次启动门禁

`tabContent` 同时检查 `visitedTabs` 与 `settings.hasSeenWelcome`：在用户勾选「我已阅读并了解」之前，不会创建任何 WebView，也不会发起任何校园站点请求。

### 2.7 下载

`WKNavigationAction.shouldPerformDownload`、`navigationResponse.canShowMIMEType == false`、以及 `didBecome download` 三条路径都交给 `DownloadCoordinator`：临时目录落盘 → `UIActivityViewController` 分享 → 提示文件名。**不建立持久下载库**，避免在 App 内复制学校资料。

### 2.8 隐私与安全

- 唯一的本地持久化：4 个站点容器 UUID、`hasSeenWelcome`、`biometricLockEnabled`；
- 没有账号密码字段，没有任何自建网络请求；
- ATS 只开放 `NSAllowsArbitraryLoadsInWebContent`（网页内容），不放开 App 自身请求；
- `WKWebView.isInspectable` 仅在 DEBUG 打开（Release 配置不再定义 DEBUG）；
- App 锁使用 `LocalAuthentication` 的 `deviceOwnerAuthentication`，只做界面遮挡；
- 网页请求摄像头/麦克风时一律 `.deny` 并提示，App 不新增采集能力；
- `Resources/PrivacyInfo.xcprivacy` 声明不追踪、不收集，仅 UserDefaults（CA92.1）。

## 3. 时序：一次跨站跳转

```
Moodle WebView            BrowserModel(moodle)        AppModel               BrowserModel(portal)
     │ 用户点 students.gtiit.edu.cn/grades
     │──────────────────────────►│
     │                    decidePolicyFor
     │                           │── browserRouteToOtherSite ──►│
     │                           │                              │ switchTo(.portal)
     │                           │                              │ selectedTab = .portal
     │                           │                              │ browser(for:.portal).load(url)
     │◄── decision(.cancel) ─────│                              │──────────────►│
     │                           │                              │       网页开始加载
```

## 4. 与研究的对应关系

| 研究结论 | 落到代码 |
|---|---|
| 四站独立凭据、不能"一次登录全通" | 每站独立 `WKWebsiteDataStore` |
| Booked API 关闭 | 不做原生预约，只做容器 + 资源深链 |
| Moodle 登录只到浏览器 | 不做原生令牌，保留官方网页与日历导出入口 |
| 门户 Code of Conduct | 不代替用户同意，只在说明卡提示 |
| 加载中 ≠ 无记录 | 首次加载显示占位，不提前显示"暂无数据" |
| 不承诺后台推送 | 没有 BackgroundTasks / APNs |
| App Store 4.2 最低功能 | 原生导航、会话管理、深链、下载、锁、说明页构成实际功能增量 |

## 5. 未来扩展点（尚未实现）

- Moodle 只读 web service 验证通过后，可在「学习」Tab 增加原生的截止列表（需要自有回调 + 服务端允许函数）；
- 官方日历导出链接可做「手动导入」到本地日历（研究已列为候选替代路线）；
- 本地手动日程与提醒（不依赖学校接口）；
- iPad 侧边栏 / 多窗口（注意四个 WebView 的内存）。