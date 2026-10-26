# Opus 5.5 交接文档 · GTIIT Campus Assistant

更新时间：2026-10-26  
仓库：/Users/zhufengyi/Documents/ChatGPT/探索/GTIIT-iOS-App  
当前基线提交：372d4f2（main）  
当前版本：2.0.1-beta，build 65  
本机已安装：iPhone Air，2.0.1 (65)  
工作区状态：干净（交接文档提交前）

## 0. 先读什么

建议按顺序阅读：

1. README.md：产品范围、环境、构建、真机安装
2. CHANGELOG.md：最近 2.0.1 的结构变化
3. docs/PERFORMANCE.md：当前四站预加载和摘要时序
4. docs/BACKGROUND-REFRESH.md：后台任务/Widget/Live Activity 审计
5. docs/LOCALIZATION.md：本地化覆盖与检查
6. docs/MOODLE-NATIVE-SPEC.md：Moodle 原生工作台和边界
7. docs/RESEARCH-SPEC.md：四个校园站点的只读研究快照
8. docs/ARCHITECTURE.md：分层说明，但内容仍标为 1.11，部分启动/导航描述已过时，以代码和 PERFORMANCE 为准

本机源码是唯一权威。不要把 2026-10-21 的网页结构研究当成永久 API。

## 1. 这台电脑和运行环境

- macOS 27.0.1（Build 26A434）
- Xcode 27.1（Build 27A9275）
- 仓库路径：/Users/zhufengyi/Documents/ChatGPT/探索/GTIIT-iOS-App
- 当前 agent 工作目录：/Users/zhufengyi/Documents/deepseek-harness/default-workspace
- 真机：iPhone Air，UDID 00008150-001169210EE2401C，当前可安装 2.0.1 beta 65
- 可丢弃回归模拟器：GTIIT-Design-Review，UDID 0FC8885A-CE2A-4118-971E-97C2A718A5F7
- Xcode 工程是生成文件，不要手改 GTIIT.xcodeproj/project.pbxproj
- 本机 Tools/signing.env 存在且被 git 忽略；不要提交其中团队 ID
- 默认不启用 App Groups；GTIIT/GTIIT.entitlements 和 Widget entitlement 已存在，但当前签名不启用共享容器

## 2. 产品定位与硬边界

这是非官方、学生独立开发的 GTIIT 校园客户端，不是学校官方 App。

四个网页系统：

| 站点 | 原生入口 | 主要用途 |
| --- | --- | --- |
| Student 门户 | Portal Tab / 原生菜单 | 成绩、选课、考勤、申请、评价、培养计划、学生课表 |
| Moodle | Learning Tab | 当前课程、临近日程、作业/测验、历史课程、工具目录 |
| Room Booking | Booking Tab | 练习房、讨论室、预约查询 |
| Sports Center | Booking Tab | 体育中心、场馆、会员预约 |

核心边界：

- 没有已验证的学校业务 API；网页内容通过各自独立 WKWebsiteDataStore 访问。
- 不代填、不代提交业务表单；密码只在官方网页输入。
- 不接管 Moodle 移动令牌；Moodle 自动登录只点击登录页已有的 Office 365 SAML 链接，不读取/填写账号密码，不绕过 MFA。
- 没有自建后端、统计 SDK、崩溃上报、APNs 远程推送。
- 课表、Moodle 摘要、考试摘要只保存在本机受保护 Application Support；清除对应站点数据时同步清除。

## 3. 当前用户界面结构

### 一级导航

- iPhone 竖屏：系统 TabView，五页：Shuttle、Portal、Learning、Booking、Me。
- iPhone 横屏 / iPad 宽屏：原生 UISplitViewController + 系统 Sidebar List。
- 侧栏和详情使用同一个 SwiftUI TabView；旋转时保持页面实例，不重新创建 WebView。
- 侧栏收起/展开现在由一个浮动的 sidebar toggle 完成，锚定物理左上角安全区；横屏左侧 Dynamic Island 安全区也计入。旧的 sidebar navigation 右侧按钮已移除。
- RootTabView.swift 中 NativePrimaryController 负责 split view、安全区按钮、旋转和 content host。

### 各页面

- Portal：SiteBrowserView，原生标题 + 网页；原生标题栏菜单为图标按钮，菜单项使用语义图标；网页 header/nav/aside/菜单栏被 CSS 隐藏，只保留 main 和 Checklist steps 等必要结构。
- Learning：MoodleTabView，原生工作台；当前课程按本地课表匹配，未匹配的当前学期内容进入其他课程；历史课程为原生二级卡片页；课程卡 push 到课程详情，顶部 inline 标题，下方官方内容，Moodle 网页 chrome 被隐藏。
- Booking：原生目录 + 官方网页 push；不再使用底部 sheet。
- Shuttle：原生时刻表、双方向卡片、Live Activity、本地提醒、定位方向推荐。
- Me：课表、考试、Moodle 摘要、快捷入口、设置、关于、以龙彩蛋等。

### 最近 UI 约定

- 学习/预约顶部只有一个 58pt 图标，和 20pt 内容边距对齐，不再有大标题卡。
- 所有原生卡片 push 到右侧页面；网页页面保留原生返回。
- 触感反馈集中在 Core/Haptics.swift，Settings 可关。
- App 支持浅色/深色/系统，网页 Dark Reader 适配四站；Apple 登录页不注入暗色。

## 4. 启动、WebKit 与刷新时序

当前启动路径与旧文档不同：

1. SwiftUI 首帧显示真实 UI。
2. AppModel.prepareLaunchIfAllowed 创建四个 BrowserModel，并在 WebPrewarmHost（opacity 0.01、无触摸）里给四个 WKWebView 提供窗口和布局。
3. 约 250ms 后启动 Moodle 摘要；考试摘要再延后 200ms（warmUpCampusSummaries）。
4. LaunchPreparation 负责探测四站登录状态、Moodle 既有 SSO 链接和页面就绪；没有全屏 launch gate，页面加载与首帧独立。
5. 有 Moodle 缓存时，约 1.2s 后 MoodleAutoLogin 启动，只点击官方登录页已有 SAML 链接。
6. 预加载结束移除 WebPrewarmHost；进入 Tab 时复用同一个 WKWebView，不重新加载。

需要知道的代价：四站预加载是有意为之，会创建四个 WebView/内容进程；如果审视启动速度，先看 docs/PERFORMANCE.md 和 Instruments，而不是直接删预加载。

后台执行：没有 BGTaskScheduler、后台 URLSession、持续后台定位或远程推送。只有 WidgetKit timeline（请求 600 秒）和用户排定的本地通知在 App 不活跃时工作；详见 docs/BACKGROUND-REFRESH.md。

## 5. 代码地图

| 路径 | 作用 |
| --- | --- |
| GTIIT/App/GTIITApp.swift | App 入口，创建 Settings/AppModel |
| GTIIT/App/AppModel.swift | 站点浏览器、Tab、启动预加载、摘要、Moodle 自动登录、通知路由 |
| GTIIT/App/AppSettings.swift | 默认设置、持久化、启动页、语言、Moodle 布局、触感等 |
| GTIIT/App/AppLockController.swift | LocalAuthentication App 锁 |
| GTIIT/App/PrivacyShieldController.swift | 独立窗口隐私遮挡 |
| GTIIT/App/ShuttleIntents.swift | Siri / App Intents / App Shortcuts |
| GTIIT/Views/RootTabView.swift | 自适应 Tab/SplitView/Sidebar、生命周期、Debug 启动开关 |
| GTIIT/Views/SiteBrowserView.swift | Portal/Moodle 旧网页 shell、原生导航菜单 |
| GTIIT/Views/MoodleNativeView.swift | Moodle 原生工作台、课程/历史/工具/布局、课程详情 |
| GTIIT/Views/BookingTabView.swift | 预约原生目录与 push 官方页 |
| GTIIT/Views/ShuttleView.swift | 班车时刻表、方向卡、提醒入口 |
| GTIIT/Views/MyTabView.swift | 我的页面和摘要入口 |
| GTIIT/Views/SettingsView.swift | 设置、课表、站点清理、布局等 |
| GTIIT/Views/WelcomeView.swift | 首次启动分页说明 |
| GTIIT/Services/BrowserModel.swift | 单站 WKWebView、导航策略、KVO、下载、恢复 |
| GTIIT/Services/WebDataStoreRegistry.swift | 四站独立持久化容器与清理 |
| GTIIT/Services/LaunchPreparation.swift | 四站启动探测、Moodle SSO 链接识别 |
| GTIIT/Services/MoodleAutoLogin.swift | 登录页既有 Office 365 链接的自动点击（不填表） |
| GTIIT/Services/MoodleUpcomingStore.swift | Moodle 摘要、缓存、30 分钟刷新 |
| GTIIT/Services/StudentExamStore.swift | 考试摘要、隐藏 WebView、30 分钟刷新 |
| GTIIT/Services/DownloadCoordinator.swift | WKDownload、进度、保存、外部目录 |
| GTIIT/Services/PDFPreviewCoordinator.swift | PDFKit 预览与保存 |
| GTIIT/Services/WebAppearance.swift | Dark Reader、网页背景、Moodle/Student chrome 脚本注入 |
| GTIIT/Resources/WebAppearance/appearance.js | 网页 CSS/清理逻辑；Student 菜单隐藏和 Moodle 导航在这里 |
| GTIIT/Components/WebViewContainer.swift | WebView 宿主、滚动/导航栏联动 |
| GTIIT/Components/WebPrewarmHost.swift | 启动隐藏预加载宿主 |
| GTIIT/Components/NativePageIcon.swift | Learning/Booking 共享图标头 |
| GTIIT/Components/NativeWebPageView.swift | 共享 push 网页、进度/错误/加载态 |
| GTIIT/Core/Localization.swift | L10n 中英字典与 format |
| GTIIT/Core/Haptics.swift | 触感总开关与统一 API |
| GTIIT/Core/Theme.swift | 颜色、导航外观、Sidebar 颜色 |
| GTIITWidgets/ | Widget extension（Next bus + Live Activity UI） |
| GTIIT/Models/MoodleUpcoming.swift | MoodleWork/MoodleCourse；Homework 标题与课程匹配 |
| Tests/ | 352 项异步回归、合成 fixture server、UI review |
| Tools/ | 工程生成、校验、版本、设备安装、图标 |
| docs/ | 架构、研究、性能、本地化、后台、Moodle spec、设计、验收 |

## 6. 构建、测试、安装

编译工程：

~~~bash
cd /Users/zhufengyi/Documents/ChatGPT/探索/GTIIT-iOS-App
python3 Tools/check_project.py
python3 Tools/check_localization.py
xcodebuild -project GTIIT.xcodeproj -scheme GTIIT -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/GTIIT-UI CODE_SIGNING_ALLOWED=NO build
~~~

回归：

~~~bash
python3 Tools/run_regression.py 0FC8885A-CE2A-4118-971E-97C2A718A5F7
~~~

真机安装：

~~~bash
./Tools/install_device.sh
./Tools/install_device.sh 00008150-001169210EE2401C
~~~

生成器：

~~~bash
python3 Tools/gen_project.py
python3 Tools/check_project.py
~~~

版本只改 Tools/version.json，然后重新生成工程；不要手工编辑 pbxproj。

## 7. 当前验证状态

2026-10-26 本轮已验证：

- Tools/check_project.py 通过
- Tools/check_localization.py 通过：664 tr、46 format、890 .strings、2 Info.plist keys
- Tools/run_regression.py：352 checks passed
- 模拟器 Debug 构建成功
- iPhone 安装 2.0.1 (65) 并启动

未验证/需要真实账号的部分：

- 真实 GTIIT 登录后的 Student/Moodle/预约页面内容和菜单隐藏效果
- 不同校园网/VPN 下的页面加载
- 真机横屏/旋转后的 sidebar 按钮实际触感与 Dynamic Island 安全区视觉
- Moodle 自动登录在真实 MFA/会话过期场景下的行为
- App Groups、Widget 共享设置的真实签名

## 8. 当前风险与审查重点

### 高优先级

1. appearance.js 中 Student 菜单隐藏使用了较宽的 header/nav/aside/[class*=menu] 规则；需要在真实登录页确认没有误伤内容、表单和 Checklist steps。
2. Sidebar toggle 现在用 window safeAreaInsets 手工 frame 定位；需要在 iPhone 横屏、竖屏、iPad 和旋转过程确认不被圆角/Dynamic Island 遮挡。
3. Homework 标题通过第一个 1–3 位数字 token 归一化；可能误识别名字中先出现的教室/编号；当前测试覆盖常见形式，但应抽真实课程名验证。
4. App Groups 未启用：Widget 的教学周/语言可能 fallback；不要假设跨 target 状态同步。
5. docs/ARCHITECTURE.md 仍标为 1.11，和当前预加载、Sidebar、Moodle 原生页不一致；审查时以代码/PERFORMANCE 为准，可顺手更新。

### 中优先级

- 默认语言仍为中文；英文系统首次启动不会自动切英文。
- Localizable.strings 有历史/孤立键；当前检查通过，不代表完整清理。
- 四站并行预加载是有意取舍，低内存/旧设备需要 Instruments 复测。
- WidgetKit 10 分钟是请求间隔，不是保证。
- Live Activity 没有推送刷新；App 挂起后内容不会继续更新。
- 生成工程依赖 Python 工具链；直接 Xcode 打开生成工程可以，但源文件增删后必须再生成。

### 不要做

- 不要伪造学校 API 或声称原生提交已实现。
- 不要读取/填写密码、MFA 或表单值。
- 不要把 Cookie、账号、课表、摘要、签名团队写入 Git。
- 不要手工改 pbxproj 绕过生成器。
- 不要为性能直接移除四站会话隔离或 Moodle SSO 恢复。

## 9. Opus 5.5 的审查清单

内容审查：

- 中英 native UI 是否全部翻译；strings 与 L10n 是否漂移
- Student/Moodle 网页隐藏规则是否误伤内容
- Homework 标题、课程编号、学期/历史分类是否符合产品语义
- 空状态、错误状态、未登录状态、部分更新状态是否清晰

结构理解：

- AppModel、BrowserModel、WebViewContainer、WebPrewarmHost 的所有权
- 四站独立数据容器与清理流程
- 原生页面和网页页面之间的 push/back 边界
- Widget/Live Activity/通知/后台刷新边界
- 启动预加载和首帧的关系

验证：

- 运行 check_project、check_localization、run_regression
- 模拟器横屏/竖屏、iPad 宽度
- 真机真实登录、清除站点数据、锁屏、旋转
- 查看 docs/verification 的最新结果，不把历史截图当当前状态

## 10. 本机交接注意

- 如果另一个模型在同一目录继续工作，先 git status 和 git log --oneline -3，不要覆盖未提交改动。
- 当前工作区在本交接文档生成前是干净的；若出现修改，先判断是否来自用户或其他 agent。
- Tools/signing.env 是本地文件，不是团队共享配置。
- 文档中的 2026-10-21 研究快照可能过期；页面结构变化优先检查真实登录后的 WebView。
- 本机 iPhone 可能锁屏；安装后启动失败先解锁，再运行 install_device.sh。
