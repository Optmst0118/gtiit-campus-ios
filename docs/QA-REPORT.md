# GTIIT iOS App 独立 QA 报告

- 复核人：qa-verifier（独立于实现方）
- 日期：2026-10-21
- 复核对象：`GTIIT-iOS-App`（GTIIT.xcodeproj / GTIIT/ 共 24 个 Swift 文件 / docs/RESEARCH-SPEC.md）
- 复核方式：只读源码 + 静态验证（swiftc typecheck/parse/链接、工程文件解析、plist/资产校验、代码审查）
- 约束遵守：未修改 `GTIIT/` 下任何文件，未改 pbxproj，未运行 `Tools/gen_project.py`；未使用 sudo、未绕过 Xcode license；唯一写入为 `docs/QA-REPORT.md`（临时脚本均放在 `/tmp` 与 `$WD/.cache`）。

---

## 0. 结论速览

| 项目 | 结论 |
|---|---|
| 源码可编译性 | **PASS**：`swiftc -typecheck` exit 0、`-warnings-as-errors` exit 0、`-parse` exit 0，`-emit-executable` 完整编译+链接 exit 0 |
| 完整 Xcode 构建 | **未验证**：`xcodebuild` / `actool` 均被 Xcode license 阻断（exit 69），按要求未用 sudo 绕过 |
| 工程结构 | **PASS**：objectVersion 56、target/product/scheme 自洽；24/24 Swift 文件全部在 Sources phase；27 个 fileRef 全部在磁盘存在；UUID 无重复；必要 build settings 齐全 |
| 资源 | **PASS**：Assets.xcassets 三份 Contents.json 合法；AppIcon 1024×1024、colorType=2（无 alpha）、`platform=ios`；LaunchBackground 有亮/暗两套 |
| 缺陷统计 | **P0 = 0，P1 = 2，P2 = 16，P3 = 11**（P3 为汇总清单，不逐行列表） |
| A4 四项差异 | **全部已修**（#3 有按钮文案的小偏差）；补充核对：#5 已修、#6/#7 部分修、#8 保留 |
| 交付判断 | **可交付（源码/工程层面）**；提审前必须处理 2 个 P1 与 Release DEBUG 配置，其余为健壮性/体验/上架合规项 |

> 说明：任务描述称“25 个 Swift 文件”，经磁盘与 pbxproj 双向核对实际为 **24 个**（App 4、Components 2、Core 3、Models 3、Services 4、Views 8）。以实际 24 个为准。

---

## 1. 环境与限制

| 项 | 值 |
|---|---|
| Xcode | 27.1（27A9275） |
| Swift | Apple Swift version 6.4（swiftlang-6.4.0.34.1） |
| SDK | iphonesimulator27.1（Simulator - iOS 27.1） |
| 部署目标 | iOS 17.0 |
| 可用的替代验证 | swiftc 直接 typecheck / parse / emit-executable |
| 被阻断的验证 | xcodebuild（license）、actool（license）、真机/模拟器运行 |

**复核限制（重要）**：本报告所有运行时行为结论均为**静态推演**，未在真机或模拟器上执行 App。涉及 WebKit KVO 线程、UIViewRepresentable 重挂载、SSO 弹窗/重定向、系统文件选择器等运行时假设，均列入第 6 节残余风险。

---

## 2. 复现命令与输出节选

以下命令均在 App 根目录（`GTIIT-iOS-App`）执行；`WD` 为工作区根目录。

### 2.1 基础 typecheck（Lead 报告的独立复现）

```bash
WD=$PROJECT_ROOT
SW=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
SDK=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
mkdir -p $WD/.cache/tmp $WD/.cache/modules
TMPDIR=$WD/.cache/tmp $SW -typecheck -swift-version 5 -sdk "$SDK" \
  -target arm64-apple-ios17.0-simulator -module-cache-path $WD/.cache/modules \
  $(find GTIIT -name '*.swift')
echo "EXIT=$?"
```

输出：`EXIT=0`（无任何 error/warning）。**与 Lead 的说法一致。**

### 2.2 更严格参数

| 命令 | 结果 |
|---|---|
| 追加 `-warnings-as-errors`（swift-version 5） | **exit 0，0 warning**（可作为“无警告”证据） |
| `-parse`（仅语法） | **exit 0** |
| `-swift-version 6` | **exit 1**：1 个真实 error（另 1 条从属诊断）+ 18 条 warning 行（去重后 9 条） |
| `-swift-version 5 -strict-concurrency=complete` | **exit 1**：同一个 error |

swift-version 6 的关键报错：

```text
GTIIT/Services/DownloadCoordinator.swift:8:13: error: type 'DownloadCoordinator'
  does not conform to protocol 'WKDownloadDelegate'
  note: candidate has non-matching type '(WKDownload, URLResponse, String,
        @escaping (URL?) -> Void) -> ()'
  note: protocol requires function 'download(_:decideDestinationUsing:suggestedFilename:)'
        with type '(... @escaping @MainActor @Sendable (URL?) -> Void) -> Void'
```

warning 全部集中在 `GTIIT/Core/TopViewController.swift`（`UIApplication.shared`、`connectedScenes`、`windows`、`isKeyWindow`、`rootViewController`、`presentedViewController` 均为主线程隔离属性，被非隔离上下文引用）。

**结论**：项目 `SWIFT_VERSION = 5.0`（pbxproj:385/409），当前工具链下 Swift 5 模式**可编译**；但 Swift 6 / 严格并发模式**不通过**，属于向前兼容风险（见 QA-10）。

### 2.3 完整编译 + 链接（比 typecheck 更强）

```bash
TMPDIR=$WD/.cache/tmp $SW -emit-executable -swift-version 5 -sdk "$SDK" \
  -target arm64-apple-ios17.0-simulator -module-cache-path $WD/.cache/modules \
  -o /tmp/qa-build/GTIIT $(find GTIIT -name '*.swift')
```

输出：`link exit=0`，产物 `Mach-O 64-bit executable arm64`；`otool -L` 显示已自动链接
`WebKit`、`SwiftUI`、`UIKit`、`LocalAuthentication`、`SafariServices`、`Combine`；
`LC_BUILD_VERSION minos 17.0`。说明 Frameworks build phase 为空不影响构建（Swift autolink 生效），且部署目标生效。

### 2.4 Xcode 构建（按环境事实，不绕过）

```bash
xcodebuild -project GTIIT.xcodeproj -scheme GTIIT -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' build
# exit=69
# You have not agreed to the Xcode license agreements. Please run
# 'sudo xcodebuild -license' ...
```

同样，`xcrun actool GTIIT/Resources/Assets.xcassets ...` 也被 license 阻断（exit 69）。
**未尝试 sudo，也未采用任何绕过手段。**

### 2.5 plist / 工程 / 资源校验

```text
plutil -lint GTIIT.xcodeproj/project.pbxproj   -> OK (exit 0)
plutil -lint GTIIT/Info.plist                  -> OK (exit 0)
```

Python（标准库自写 OpenStep 解析器，`$WD/.cache/qa_pbxproj.py`）+ 资产脚本结果：

```text
objectVersion: 56
rootObject -> PBXProject（mainGroup 可解析）
top-level object defs: 73, unique: 73, dups: []
isa: PBXBuildFile 25, PBXFileReference 27, PBXGroup 10, PBXNativeTarget 1, PBXProject 1,
     PBXSourcesBuildPhase 1, PBXFrameworksBuildPhase 1, PBXResourcesBuildPhase 1,
     XCBuildConfiguration 4, XCConfigurationList 2
PBXFileReference 缺失磁盘: []
未被 group 引用的 fileRef: []
PBXBuildFile 引用无效: []
buildPhase 引用无效: []
25 个 PBXBuildFile 全部被某个 buildPhase 使用
Sources phase: 24 条 / 磁盘 .swift 24 个；phase 缺文件=[]，磁盘缺 phase=[]，重复=[]
Resources phase: Assets.xcassets
target: GTIIT / com.apple.product-type.application / product = GTIIT.app
Debug/Release: IPHONEOS_DEPLOYMENT_TARGET=17.0, PRODUCT_BUNDLE_IDENTIFIER=io.github.optmst0118.gtiit,
  INFOPLIST_FILE=GTIIT/Info.plist（存在）, ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon,
  GENERATE_INFOPLIST_FILE=NO, SWIFT_VERSION=5.0, TARGETED_DEVICE_FAMILY=1,2
scheme: 3 处 BlueprintIdentifier = E3435DDA2687639586BF0B70 = target UUID ✓；BuildableName=GTIIT.app ✓
```

> 注：初版脚本用正则把 `TargetAttributes` 里的 target UUID 误计为“重复定义”；改用“顶层 objects 定义位置”重新统计后为 **73/73 无重复**。

资产：

```text
AppIcon.appiconset/Contents.json: images=[universal, platform=ios, 1024x1024, AppIcon.png]
AppIcon.png: 1024x1024, bitdepth 8, colorType 2 (RGB, 无 alpha), 无 tRNS
AccentColor / LaunchBackground(亮+暗) Contents.json: JSON 合法
```

### 2.6 iOS 17 API 可用性实测

对同一测试片段分别以 iOS 16.0 与 iOS 17.0 为目标 typecheck：

```text
-target arm64-apple-ios16.0-simulator:
  error: 'init(forIdentifier:)' is only available in iOS 17.0 or newer
-target arm64-apple-ios17.0-simulator:
  exit 0
```

同时 SDK 头文件确认 `WKWebsiteDataStore` 的
`+dataStoreForIdentifier:` / `identifier` 均为 `API_AVAILABLE(ios(17.0))`。
`MainActor.assumeIsolated` 在 iOS 16 目标下也不报可用性错误，因此它不是 iOS 17 才有的 API。

### 2.7 代码审计 grep（全部 0 命中）

`evaluateJavaScript / WKUserScript / userContentController / addUserScript`、
`URLSession / Analytics / Crashlytics / Firebase / os_log / print(`、
`runOpenPanel / FilePicker / UIDocumentPicker / fileImporter`、
`requestMediaCapturePermission / AVCapture / UIImagePicker`、
`transcripts`、`2026-12-21`、`继续使用即表示`、`已同步 / 实时更新`、
`#available / @available`、`NotificationCenter / DispatchQueue / Combine.sink`。

说明：无脚本注入、无第三方统计/网络代码、无日期写死、无默示同意文案、无手写 `@available`。

---

## 3. 结论式摘要表（P0 / P1 / P2）

| ID | 严重度 | 位置（file:line） | 问题 | 建议修复 |
|---|---|---|---|---|
| QA-01 | **P1** | 工程根无 `PrivacyInfo.xcprivacy`；`GTIIT/App/AppSettings.swift:12`、`GTIIT/Services/WebDataStoreRegistry.swift:14` | 使用 `UserDefaults`（Apple required-reason API），但工程没有任何隐私清单；2024-05 起提交 App Store 需声明访问理由，缺失会收到警告/有被拒风险 | 新增 `GTIIT/PrivacyInfo.xcprivacy`：`NSPrivacyTracking=false`、采集类型为空、`NSPrivacyAccessedAPITypes` 声明 `NSPrivacyAccessedAPICategoryUserDefaults`（理由 CA92.1）；通过 `Tools/gen_project.py` 加入 Resources phase |
| QA-02 | **P1** | `GTIIT/Views/MyTabView.swift:163-168` | 「我的」站点行左滑「清除」直接 `app.clearData(for:)`，**无二次确认**，会立刻清空该站 Cookie/缓存/登录态；同一操作在浏览器菜单（`SiteBrowserView.swift:26-37`）和说明卡（`SiteInfoView.swift:78-103`）都有确认；违反规格 F.2「按站点确认」 | 滑动按钮只置 `pendingClearSite`，复用 `confirmationDialog` 确认后再清 |
| QA-03 | P2 | `GTIIT/App/AppModel.swift:10,24-29`；`GTIIT/Views/SiteBrowserView.swift:9`；`GTIIT/Views/RootTabView.swift:43-49` | `visitedTabs` 初始含 `.portal`，首帧 body 即创建门户 `BrowserModel` 并 `loadHome()`；欢迎页（fullScreenCover）是随后才出现 → **用户确认免责声明前门户网页已开始加载**，与 F.5「必须点确认才加载网页」不符 | 初始 `visitedTabs` 置空，或 `tabContent` 在 `!settings.hasSeenWelcome` 时返回占位；欢迎页关闭后再创建 WebView |
| QA-04 | P2 | `GTIIT.xcodeproj/project.pbxproj:355`（根因 `Tools/gen_project.py:138`）；`GTIIT/Services/BrowserModel.swift:55-57` | Release 的 project 级配置仍为 `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)"`，导致 Release 也定义 `DEBUG`：`webView.isInspectable = true` 等调试代码会进生产包，后续 DEBUG-only 代码同样会泄漏 | 把该行从 `common_project_settings` 移到 `debug_project_settings`；用修好的生成器重建工程（本次未运行生成器） |
| QA-05 | P2 | `GTIIT/Services/BrowserModel.swift:261-272`；`GTIIT/App/AppModel.swift:119-127` | 所有主框架 http(s) 导航都参与跨站路由，未区分用户点击与服务器 3xx；若 A 站重定向到 B、B 又重定向回 A（或 SSO 回跳），两个 WebView 会互相 `load`+`cancel` 抖动，无冷却/去重 | 仅对 `navigationAction.navigationType` 为用户触发时才跨 Tab；服务端重定向留在原 WebView；增加同 URL 对短时间去重 |
| QA-06 | P2 | `GTIIT/Services/BrowserModel.swift:303-317` | `createWebViewWith` 一律 `return nil` 并把新窗口 URL 塞回同一 WebView。依赖 `window.open` 句柄 + `postMessage` 的 SSO/OAuth 弹窗会拿不到 window、流程可能卡住 | 保留同一 WebView 作为兜底，但对已知 SSO 弹窗提供独立 WKWebView 或至少提示；真机回归 Microsoft/Moodle 登录 |
| QA-07 | P2 | `GTIIT/Services/BrowserModel.swift:141-176`（6 处） | KVO 闭包用 `MainActor.assumeIsolated`。WebKit 并未在 API 契约中保证 KVO 一定在主线程；一旦某次通知落在非主线程，`assumeIsolated` 触发 precondition → **直接崩溃**（Release 同样生效） | 改为 `Task { @MainActor in ... }` / `DispatchQueue.main.async`，或先 `MainActor.preconditionIsolated` 再降级处理，避免硬崩 |
| QA-08 | P2 | `GTIIT/Components/WebViewContainer.swift:9-14`；`GTIIT/Views/BookingTabView.swift:11-16` | `makeUIView` 把同一个 WKWebView 从旧父视图 `removeFromSuperview` 后返回，且未实现 `dismantleUIView`。当前“每站一个 model + 分段切换不同 site”使其可用，但把共享 UIView 跨 representable 重挂载，若 SwiftUI 复用/二次 makeUIView，可能把 WebView 从仍存活的容器摘走 → 白屏/闪断 | 用稳定容器 UIView：`makeUIView` 返回容器，`updateUIView` 里 addSubview/约束；或四站 ZStack 常驻 + opacity/hitTesting 切换 |
| QA-09 | P2 | `GTIIT/App/AppModel.swift:24-29`；`GTIIT/Views/SiteBrowserView.swift:9` | 在 SwiftUI `body` 中调用 `app.browser(for:)` 会创建 WKWebView、启动网络、注册 KVO（body 副作用）。因为 `browsers` 不是 @Published、新 model 尚无观察者，**不会**触发 “Modifying state during view update”，字典缓存也避免重复创建/循环；但首帧卡顿、行为依赖求值顺序，且将来若清理 `browsers` UI 不会感知 | 在 `AppModel.init` 预建或 `.task`/onAppear 中建；模型字典改为可观察或用每 Tab 的 `@StateObject` |
| QA-10 | P2 | `GTIIT/Services/DownloadCoordinator.swift:8,14-19`；`GTIIT/Core/TopViewController.swift:3-16`；`pbxproj:385/409` | Swift 6 模式（以及 `-strict-concurrency=complete`）**编译失败**：`WKDownloadDelegate` 的 completion handler 在新 SDK 要求 `@MainActor @Sendable`；`TopViewController` 未标 `@MainActor` 产生 9 条隔离 warning。当前 `SWIFT_VERSION=5.0` 可编，但 Xcode 27 新工程/升级后是隐患 | completion 参数改为 `@escaping @MainActor @Sendable (URL?) -> Void`（或 conformance 标 `@preconcurrency`）；`enum TopViewController` 标 `@MainActor` |
| QA-11 | P2 | `GTIIT/Views/MyTabView.swift:148-151,179-182` | 站点状态文案为 `host · 本机已保存网页数据（不代表已登录）`（约 30+ 字），却用 `.lineLimit(1)` 放在约 250–290pt 宽的行内 → 会被省略号截断，**恰好截掉「不代表已登录」**，弱化了规格要求的“缓存≠登录”提示 | 把「不代表已登录」前置、缩短文案、允许 2 行，或只在 section footer 说明 |
| QA-12 | P2 | `GTIIT/Info.plist:58-62`；对照 `SiteID.swift:38-42`、`QuickLink.swift:30-70` | `NSAllowsArbitraryLoadsInWebContent=true` 全量放行 WebView 的 http 内容，但四站首页与全部快捷入口均为 https，没有 http 需求；放行面过大且增加 App Review 对 ATS 例外的问询 | 删除该键；若确有 http 校园页，只对具体域名加 `NSExceptionDomains`，不要用 InWebContent 全量开关 |
| QA-13 | P2 | `GTIIT/Info.plist:54-55`（只有 Face ID）；`BrowserModel.swift:302-374`（未实现媒体授权） | WKUIDelegate 未实现 `requestMediaCapturePermissionFor...`，按 SDK 头注释默认行为是 `.prompt`；而 Info.plist 没有 `NSCameraUsageDescription` / `NSMicrophoneUsageDescription`。若 Moodle 等页面调用 `getUserMedia`（录音/录像作业），iOS 可能因缺 usage string 终止 App | 补两条 usage description，或实现 delegate 明确 `.deny` 并提示；同步更新隐私文案 |
| QA-14 | P2 | `GTIIT/Core/Theme.swift:12`；`SiteBrowserView.swift:50,63,84`；`BookingTabView.swift:29-33`；`WelcomeView.swift:57-59,128-167` | header 固定 46pt + 固定 13/10pt 字号（不随动态字体缩放）；预约分段下方说明 `.lineLimit(1)` + `minimumScaleFactor(0.8)`，在辅助功能大字号下会截断；欢迎页 footer 用 `safeAreaInset` + `fixedSize`，AX 大字号时可能挤占过多屏幕 | header 用相对字号/允许两行；说明文案允许 2 行；欢迎页 footer 在大字号下改为整页滚动内容 |
| QA-15 | P2 | `GTIIT/Views/RootTabView.swift:30-33,50-54`；`GTIIT/Views/LockScreenView.swift:52` | 仅在 `.background` 上锁：iOS 可能在 `.inactive` 阶段先拍 App 切换器快照，锁定前内容可能被截入快照；锁屏 overlay 也未对下层 TabView 做 `accessibilityHidden`，VoiceOver 可能仍能读到被遮住的网页 | 在 `.inactive` 就上锁/加模糊；锁定期间给 TabView 加 `.accessibilityHidden(true)`、`.allowsHitTesting(false)` |
| QA-16 | P2 | `GTIIT/Models/QuickLink.swift:56-57` | 硬编码 Moodle 课程 ID `course/view.php?id=81`、`id=149` 作为「本科教务空间 / 学生事务空间」固定入口。规格 A.3 明确“ID 不应硬编码为 App 功能入口”（RESEARCH-SPEC.md:118、F.1:534）；A4 只清理了 `/transcripts`，这两条仍在 | 移到“我的”站点说明或标注“未验证”，或改为进入 Moodle 后在官方页内查找；不在默认快捷入口写死 ID |
| QA-17 | P2 | `GTIIT.xcodeproj/project.pbxproj:366-413` | 没有 `DEVELOPMENT_TEAM`（也无 Provisioning 配置）。模拟器不受影响，但真机调试/Archive 上架必须手工补签名配置 | 在 Signing & Capabilities 设 Team，或生成器加入 `DEVELOPMENT_TEAM` 占位说明 |
| QA-18 | P2 | `GTIIT/Views/RootTabView.swift:34-42` | `.fullScreenCover(showWelcome)` 与 `.sheet(item: siteInfo)` 挂在同一个视图上。SwiftUI 同一 presentation 宿主同时只能呈现一个模态；若两者被程序性地同时置位，会丢掉其中一个并打印 “already presenting” | 用单一 enum 驱动 modal（welcome/siteInfo 二选一），或把 sheet 挂到子视图上 |

> P3 汇总（不逐行列表）：四站常驻 WKWebView 内存占用（`AppModel.swift:18,24-29`，≤4 个内容进程，已有懒加载/进程回收兜底）；下载临时文件无清理/配额策略、`resumeData` 未使用（`DownloadCoordinator.swift:20-56`）；死代码 `AppModel.hasLoaded`（:31-33）与 `open(url:in:)`（:72-75）；`AboutView.swift:35` 隐私文案只列 2 个 UserDefaults 键，漏了 4 个 `web.dataStore.identifier.*` UUID；`CFBundleDisplayName=GTIIT`（Info.plist:7-8）与 `AppInfo.displayName="GTIIT 校园助手"` 不一致；A4 #6 提到的 `FilePickerCoordinator` 在源码中不存在（依赖 WebKit 默认文件选择器）；体育快捷入口只有 2/15 个场馆，且说明卡缺“两张时间表冲突/官方联系方式”（E.3 卡 4）；欢迎页主按钮叫「开始使用」而非规格建议的「我已了解并开始使用」，也缺「查看隐私说明」次按钮；工程 objectVersion 56 / compatibilityVersion Xcode 14 由 Xcode 27 打开可能提示升级；无单元测试 target；iPad（TARGETED_DEVICE_FAMILY=1,2）布局未验证。

---

## 4. 逐项检查清单结果

### 4.1 编译

| 检查项 | 结果 | 证据 |
|---|---|---|
| Swift 全部源码 typecheck（Swift 5） | ✅ PASS | exit 0，无输出 |
| 0 warning | ✅ PASS | `-warnings-as-errors` 仍 exit 0 |
| 语法核对 | ✅ PASS | `-parse` exit 0 |
| 完整编译+链接 | ✅ PASS（源码级） | `-emit-executable` exit 0，Mach-O arm64 |
| Swift 6 / 严格并发 | ❌ FAIL（前瞻） | Swift 6 exit 1；见 QA-10 |
| xcodebuild 全构建 | ⚠️ 未验证 | license exit 69，未绕过 |
| 资源编译（actool） | ⚠️ 未验证 | license exit 69 |

### 4.2 工程结构

| 检查项 | 结果 | 说明 |
|---|---|---|
| objectVersion / target / product | ✅ | 56；单 target GTIIT；productType application；product GTIIT.app |
| 每个 PBXFileReference 在磁盘存在 | ✅ | 27/27；Swift 相对各自 group、Assets/Info.plist 相对 GTIIT/ |
| PBXBuildFile fileRef 存在 | ✅ | 25/25 |
| buildPhase 引用存在 | ✅ | 3 个 phase 全部有效 |
| UUID 唯一 / rootObject / mainGroup | ✅ | 73 个对象无重复；均可解析 |
| .swift 全部在 Sources | ✅ | 24/24；无遗漏/重复 |
| scheme BlueprintIdentifier / BuildableName | ✅ | 3 处均等于 target UUID；GTIIT.app |
| build settings | ✅ | 17.0 / bundle id / Info.plist / AppIcon / GENERATE_INFOPLIST_FILE=NO / SWIFT_VERSION=5.0 全部具备 |
| plutil -lint | ✅ | pbxproj 与 Info.plist 均 OK |
| Assets JSON / AppIcon 尺寸 / alpha | ✅ | 1024×1024，RGB 无 alpha；JSON 合法 |
| ⚠️ 发现 | ⚠️ | Release 仍定义 DEBUG（QA-04）；无 DEVELOPMENT_TEAM（QA-17）；无 PrivacyInfo（QA-01） |

### 4.3 代码审查

**WKWebView 生命周期/内存**
- 每站一个 `BrowserModel`，`AppModel.browsers` 缓存（AppModel.swift:18,24-29），同站始终复用 → **无重复创建**；`openSite/open/switchTo` 均走缓存。
- WKWebView/URL 数据容器在 model 生命周期内常驻，AppModel 为全局单例 → 不属于内存泄漏，但最多 4 个 Web 内容进程（P3）。已实现 `webViewWebContentProcessDidTerminate` 自动 reload（BrowserModel.swift:239-243），有兜底。
- `WebViewContainer.makeUIView` 的重挂载安全性见 QA-08：**当前可用但脆弱**。

**KVO / MainActor**
- 6 处 KVO 均用 `MainActor.assumeIsolated`（BrowserModel.swift:141-176）。`.initial` 回调发生在 init 的主线程同步阶段，安全；运行期依赖 WebKit 总在主线程回调——**非契约保证**，失败即 `assumeIsolated` 硬崩（QA-07）。
- 建议改为 `Task { @MainActor in ... }` 或 `DispatchQueue.main.async`，并保留弱引用。

**AppModel.browser(for:) 在 body 中调用**
- **不会**触发 “Modifying state during view update”：`browsers` 是普通字典（非 @Published），且新建的 BrowserModel 尚无 SwiftUI 观察者（QA-09）。
- **不会**重复创建/循环：字典缓存 + `SiteBrowserView` 每站一份。
- 但仍是 body 副作用（创建 WKWebView、发起网络、注册 KVO），建议移出 body。

**跨站路由 / SSO（BrowserModel.swift:245-298、303-317；AppModel.swift:119-138）**
- `decidePolicyFor` 只对**主框架**且 `SiteID.site(for:)` 命中其它站点时切换 Tab 并 `.cancel`，单次导航不会自循环。
- `login.microsoftonline.com` 不在任何 `aliases` 中 → 判为 nil → 留在原 WebView，**SSO 不会被误判**（SiteID.swift:50-57,168-175）。
- 风险：服务器 3xx 与用户点击未区分，A↔B 回跳可能抖动/循环（QA-05）；`target=_blank` 弹窗被压平（QA-06）；`mike-x.com` 后缀过宽，任何 `*.mike-x.com` 都会被当成体育站。
- 另：跨站路由会丢失源站点的前进/后退历史（被 `.cancel` 的导航不入栈），属体验问题。

**TabView visitedTabs 懒加载 / 状态保持**
- 逻辑成立：`RootTabView` 读 `app.visitedTabs`，未访问 Tab 渲染 `Color.clear`，首次访问才建 WebView；`ForEach + if` 的视图身份由 `.tag(tab)` 保证（RootTabView.swift:9-16,58-74）。iOS 17/18 与 26/27 的 TabView 仍走 `.tabItem` 兼容路径，静态上无版本差异；**未运行时验证 iOS 26 Liquid Glass 外观**。
- 切换 Tab 后 WebView 状态保持：TabView 保留各 Tab 视图，WebView 不重建、不 reload，滚动/页面状态保留；`SiteBrowserView` 每次都取缓存 model（SiteBrowserView.swift:9）。
- 小问题：`BookingTabView` 默认 segment=`.rooms`，首次进预约 Tab 会先加载练习房（即使只想看体育），各站仍各只一个 WebView。

**sheet / fullScreenCover / LockGate**
- `LockGate` 用 `@ObservedObject var lock: AppLockController`（RootTabView.swift:78-87）：`isLocked` 是 @Published，**会正常刷新**，判断成立。
- 两个模态挂同一视图有潜在冲突（QA-18）。
- 锁屏时机与快照/无障碍问题见 QA-15。

**中文文案截断风险**
- `MyTabView` 站点状态单行文本过长 → 必截断且截掉关键否定句（QA-11，最严重的一处截断）。
- header 固定高度 + 单行标题/域名：默认字号可容纳两行；长标题按设计省略，可接受。
- Booking 分段说明 `lineLimit(1)`：默认字号可容纳，大字号下会截断（QA-14）。
- 欢迎页/About 长文本用 `fixedSize(horizontal:false,vertical:true)` + ScrollView，正文不截断。

**下载 / file:// / ATS**
- 下载路径：`shouldPerformDownload` 与 `canShowMIMEType==false` 都走 `.download`（BrowserModel.swift:256-259、284-289），`WKDownloadDelegate` 落到临时目录 `GTIITDownloads` 后系统分享；文件名 `sanitize` 把 `/`、`:` 替换掉，**路径穿越不可行**（DownloadCoordinator.swift:58-64）。
- 残留：临时文件无清理/配额策略、失败不可续传（`resumeData` 未用）、未限制文件名长度。属 P3。
- 非 http(s) scheme 全部 `UIApplication.shared.open`（含 file://、data: 等），没有把 file:// 载入 WebView，也没有本地文件读取入口；安全边界合理（但 `data:` 顶层导航会被取消，属边缘限制）。
- ATS：全量 WebView http 放行无必要（QA-12）；无其他 ATS 例外；`ITSAppUsesNonExemptEncryption=false` 已声明。

**隐私 / UserDefaults**
- 无 `evaluateJavaScript`/`WKUserScript`/注入、无 URLSession、无第三方 SDK、无自建后端；网络访问只发生在 4 个官方站点 WebView（及 SSO 跳转、SFSafariViewController/系统打开）。与 About 页“不读取/不上传”的主张**基本一致**。
- UserDefaults 实际存了 **6 类键**：`settings.hasSeenWelcome`、`settings.biometricLock`、4 个 `web.dataStore.identifier.<site>`（AppSettings.swift:7-10；WebDataStoreRegistry.swift:19-26）。About 隐私文案（AboutView.swift:35）只提了前两项 → 文案不完整（P3）。
- 生物识别只经 `LAContext` 本地校验，未申请相机/相册；`NSFaceIDUsageDescription` 已提供。账号/密码确实不经过 App 代码。
- 会话持久化由 WebKit 每站独立 `WKWebsiteDataStore` 承担（WebDataStoreRegistry.swift:29-34），重启保留登录，符合规格。

**iOS 17 API 可用性**
- `WKWebsiteDataStore(forIdentifier:)` 最低 iOS **17.0**（SDK 头 + iOS 16 目标编译实测），部署目标 17.0 → **不需要 `@available`**。若将来把部署目标降到 16，必须加 `@available(iOS 17.0, *)` 并接受“会话不隔离”的降级说明（规格 F.2 最后一条）。
- `MainActor.assumeIsolated` 并非 iOS 17 专属，无可用性问题。
- 其余使用（`onChange(of:) { _, new in }`、`ShareLink`、`presentationDetents`、`NavigationStack`、`scrollContentBackground`）均 ≤ iOS 17。
- 未使用 iOS 18.4+ 的 `runOpenPanelWithParameters`，文件上传依赖 WebKit 默认（Safari 行为）。

**App Store 4.2 / 非官方 App 风险（2–3 条建议，不构成法律结论）**
1. **4.2 Minimum Functionality**：纯网页容器是典型高风险项。建议强化可辩护的原生价值（多站独立会话与清理、生物识别遮挡、下载/分享、本地快捷入口、错误引导），并在审核备注里说明“校园网络受限、需登录学校账号才能看到内容”，必要时准备审核用演示路径。
2. **5.2.1 商标/非官方**：App 名 `GTIIT`、校园蓝图标与文案使用学校名称/缩写，即使有免责声明也可能被要求授权。建议发布前取得学校书面许可，或改用不含校名的中性名称并保留“非官方”声明。
3. **4.3 / 2.1 / 隐私**：避免与其它学校“网页套壳”模板同质化；确保隐私标签填写「不收集数据」，同时补 PrivacyInfo（QA-01）与 ATS 说明（QA-12）；审核时说明四站均需校园网络，避免审核员打不开页面被判定功能不可用。

---

## 5. 对 RESEARCH-SPEC.md 附录 A4 的差异核对

| # | A4 原差异 | 状态 | 代码位置与依据 |
|---|---|---|---|
| 1 | 门户快捷入口含 `/transcripts`（未验证路由） | **已修** | `QuickLink.swift:41-44` 只有 grades/enrollments/checklist/attendance；全仓 grep `transcripts` = 0 命中 |
| 2 | 教学评价副标题写死「页面显示 2026-12-21 开放」 | **已修** | `QuickLink.swift:55` 副标题为「开放时间以页面提示为准」；grep `2026-12-21` = 0 命中 |
| 3 | WelcomeView 缺完整声明 / 默示同意 / 无显式确认 | **已修** | `WelcomeView.swift:118` 为 E.1 的 155 字全文；`:130-146` 复选框「我已阅读并了解…」；`:148-161` 未勾选时「开始使用」禁用；`:60` `interactiveDismissDisabled`；grep「继续使用即表示」= 0。**小偏差**：主按钮文案仍是「开始使用」，不是规格建议的「我已了解并开始使用」，也缺 E.1 的次要按钮「查看隐私说明」（P3） |
| 4 | SiteInfoView 只有边界/入口/清除，缺「用途」「已知前提」 | **已修** | `SiteInfoView.swift:28-32`「用途」=`site.purpose`；`:34-46`「首版边界」；`:48-61`「已知前提」=`site.prerequisites`；`:63-68` 入口；`:70-85` 打开/清除按钮 + 确认弹窗。**内容层面**仍少于 E.3 卡 3/卡 4 的细节（体育两表冲突、官方联系方式、15 场馆入口；练习房书面规定全套）→ P3 |

补充核对（A4 #5–#8，供 Lead 取舍）：

| # | 状态 | 依据 |
|---|---|---|
| 5 | **已修** | `MyTabView.swift:179-182`：`本机已保存网页数据（不代表已登录）` / `本机暂无网页数据`，与 E.5 建议一致（但见 QA-11 截断风险） |
| 6 | **部分修** | 下载+系统分享已实现（`DownloadCoordinator.swift:20-51`）；A4 提到的 `FilePickerCoordinator` 在源码中**不存在**（grep=0），上传依赖 WebKit 默认；`AboutView.swift:32-37` 隐私说明未补「下载文件只落临时目录」一句，也无临时文件清理策略 |
| 7 | **部分修** | 锁定页文案（`LockScreenView.swift:17-24`）与「只遮挡界面」主张成立；但 E.2 第 8 条要求的“生物识别由 iOS 验证、App 不接触”未写进 About 的隐私分条（`AboutView.swift:32-37` 只有 4 条，不是 9 条） |
| 8 | **保留/部分** | 名称`AppInfo.swift:4`与标语`:19`一致，About 有非官方声明；但 `CFBundleDisplayName=GTIIT`（Info.plist:7-8）与「GTIIT 校园助手」不一致，发布前仍需学校名称/标识授权核查 |

**A4 总结论**：4 条必查差异 **全部已修**（#3 有按钮文案小偏差），Lead 对研究快照的响应是到位的；新的遗留集中在“未验证深链（Moodle 81/149）”“隐私文案完整性（A4 #6/#7）”和“运行时安全边界”。

---

## 6. 残余风险

1. **未做运行时验证**：本报告无法证明 App 在真机/模拟器上可启动、可加载四站、可走 SSO。Xcode license 未同意导致 `xcodebuild`/`actool`（exit 69）不可用；未用 sudo 绕过，也未模拟器运行。
2. **KVO 主线程假设**（QA-07）：WebKit 当前通常主线程回调，但非契约；失败表现为崩溃而非降级。
3. **WebView 重挂载假设**（QA-08）：依赖 SwiftUI 每次重建 representable 时调用 `makeUIView` 的行为；不同 iOS 版本行为若变化可能白屏。
4. **SSO / 弹窗 / 重定向**（QA-05、QA-06）：Microsoft 登录、Moodle SAML2、`window.open` 弹窗需要真机回归；跨站 A↔B 回跳的循环概率无法仅靠静态分析排除。
5. **校园网络可达性**：四站均需校内网络/学校认可方式；审核与首次用户可能遇到 DNS/证书/超时，错误文案已覆盖（BrowserModel.swift:192-210），但真实错误码映射未验证。
6. **iOS 26/27 UI**：TabView/Liquid Glass、锁屏、sheet 外观未运行时验证；iOS 17/18 行为为静态推断。
7. **上架合规**：PrivacyInfo（QA-01）、ATS 例外（QA-12）、4.2 最低功能、5.2.1 商标、审核可复现路径；均需在提交前由 Lead/发布者决策。
8. **工程生成器**：`Tools/gen_project.py` 是 pbxproj 的唯一可信来源；QA-04 的根因在其 138 行，若只手改 pbxproj 会在下次生成时回归。

---

## 7. 建议修复顺序（不改源码，仅建议）

1. **提审阻断**：QA-01（PrivacyInfo）、QA-13（相机/麦克风描述，若站点会用到）。
2. **数据安全/体验**：QA-02（左滑清除确认）、QA-11（状态文案截断）。
3. **发布配置**：QA-04（Release 去 DEBUG）、QA-17（Development Team）、QA-03（确认后再加载网页）。
4. **运行时稳健性**：QA-07（KVO）、QA-08（WebView 容器）、QA-05/06（跨站/弹窗）、QA-15（锁屏快照）。
5. **上架合规与前瞻**：QA-12（ATS）、QA-10（Swift 6）、QA-16（硬编码 ID）、4.2/5.2.1 策略。

---

## 8. 声明

- 本次复核**未修改** `GTIIT/` 下任何源码、未修改 `GTIIT.xcodeproj/project.pbxproj`、未修改 `GTIIT.xcodeproj/xcshareddata/xcschemes/GTIIT.xcscheme`、未运行 `Tools/gen_project.py`。
- 未使用 `sudo`、未绕过 Xcode license。
- 临时脚本与编译产物仅写入 `/tmp` 与 `$WD/.cache`；本报告是本次唯一写入 `docs/` 的文件。
- 报告中的行号以复核时（2026-10-21）源码为准；若 Lead 后续修改源码，行号可能偏移。
