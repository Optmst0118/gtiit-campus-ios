# QA 复核的处置记录

- 复核报告：[QA-REPORT.md](QA-REPORT.md)（P0=0 / P1=2 / P2=16 / P3=11）
- 处置日期：2026-10-21
- 处置人：Lead
- 说明：修复后重新通过 `swiftc -typecheck -warnings-as-errors`（0 error / 0 warning）、`-c -whole-module-optimization` 完整编译、`Tools/check_project.py` 工程结构校验。

## P1

| ID | 处置 | 位置 | 说明 |
|---|---|---|---|
| QA-01 缺隐私清单 | ✅ 已修 | `GTIIT/Resources/PrivacyInfo.xcprivacy` | 声明 `NSPrivacyTracking=false`、不收集数据，`NSPrivacyAccessedAPITypes` 仅 UserDefaults（CA92.1）；已由生成器加入 Resources 编译阶段 |
| QA-02 左滑清除无确认 | ✅ 已修 | `Views/MyTabView.swift` | 左滑「清除」改为置 `pendingClearSite` 后弹 `confirmationDialog`，与浏览器菜单/说明卡一致 |

## P2

| ID | 处置 | 位置 | 说明 |
|---|---|---|---|
| QA-03 确认前已加载网页 | ✅ 已修 | `Views/RootTabView.swift` | `tabContent` 增加 `settings.hasSeenWelcome` 条件：勾选确认后才创建 WebView |
| QA-04 Release 定义 DEBUG | ✅ 已修 | `Tools/gen_project.py` | `SWIFT_ACTIVE_COMPILATION_CONDITIONS` 移入 Debug 配置并重新生成工程；Release 不再定义 DEBUG，`isInspectable` 不进生产包 |
| QA-05 跨站路由抖动 | ✅ 已修 | `Services/BrowserModel.swift` | 只对 `.linkActivated/.formSubmitted/.formResubmitted` 路由，服务端 3xx（`.other`）留在原 WebView；同一 URL 3 秒去重 |
| QA-06 window.open 被压平 | ⏸ 接受（已记录） | `Services/BrowserModel.swift` | 保留「新窗口在主 WebView 打开」的兜底策略（对学校 SSO 最稳）；依赖 window 句柄的 OAuth 弹窗需真机回归，见「残余风险」 |
| QA-07 KVO 硬崩风险 | ✅ 已修 | `Services/BrowserModel.swift` | 新增 `onMain`：主线程同步写回，非主线程异步回主队列，不再无保护调用 `assumeIsolated` |
| QA-08 WebView 重挂载脆弱 | ✅ 已修 | `Components/WebViewContainer.swift` | 引入 `WebViewHostView` 稳定容器，`updateUIView` 负责 `host(_:)`，不再把裸 WKWebView 当 representable 根视图 |
| QA-09 body 内创建 WebView | ⏸ 接受（已记录） | `Views/SiteBrowserView.swift` | 当前为 `app.browser(for:)` 字典缓存 + 每站单例，不会重复创建或循环；改成 `.task` 会在分段切换时闪占位图，暂不改动 |
| QA-10 Swift 6 前瞻兼容 | ◑ 部分修 | `Core/TopViewController.swift` | `TopViewController` 已标 `@MainActor`；`WKDownloadDelegate` 的 completion 在 Swift 6 模式下需 `@MainActor @Sendable`，当前工程 `SWIFT_VERSION=5.0`，升级 Swift 6 时再处理 |
| QA-11 状态文案被截断 | ✅ 已修 | `Views/MyTabView.swift` | 行内改为「本机有网页数据（不代表已登录）」/「本机无网页数据」，「不代表已登录」移到 section footer |
| QA-12 ATS 放行面过大 | ⏸ 接受（已记录） | `GTIIT/Info.plist` | 保留 `NSAllowsArbitraryLoadsInWebContent`（仅 Web 内容，不是全 App）：校园门户常见 http 内链与重定向，作为浏览器容器需要渲染官方页面本身；无自建网络请求，App 侧仍只走 https |
| QA-13 相机/麦克风缺失 | ✅ 已修 | `Services/BrowserModel.swift` | 实现 `requestMediaCapturePermissionFor` 并一律 `.deny` + 提示，避免缺 usage string 被系统终止；不新增相机/麦克风采集能力 |
| QA-14 动态字体截断 | ◑ 部分修 | `Views/BookingTabView.swift` | 分段说明由 1 行改为 2 行 + 最小缩放；header 保持固定高度以留出网页空间，辅助功能超大字号仍是已知取舍 |
| QA-15 锁屏时机/无障碍 | ✅ 已修 | `Views/RootTabView.swift` | `.inactive` 即上锁（覆盖切换器快照）；锁定时对 TabView 关闭 `accessibilityHidden` 与命中测试 |
| QA-16 硬编码课程 ID | ✅ 已修 | `Models/QuickLink.swift` | 删除 `course/view.php?id=81/149` 两条固定入口 |
| QA-17 无 DEVELOPMENT_TEAM | ⏸ 接受（设计如此） | `GTIIT.xcodeproj` | 模板不写死签名团队；README「快速开始」第 1 步要求选自己的 Team |
| QA-18 两个模态同宿主 | ⏸ 接受（已记录） | `Views/RootTabView.swift` | 欢迎页（首次启动）与站点说明（浏览中）在交互上互斥，不会同时置位；若后续新增入口再收敛为单一 enum 驱动 |

## P3 顺手处理

- `AboutView` 隐私分条补全：下载临时文件、生物识别由 iOS 校验、UserDefaults 实际键（含 4 个数据容器 UUID）、隐私清单声明；
- 删除未使用 API：`AppModel.hasLoaded`、`AppModel.open(url:in:)`；
- 每次启动清理上一次的下载临时目录（不读取文件时间戳，避免新增 required-reason API）；
- 欢迎页主按钮改为「我已了解，开始使用」，并增加「查看完整说明与隐私」次按钮；
- Moodle 自定义课表/服务空间不再写死课程实例 ID，改为从「我的课程」进入后在官方页内导航。

## 运行期验证补充（2026-10-21 15:00 后）

Xcode 许可证已同意，完成真机与模拟器运行验证：

- `xcodebuild` 模拟器构建 **BUILD SUCCEEDED**；iPhone 17 / iOS 26.5 上四站真实加载（门户跳转 Microsoft 登录、Moodle 登录、Booked 登录）；
- 真机 iPhone Air / iOS 27.0.1：`-allowProvisioningUpdates` 自动生成 iOS Team Provisioning Profile（team YOUR_TEAM_ID，7 天有效），`devicectl` 安装并启动成功，WebContent 进程正常；
- 修复 WebView 底部内容被 iOS 26 浮动 Tab 栏遮挡的问题（`contentInsetAdjustmentBehavior = .automatic`）。

## 仍然残留（需上架前处理）

1. ~~无法运行~~：已解决（见上）。
2. **SSO 弹窗**：Microsoft / Moodle SAML2 的 `window.open` 流程需真机回归。
3. **跨站回跳**：服务端重定向已不参与路由，但真机上仍建议验证 A↔B 跳转。
4. **商标与上架**：App 名称使用学校缩写，发布前需确认授权或改用中性名称（见 QA 报告 §4.3）。
5. **Swift 6**：未来升级到 Swift 6 语言模式时需处理 `WKDownloadDelegate` 的 `@MainActor @Sendable` 签名。