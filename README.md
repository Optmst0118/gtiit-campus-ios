# GTIIT 校园助手 · GTIIT Campus Assistant

[![Build](https://github.com/Optmst0118/gtiit-campus-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/Optmst0118/gtiit-campus-ios/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/iOS-17.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

> **非官方项目。** 由学生独立开发，与广东以色列理工学院（GTIIT）及其信息系统运营方没有隶属、授权或背书关系。
> Unofficial, student-built client. Not affiliated with, endorsed by, or supported by GTIIT.

把学校的四个官方网页集中到一个 iOS App，配合原生班车倒计时、离线课表、Moodle 临近日程、临近考试、PDF 预览与下载管理。课表需用户确认后保存；日程摘要仅缓存在本机，不转发、不代提交校园业务数据。

**当前版本：1.13（17）**。完整变更见 [CHANGELOG](CHANGELOG.md)，交付与验证范围见 [1.13 记录](docs/RELEASE-1.13.md)。

<p align="center">
  <img src="docs/screenshots/01-welcome.png" width="200" alt="首次启动说明">
  <img src="docs/screenshots/02-portal.png" width="200" alt="学生门户跳转 Microsoft 登录">
  <img src="docs/screenshots/03-booking.png" width="200" alt="练习房预约登录页">
  <img src="docs/design/features-1.8/me-separate-cards.png" width="200" alt="我的页：本地课表与临近日程">
</p>

---

## 目录

- [它是什么](#它是什么)
- [功能](#功能)
- [截图](#截图)
- [环境要求](#环境要求)
- [快速开始](#快速开始)
- [真机安装](#真机安装)
- [测试与验证](#测试与验证)
- [架构](#架构)
- [项目结构](#项目结构)
- [隐私与安全](#隐私与安全)
- [已知限制](#已知限制)
- [文档](#文档)
- [参与贡献](#参与贡献)
- [许可与声明](#许可与声明)
- [English](#english)

## 它是什么

GTIIT 的日常学习与预约分散在四个系统里：

| 系统 | 作用 | 首页 |
| --- | --- | --- |
| 学生门户 | 学期课程、成绩、考试、选课/周课表、刷卡考勤、申请、培养计划、教学评价 | `students.gtiit.edu.cn` |
| Moodle | 课程、Assignment / Quiz、资料、课程考勤、日历 | `moodle.gtiit.edu.cn` |
| 房间预约 | 练习房 / 讨论室 / 体育场馆等 Booked 资源 | `roombooking.gtiit.edu.cn` |
| 体育中心 | 场馆入口、开放时间、会员预约 | `gtiit.mike-x.com` |

这些系统的网页本身可用，但手机浏览器里来回切换、反复登录、找不到上一页非常低效。本项目因此选择 **网页套壳（web shell）** 路线：

- 每个系统一个独立的持久化 `WKWebsiteDataStore`，会话互不干扰、重启保留、可单站清除；
- 保留官方登录、表单与业务逻辑；网页外观、品牌条与页脚适配独立注入，操作仍由用户在官方页面完成；
- 原生补充**班车、校历、本地课表、临近日程、下载与 PDF 预览、App 锁、设置和错误恢复**。

课表仅提取正式选课的课程名称、班组、星期、时间和教室；Moodle 日程在现有同源网页会话内只读检查当前学期活跃课程的作业名称、开放／截止日期与提交状态；考试读取仅限 Student 当前学期考试组件的课程、类别、日期、时长和地点。原生层不保存账号密码、会话密钥、成绩、作业正文或附件。

## 功能

### 当前原生功能

- **本地课表**：我的页面可从门户导入；设置 → 课表采用标准横向导航，提供提取、查看与删除。自动识别正式选课后进入核对页，右上角蓝色勾确认保存。当日与下一节课程包含时间、教室和楼宇，点入可看整周。离线快照不会自动同步，变更后需重新导入。
- **Moodle 临近日程**：与课表分别成卡；结合日历及当前学期活跃课程的作业页，补充 Timeline 未包含的截止信息。摘要以受文件保护、排除备份的文件保存在本机，重启可用；自动间隔 30 分钟，支持手动刷新。退出登录或清除 Moodle 网页数据时同步清除。课程过滤使用 Moodle 的 in-progress 分类，并排除明确的旧学期、未来／已结束与不可见课程。
- **临近考试**：在“我的”中位于 Moodle 临近日程下方，独立显示最近一场考试的课程、类别、时间、时长和地点；详情页显示当前学期所有未开始的考试。只读 Student Dashboard 考试组件分页前的数据，在本机受保护缓存，每 30 分钟更新，支持手动刷新；清除门户登录数据时同步清除。未知地点显示待定，临时变更需在 Student 核对。
- **校历**：常用入口内提供 2025–2026／2026–2027 学年、原生月历与原始 PDF。月历仅将经核实的实际放假日标红，保留国内假期及逾越节，不标非放假节日；未经核实的原表日期不自动推断。学校原件不公开再分发，本机授权原件缺失时仅禁用原始 PDF 入口。
- **常用入口**：两栏蓝色渐变卡片（无障碍大字号使用单栏）；设置 → 通用 → 管理常用入口可添加、隐藏与恢复。网站快捷卡片长按可分享链接、移除与管理；移除仅影响入口。菜单出现后卡片持续等比放大约 12%，连续圆角随比例保持，背景轻微模糊和变暗。无长按菜单的可点击卡片采用按住微缩、松开恢复；遵循减弱动态效果。
- **语言**：设置 → 语言即时切换 English／中文，仅影响原生界面，保留网页实例。
- **以龙彩蛋**：连续点击“关于 GTIIT”标题或简介卡片六次，在设置中解锁。三视图贴纸带碰撞与橡胶回弹；可收起，减弱动态效果时静态展示。

### 网页容器

- **原生标题栏**：四个网站的标题固定为 Student、Moodle dashboard、GTIT room booking service、GTIT sports center，采用原生导航栏；网页内的课程标题不再替换 App 标题，首页与刷新等操作收进更多菜单。
- **五段底部标签**：班车 / 门户 / 学习 / 预约 / 我的；预约内再分「练习房 / 讨论室」与「体育场馆」。
- **每站独立会话**：基于 iOS 17 的 `WKWebsiteDataStore(forIdentifier:)`，可分别清除登录数据。
- **跨站路由**：用户点击的普通 GET 链接会切到对应标签；POST、登录与重定向留在原 WebView，保持表单与 SSO 上下文。
- **真实新窗口**：`window.open` / `target=_blank` 用 WebKit 提供的配置创建子窗口，保留 `opener` 与 `postMessage`。
- **下载**：保留当前响应（含 Cookie / POST / 一次性链接）转成 `WKDownload`，支持进度、取消、服务器支持时续传、同名编号。
- **PDF 预览**：Moodle 的 PDF 先用 PDFKit 预览，右下角按钮显式保存，不会偷偷落盘。
- **网页深色外观**：在隔离脚本世界中为四个校园域增补配色（Dark Reader，MIT），不改页面 JS 原型与业务事件。
- **底栏与恢复**：内容延伸到原生液态玻璃底栏下方；Student 保持完整网页视口，为其内部滚动区末尾和 Checklist 固定操作条单独避让，其他页面使用 WebKit obscured insets。门户复用视图在导入返回时重新挂载。只读且未编辑的普通 GET 页面可限频恢复，表单与 POST 不自动重放。
- **加载与错误**：下拉刷新、进度条、占位与重试；四站错误页均提示校园 Wi-Fi／aTrust，是否可直接跳转由已安装客户端能力决定。冷启动可预加载四站（10 秒上限，可关闭）。

### 原生能力

- **班车**：南→北／北→南双栏，蓝／橙色从上向下渐隐的卡片展示下一班、倒计时和随后班次；点击卡片进入对应方向的完整时刻表（58 个车次，2026-10-12 表；教学周手动确认）。
- **App 锁**：立即 / 1 分钟 / 5 分钟后锁定，Face ID / Touch ID / 设备密码；后台以独立遮罩覆盖网页、分享面板与内置 Safari。
- **下载管理**：紧凑列表／网格、名称／大小／时间双向排序，偏好跨启动保存。默认下载位置可改为本机、iCloud Drive 或受支持文件服务，只影响新下载；旧文件不迁移。列表左滑删除使用系统红色并需确认；长按可预览、分享及管理文件。网格使用独立 UIKit collection cell，原生长按仅提升当前文件的缩略图，不会把相邻文件或整个背景一起提起；原生 Quick Look、菜单和关闭后的复原按文件 ID 管理。
- **设置**：课表、语言、通用、隐私与锁定、网页浏览、站点与登录、存储空间、下载管理、帮助与诊断、关于。
- **外观**：跟随系统 / 浅色 / 深色即时生效；`UIContentSizeCategory` 与最大辅助字号适配。
- **网络诊断**：不带 Cookie 的 HEAD 检测，只输出站点、状态码与时间，可分享。
- **无第三方依赖**：没有网络库、没有统计 SDK、没有自建后端；只有系统框架与一个 MIT 许可的 Dark Reader 脚本。

## 截图

| 班车 | 门户 | 预约 |
| --- | --- | --- |
| <img src="docs/design/shuttle-iphone-final.png" width="220"> | <img src="docs/screenshots/02-portal.png" width="220"> | <img src="docs/screenshots/03-booking.png" width="220"> |

| 学习（Moodle） | 我的 | 设置 |
| --- | --- | --- |
| <img src="docs/screenshots/05-learning.png" width="220"> | <img src="docs/design/features-1.8/me-separate-cards.png" width="220"> | <img src="docs/verification/settings-iphone-se.png" width="220"> |

| 下载管理 |
| --- |
| <img src="docs/screenshots/07-downloads.png" width="220"> |

更多设计稿与验收截图见 [docs/design](docs/design) 与 [docs/verification](docs/verification)。

### 当前长按交互（合成测试数据）

| 持续等比放大的常用入口 | 下载网格中的文档预览 |
| --- | --- |
| <img src="docs/design/features-1.11/shortcut-menu-sustained.png" width="230" alt="菜单显示期间维持等比放大和连续圆角"> | <img src="docs/design/features-1.11/download-grid-document-preview.png" width="230" alt="下载网格长按只呈现文件本身"> |

## 环境要求

| 项 | 要求 |
| --- | --- |
| macOS | 15 或更新 |
| Xcode | **26 或更新**（使用 iOS 26 SDK 的 Liquid Glass API；部署目标为 iOS 17） |
| iOS 设备/模拟器 | iOS 17.0+ |
| 可选 | Python 3（工程生成、检查、回归脚本） |

工程不依赖 CocoaPods / Swift Package Manager / 任何外部库，克隆后即可打开构建。

## 快速开始

```bash
git clone https://github.com/Optmst0118/gtiit-campus-ios.git
cd gtiit-campus-ios
open GTIIT.xcodeproj
```

不需要新建 Xcode 工程：仓库里已经包含完整、可打开的 `GTIIT.xcodeproj`。在已存在的本地目录里更新时，直接 `git pull` 即可。

在 Xcode 中：

1. 选择 target **GTIIT** → **Signing & Capabilities**，选择你自己的开发团队；
2. 选一台 iOS 17+ 模拟器或真机，⌘R 运行。

命令行构建（模拟器，不需要签名）：

```bash
xcodebuild -project GTIIT.xcodeproj -scheme GTIIT -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

### 工程文件是生成的

`GTIIT.xcodeproj/project.pbxproj` 由脚本生成，新增/删除源文件后运行：

```bash
python3 Tools/gen_project.py      # 重新生成 pbxproj 与共享 scheme
python3 Tools/check_project.py    # 校验引用、UUID、签名设置、图标与隐私清单
```

签名团队来自环境变量 `DEVELOPMENT_TEAM` 或本机 `Tools/signing.env`（已被 git 忽略）。模板见 `Tools/signing.env.example`。

## 真机安装

```bash
./Tools/install_device.sh          # 自动选择已连接的实体设备
./Tools/install_device.sh <UDID>   # 指定设备
```

脚本会：读取 `Tools/signing.env` 里的团队（或 `DEVELOPMENT_TEAM` 环境变量）→ 构建并自动续签 → 安装 → 启动。**不需要在 Xcode 里手工点 Team，也不会把团队写进 `project.pbxproj`。**

首次安装后需要在 iPhone 上信任开发者证书：

> 设置 → 通用 → VPN 与设备管理 → 「Apple Development: …」→ 信任

免费个人团队的描述文件 **7 天过期**，到期重跑脚本即可续签。

> 公开仓库使用中性 bundle id `io.github.optmst0118.gtiit`。如果你之前装过内部版本（`com.zhufengyi.gtiit`），新版本会作为另一个 App 并行安装；想原地升级就改 `Tools/gen_project.py` 里的 `BUNDLE_ID` 后重新生成工程。

## 测试与验证

项目使用独立测试 App 运行真实 WebKit 集成回归，测试数据全部为本地合成数据，不接触真实学生资料。

```bash
# 需要一个名称包含 Review 或 Test 的可丢弃模拟器
python3 Tools/run_regression.py <模拟器 UDID>

# 三种构建（Debug 模拟器 / Release 模拟器 / Release 真机目标）
python3 Tools/verify_builds.py
```

验证证据在 [docs/verification](docs/verification)，各版本的实际验证范围与限制记录在对应的 RELEASE 文档中；历史构建结果不等同于所有版本都重新执行三种构建：

| 验证 | 数量 | 说明 |
| --- | --- | --- |
| 集成回归 | 285 项 | 导航策略、WebKit、下载、锁定、暗色、校历、课表、当前学期过滤、日程缓存与入口配置；最终版本结果见交付记录 |
| 班车检查 | 40 项 | 时刻表解析、跨日、教学周、末班 |
| 构建 | 3 种 | Debug 模拟器、Release 模拟器、Release 真机目标（`CODE_SIGNING_ALLOWED=NO`） |

CI（GitHub Actions）在 `macos-26` 上执行工程检查与模拟器构建。

## 架构

```
界面层  RootTabView / ShuttleView / SiteBrowserView / BookingTabView / MyTabView / SettingsView
          │ 原生只负责导航外壳、状态、设置、下载与锁
应用层  AppModel / AppSettings / AppLockController / LaunchPreparation / PrivacyShieldController
          │
网页内核 BrowserModel（每站一个） · WKWebView + navigation/ui delegate + KVO + 下载
          │
基础设施 WebDataStoreRegistry（每站独立持久化容器） · DownloadCoordinator / PDFPreviewCoordinator
         NavigationPolicy · PopupBrowserController · WebAppearance · NetworkDiagnostics
          │
站点定义 SiteID / AppTab / QuickLink / ShuttleSchedule（纯数据）
```

完整分层、时序与关键决策见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 项目结构

```
GTIIT-iOS-App/
├── GTIIT.xcodeproj/            # 由 Tools/gen_project.py 生成
├── GTIIT/
│   ├── App/                    # 入口、AppModel、设置、锁、隐私遮罩
│   ├── Components/             # 浏览器部件、下载浮窗、设置选择器
│   ├── Core/                   # 主题、App 信息
│   ├── Models/                 # 站点、Tab、快捷入口、班车时刻
│   ├── Services/               # 网页内核、数据容器、下载、导航策略、外观
│   ├── Views/                  # 五个一级页面与设置、帮助、锁屏
│   └── Resources/              # Assets、隐私清单、Dark Reader 脚本与许可
├── Tests/                      # 回归脚手架、UI Review、合成数据服务
├── Tools/                      # 工程生成/检查、构建验证、回归、图标、真机安装
├── docs/                       # 架构、研究、评审、设计、验收与截图
├── CONTRIBUTING.md · CODE_OF_CONDUCT.md · SECURITY.md · CHANGELOG.md
└── LICENSE
```

## 隐私与安全

- **不采集数据**：没有自建后端、统计 SDK、埋点或崩溃上报；仓库内没有真实学生数据。
- **账号只在官方网页输入**：App 代码不接触账号密码，不注入登录表单；课程提取是用户主动发起、字段受限的本地读取。
- **会话只在本地**：Cookie 与网页存储在 WebKit 沙盒内，四站隔离；可单站或全站清除。
- **本地数据**：课表与日程摘要使用受文件保护、排除备份的 Application Support；日程随 Moodle 登录数据清除，考试摘要随门户登录数据清除。下载默认保存在 Documents/Downloads，也可使用用户授权的外部目录；更换目录不迁移旧文件，外部文件不参与限时清理。
- **锁屏**：`LocalAuthentication` 的设备密码 / 生物识别，App 只收到成功或失败。
- **隐私清单**：`PrivacyInfo.xcprivacy` 声明不追踪、不收集数据，仅使用 UserDefaults 保存本机偏好。
- **网络**：网页和日程读取沿用官方同源会话；诊断向公开首页发不带 Cookie、无缓存、无重定向的 HEAD。暗色适配只按需读取当前页面 CSS；没有自建后端或统计服务。

发现安全问题请按 [SECURITY.md](SECURITY.md) 私下报告，不要公开提交 Issue。

## 已知限制

1. 四个站点需要在 App 内**分别登录**；Safari 的会话不会自动迁入。
2. 校园站点通常需要**校园网或学校认可的访问方式**，校外网络可能无法解析。
3. 学校页面、SSO、课表结构与 Moodle 只读 API 可能调整，届时需要更新深链或识别器。部分课程信息缺失时会提示结果不完整，仍应在官方页面核对。
4. 班车倒计时是**计划发车时间**，没有实时 GPS；时刻表来自用户提供的 2026-10-12 表，教学周需手动确认。
5. 免费个人团队签名的描述文件 **7 天过期**。
6. 网页暗色适配不保证覆盖所有学校组件，可按站点恢复原色；真实校园页受校园网／VPN 条件影响，合成测试不替代完整真机验收。
7. App 不代填、不代提交任何业务；成绩、考勤等敏感页面只在你本机浏览。
8. 分层 Liquid Glass 图标工程（`docs/design/AppIcon.icon`）需要 Xcode 27；默认使用 PNG 图标，以便在 Xcode 26 上构建。

## 文档

| 文档 | 内容 |
| --- | --- |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 分层、会话隔离、跨站路由、时序 |
| [docs/RESEARCH-SPEC.md](docs/RESEARCH-SPEC.md) | 站点能力边界、信息架构与中文文案规格 |
| [docs/design/DESIGN.md](docs/design/DESIGN.md) | 配色、图标、动效与设计来源 |
| [docs/RELEASE-1.4.md](docs/RELEASE-1.4.md) | 1.4 变更与验收 |
| [docs/IMPROVEMENTS-20261021.md](docs/IMPROVEMENTS-20261021.md) | 1.1 审查问题与修复对照 |
| [docs/QA-REPORT.md](docs/QA-REPORT.md) | 独立 QA（P0=0 / P1=2，已修复） |
| [CHANGELOG.md](CHANGELOG.md) | 版本记录 |

## 参与贡献

欢迎 Issue 与 PR，请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。

几条硬性边界：

- 只读取课表、Moodle 待办和 Student 考试已明确授权的字段；不扩展到成绩、账号、通用页面采集、写业务接口、绕过验证码/证书、硬编码凭据或伪造数据；
- 不提交真实学生数据、截图中的账号信息或设备标识；
- 涉及网页注入的改动必须说明作用域，并补充回归测试；
- 提交前运行 `python3 Tools/gen_project.py`、`python3 Tools/check_project.py` 与模拟器构建。

## 许可与声明

- 代码以 [MIT License](LICENSE) 发布，Copyright © 2026 Tony Zhu (Optmst0118)。
- 第三方组件与许可见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)：Dark Reader（MIT）。
- 「GTIIT」「广东以色列理工学院」、校徽与相关标识属于学校；本项目只在描述用途时使用，不主张任何权利。图标与界面为**非官方改绘**，不代表学校。若你是校方并希望调整使用方式，请通过 Issue 联系。

> 本项目不提供任何形式的担保。学校系统变化、账号安全与预约结果请以官方为准；请勿把本项目的 Issue 当作学校 IT 支持渠道。

## English

An unofficial, open-source iOS client for GTIIT campus services, written in SwiftUI. It wraps the four official websites in isolated, persistent `WKWebView` sessions and adds native features the web cannot provide: a campus shuttle schedule with countdowns, download management with PDF preview, an app lock, appearance settings and network diagnostics.

**Highlights**

- Five tabs: Shuttle · Portal · Learning · Booking · Me; booking switches between practice rooms and sports venues.
- Per-site persistent `WKWebsiteDataStore` (iOS 17+), cross-site routing only for user-initiated GET links, real popup windows, and downloads that keep the original POST/cookie context.
- No analytics, backend or account storage. Optional, explicitly confirmed timetable imports read registered course fields only and stay on the device. All sessions live in the WebKit sandbox and can be cleared per site.
- Protected local timetable and Moodle summaries; current-term active courses only, 30-minute automatic refresh, manual refresh, and cache removal with Moodle website data.
- Persistent shortcut management in Settings → General. Native context menus keep a proportional 12% card enlargement, matching continuous corners, subtle background blur/dimming, and document-only grid lift targets. Settings → Timetable uses standard push navigation.
- No third-party package dependencies; Dark Reader (MIT) is bundled only for optional web dark appearance.

**Build**

```bash
open GTIIT.xcodeproj   # Xcode 26+, iOS 17+ deployment target
xcodebuild -project GTIIT.xcodeproj -scheme GTIIT -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

**Disclaimer** — Not affiliated with GTIIT. Names and emblems belong to the university. Use at your own risk; campus systems may change without notice.

## 致谢

- README 的组织方式参考了 [muster](https://github.com/ZacxDev/muster)（简洁定义 → 功能 → 快速开始 → 文档）与 [TUM Campus-iOS](https://github.com/TUM-Dev/Campus-iOS)（截图表格、贡献入口、许可声明）等开源项目。
- 网页深色外观使用 [Dark Reader](https://github.com/darkreader/darkreader)（MIT）。
- 感谢所有公开分享 iOS 网页容器、WebKit 与 SwiftUI 实践的开源作者。