# GTIIT 校园助手（iOS）

把 GTIIT 的四个官方网页放进一个 iOS App：底部四个标签页切换，主体全部是「网页套壳」，原生只负责导航外壳、会话管理、加载状态与错误提示。

> 这是一个**非官方**的学生自制客户端，不是学校发布的 App，也与学校没有隶属关系。它不读取页面数据、不保存账号密码、不代填也不代提交任何业务。详见 [docs/RESEARCH-SPEC.md](docs/RESEARCH-SPEC.md)。

---

## 1. 快速开始

```bash
# 需要 Xcode 16 或更新版本（工程使用 objectVersion 56，向下兼容到 Xcode 14）
open GTIIT.xcodeproj
```

然后在 Xcode 里：

1. 选一台 iOS 17+ 的模拟器或真机，⌘R 运行。
2. 工程已经写入了本机的个人开发团队（`DEVELOPMENT_TEAM = YOUR_TEAM_ID`，免费 Personal Team）。换账号时改 `Tools/signing.env` 后运行 `python3 Tools/gen_project.py`，或在 Xcode 的 Signing & Capabilities 里直接选新的 Team。
3. 想把 Bundle Identifier 换成自己的：改 `Tools/gen_project.py` 里的 `BUNDLE_ID` 后重新生成。

### 1.1 装到真机（已连接 iPhone）

```bash
./Tools/install_device.sh
```

脚本会：用 `-allowProvisioningUpdates` 自动续签/注册设备 → 构建 → 安装 → 启动。

> **首次安装需要手动信任证书**：iPhone → 设置 → 通用 → VPN 与设备管理 → 「Apple Development: …」→ 信任。本机已经完成过这一步，之后直接跑脚本即可。
>
> 免费个人团队的描述文件 **7 天过期**（本次到 2026-10-28），到期后 App 打不开，重跑脚本自动续签。真机首次运行还需要在 iPhone 上开启「开发者模式」（设置 → 隐私与安全性 → 开发者模式）。

### 1.2 模拟器运行与截图

```bash
xcodebuild -project GTIIT.xcodeproj -scheme GTIIT -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/GTIIT-DD CODE_SIGNING_ALLOWED=NO build
xcrun simctl install booted /tmp/GTIIT-DD/Build/Products/Debug-iphonesimulator/GTIIT.app
xcrun simctl launch booted io.github.optmst0118.gtiit
xcrun simctl io booted screenshot /tmp/gt.png
```

截图（iPhone 17 / iOS 26.5 模拟器）：

| 首次启动 | 学生门户（跳转 Microsoft 登录） | 预约（Booked 登录） |
|---|---|---|
| ![welcome](docs/screenshots/01-welcome.png) | ![portal](docs/screenshots/02-portal.png) | ![booking](docs/screenshots/03-booking.png) |

| 我的 | 学习（Moodle 登录） |
|---|---|
| ![me](docs/screenshots/04-me.png) | ![learning](docs/screenshots/05-learning.png) |

> Xcode 27 里模拟器窗口叫 **Device Hub**（`/Applications/Xcode.app/Contents/Applications/DeviceHub.app`），不再有独立的 Simulator.app。

开发期调试启动参数（仅 DEBUG 生效）：

```bash
SIMCTL_CHILD_GTIIT_SKIP_WELCOME=1 SIMCTL_CHILD_GTIIT_TAB=me xcrun simctl launch booted io.github.optmst0118.gtiit
# GTIIT_TAB 取值：portal / learning / booking / me
```

命令行构建（需先同意 Xcode 许可）：

```bash
sudo xcodebuild -license accept      # 只在本机第一次需要
xcodebuild -project GTIIT.xcodeproj -scheme GTIIT \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

> 本次交付环境里 Xcode 许可证尚未同意，因此工程是用 `swiftc -typecheck`（iOS 17 模拟器 SDK）验证的：24 个 Swift 文件 **0 error / 0 warning**。第一次在 Xcode 打开时如提示许可，点同意即可。

## 2. 四站与四个标签页

| 标签 | 承载内容 | 首页 URL |
|---|---|---|
| **门户** | 学生门户 Dashboard（学期、课程、考试，成绩/选课/考勤/申请都从这里进） | `https://students.gtiit.edu.cn/` |
| **学习** | Moodle Dashboard（课程、Assignment/Quiz、日历、服务空间） | `https://moodle.gtiit.edu.cn/moodle/my/` |
| **预约** | 顶部原生分段：**练习房 / 讨论室**（Booked）↔ **体育场馆**（mike-x） | `https://roombooking.gtiit.edu.cn/Web/dashboard.php` / `https://gtiit.mike-x.com/0x2Rg` |
| **我的** | 原生页：站点与会话管理、快捷深链、锁定、说明与隐私 | — |

四个站点各自的网页内核常驻内存，**切换标签不会重新加载页面**，滚动位置与表单内容都保留。

## 3. 为什么是「网页套壳」

研究结论（详见 [docs/RESEARCH-SPEC.md](docs/RESEARCH-SPEC.md) 与两份原始资料）：

- 学生门户：网页功能完整，但第三方客户端接入需要学校许可与 OAuth 注册，**尚未获得**；
- Moodle：只能浏览器登录，**移动令牌/自有回调未验证**，不能假装已经打通；
- 房间预约：Booked 标准 API 在本校**明确关闭**；
- 体育中心：只确认到会员邮箱登录关口，字段与流程未验证。

所以首版把「能稳定使用的官方网页」原样装进 App，而不是用原生界面重画一半功能、再显示"暂无数据"。原生只做网页做不到的事：多标签、会话隔离、加载进度、错误解释、下载转分享、生物识别遮挡、快捷深链。

## 4. 已实现

**网页容器**

- 每站一个持久化 `WKWebsiteDataStore(forIdentifier:)`（iOS 17+），会话隔离、重启保留、可单独清除；
- 顶部原生铬：后退 / 前进 / 标题 + 域名 + 锁标 / 刷新 / 更多菜单；2pt 加载进度条；
- 下拉刷新、加载占位、可操作的错误页（区分无网络、DNS 解析失败、超时、证书失败）；
- `target=_blank` 在同一个 WebView 内打开，保证学校 SSO 不被弹窗机制打断；
- 跨站链接自动路由：Moodle 里点到门户链接 → 自动切到「门户」标签，不再"串站"；
- `tel:` / `mailto:` 等非 http scheme 交给系统；
- 网页下载（Moodle 资料、作业附件）落到临时目录后弹系统分享，完成后立即提示；
- JS alert / confirm / prompt 原生弹窗；维护 30 秒无响应的白屏问题（进程回收自动重载）；
- 菜单：回到首页、刷新、强制刷新、分享、在 Safari 打开、站点说明、清除本站数据。

**导航与原生功能**

- 底部 4 Tab，首次进入某 Tab 才创建网页内核（不会冷启动同时打四站）；
- 「预约」内两套系统用原生分段切换，两个网页各自独立会话；
- 18 个深链快捷入口（成绩、选课、考勤、培养计划、请假、Moodle 截止、导出日历、rid=78 练习房、羽毛球馆…）；
- 站内说明卡：用途 / 首版边界 / 已知前提 / 入口地址；
- 首次启动 155 字完整免责声明 + **显式勾选确认**（不是默示同意）；
- 可选的 Face ID / Touch ID / 设备密码锁：切后台即遮住网页内容；
- 每个站点独立的网页数据清理，以及"全部清除"；
- 无埋点、无后端、无第三方 SDK；本地只存 2 个偏好与 4 个数据容器 UUID。

### 4.1 本轮验证状态（2026-10-21）

| 验证 | 方式 | 结果 |
|---|---|---|
| Swift 类型检查 | `swiftc -typecheck -swift-version 5 -sdk iphonesimulator -target arm64-apple-ios17.0-simulator` | **0 error / 0 warning**（`-warnings-as-errors` 亦通过） |
| 完整编译 | `swiftc -c -whole-module-optimization` | 产出 arm64 iOS 模拟器目标文件，链接 WebKit / SwiftUI / LocalAuthentication / SafariServices |
| 工程结构 | `python3 Tools/check_project.py` | 24/24 Swift 在 Sources、全部文件引用存在、UUID 唯一、scheme 与 target 一致、AppIcon 1024×1024 无 alpha |
| 隐私清单 | `plutil -lint` + 人工核对 | UserDefaults(CA92.1)、不追踪、不收集 |
| Xcode 完整构建（模拟器） | `xcodebuild -destination 'platform=iOS Simulator,name=iPhone 17'` | **BUILD SUCCEEDED** |
| Xcode 完整构建（真机） | `xcodebuild -destination 'platform=iOS,id=…' -allowProvisioningUpdates` | **BUILD SUCCEEDED**（自动生成 iOS Team Provisioning Profile） |
| 模拟器运行 | iPhone 17 / iOS 26.5 | ✅ 四站真实加载：门户→Microsoft 登录、Moodle 登录页、Booked 登录页；截图见 `docs/screenshots` |
| 真机运行 | iPhone Air / iOS 27.0.1 | ✅ 安装并启动成功（`devicectl device process launch`），WebContent 进程正常；登录流程由用户本人在 App 内完成 |

完整缺陷处置见 [docs/QA-FOLLOWUP.md](docs/QA-FOLLOWUP.md)。其中 2 个 P1（隐私清单、左滑清除确认）与 Release DEBUG 泄漏已修复。

## 5. 明确不做（研究红线）

- 不解析、不落库、不上传任何学业数据（成绩、考勤、课表、预约记录）；
- 不保存账号密码、不接管学校登录、不索要验证码；
- 不代填、不代提交（请假、评价、选课、预约、作业）；
- 不承诺"一次登录四站全通"；
- 不承诺自动同步、后台推送或定时轮询；
- 不绕过证书校验；不复用研究里看到的固定认证字符串或官方 App 回调。

## 6. 目录结构

```
GTIIT-iOS-App/
├── GTIIT.xcodeproj/                 # 可用 Xcode 直接打开（含共享 scheme）
├── GTIIT/
│   ├── App/                         # 入口、AppModel、设置、App 锁
│   ├── Core/                        # 主题、App 信息、顶层控制器定位
│   ├── Models/                      # SiteID、AppTab、QuickLink 目录
│   ├── Services/                    # 网页内核、数据容器、下载、路由协议
│   ├── Views/                       # 根 Tab、浏览铬、预约、我的、说明、欢迎、锁屏
│   ├── Components/                  # WebView 挂载、进度条、错误页、轻提示
│   ├── Resources/
│   │   ├── Assets.xcassets/         # AppIcon、AccentColor、LaunchBackground
│   │   └── PrivacyInfo.xcprivacy     # 隐私清单：不追踪、不收集，仅声明 UserDefaults
│   └── Info.plist
├── Tools/
│   ├── gen_project.py               # 由源码目录重新生成 pbxproj（含签名团队、scheme）
│   ├── signing.env                  # 本机 DEVELOPMENT_TEAM（免费个人团队）
│   ├── install_device.sh            # 构建 + 安装 + 启动到已连接 iPhone
│   └── make_icon.py                 # 重新生成 1024 AppIcon
└── docs/
    ├── RESEARCH-SPEC.md             # 研究结论 → 产品规格与文案（702 行）
    ├── ARCHITECTURE.md              # 分层、时序与关键决策
    ├── screenshots/                 # iPhone 17 / iOS 26.5 模拟器实拍截图
    ├── QA-REPORT.md                 # 独立复核报告（P0=0 / P1=2 / P2=16）
    └── QA-FOLLOWUP.md               # 复核问题的处置记录（逐条 已修 / 接受）
```

## 7. 关键实现

| 主题 | 位置 | 说明 |
|---|---|---|
| 会话隔离 | `Services/WebDataStoreRegistry.swift` | 每站保存一个 UUID，映射到独立 `WKWebsiteDataStore`；App 代码不接触任何凭据 |
| 网页内核 | `Services/BrowserModel.swift` | 导航策略、KVO 状态、错误文案、下载、JS 面板 |
| 跨站路由 | `App/AppModel.swift` `BrowserRouter` | 按 host 精确匹配站点，切换 Tab 后加载目标 URL |
| 底部标签 | `Views/RootTabView.swift` | `visitedTabs` 懒加载；Toast、锁屏、欢迎页、说明页挂载点 |
| 原生铬 | `Views/SiteBrowserView.swift` | 46pt header + 进度条 + 网页 + 错误层 |
| 站点清单 | `Models/SiteID.swift`、`Models/QuickLink.swift` | 新增站点/快捷入口只改这两个文件 |
| 隐私清单 | `GTIIT/Resources/PrivacyInfo.xcprivacy` | 不追踪、不收集；仅声明 UserDefaults（CA92.1） |
| ATS | `GTIIT/Info.plist` | 只放开 `NSAllowsArbitraryLoadsInWebContent`（网页内容，非全 App）：校园门户常见 http 内链/重定向，容器需要按官方页面渲染；App 自身没有任何自建请求 |

## 8. 已知限制（研究快照 2026-10-21）

1. 登录后的全量盘点未完成；页面结构可能变化，深链也可能失效（失效时用站内导航）。
2. 门户、房间、体育都没有获准的原生接口；Booked API 关闭，因此没有原生预约。
3. Moodle 移动令牌与自有回调未验证，没有原生课程/作业数据。
4. 没有后台推送与定时同步；打开 App 才能看到最新页面。
5. 校园站点通常需要校内网络或学校认可的访问方式；校外网络可能解析失败（错误页会说明）。
6. 证书校验不会被绕过；企业代理/自签证书环境可能打不开。
7. 深链清单里 `/transcripts`（成绩单）已从入口移除：该路由不在门户公开清单中，实际入口在 `/apps` 页面。
8. 教学评价的开放时间只写在页面提示里，App 不硬编码日期。
9. 生物识别锁只遮挡界面，不改变学校登录状态；清除网页数据等同于退出该站。
10. `window.open` 弹窗统一在主 WebView 内打开（对学校 SSO 最稳），依赖 window 句柄的 OAuth 弹窗仍需真机回归。
11. 跨站跳转只在用户点击/提交时路由，服务端 3xx 留在原 WebView；同一 URL 有 3 秒去重，避免来回抖动。

## 9. 真机验证清单（尚未执行）

按顺序做，每项都记录网络环境（校园 Wi-Fi / 蜂窝 / 校外）：

- [ ] 四站首页在三种网络下分别能否打开；
- [ ] 每个站点单独登录，杀进程重启后是否仍保持登录；
- [ ] 清除单站数据后，其他三站是否仍保持登录；
- [ ] Moodle 点开 `pluginfile.php` 资源，下载→分享→打开是否正常；
- [ ] 门户 → Moodle 的跨站链接是否自动切 Tab 且不丢当前页面；
- [ ] Office 365 登录跳转是否在 WebView 内正常完成；
- [ ] 开启 App 锁后切后台再回来，内容是否被遮住、Face ID 是否可解锁；
- [ ] 断网/飞行模式下错误页文案与重试是否可用；
- [ ] 横竖屏、iPad 分屏下 header 与 tab bar 是否正常；
- [ ] 深色模式下原生铬与欢迎页、我的页对比度是否正常。

## 10. 二次开发

- **加站点**：在 `SiteID` 里加 case（首页、别名、图标、配色、边界文案），在 `AppTab` 里决定它属于哪个 Tab，必要时在 `BookingTabView` 加分段。
- **加快捷入口**：往 `QuickLinkCatalog` 加一条即可，「我的」页与站点深链会自动生效。
- **改工程结构**（新增/删除 Swift 文件后）：

  ```bash
  python3 Tools/gen_project.py      # 重新生成 pbxproj 与共享 scheme
  ```

  生成器只用标准库，UUID 由路径哈希得到，重复运行结果稳定。
- **改图标**：`python3 Tools/make_icon.py`（需要 Pillow）。

## 11. 资料与版本

- 研究资料：`/Users/example/Documents/ChatGPT/探索/GTIIT-iOS`、`…/GTIIT-iOS-续研`（快照 2026-10-21，Asia/Shanghai）
- 产品规格与文案：[docs/RESEARCH-SPEC.md](docs/RESEARCH-SPEC.md)
- 架构说明：[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- 独立复核：[docs/QA-REPORT.md](docs/QA-REPORT.md)、处置记录：[docs/QA-FOLLOWUP.md](docs/QA-FOLLOWUP.md)
- 最低系统：iOS 17.0（多持久化 WebKit 数据容器的前提）
- 版本：1.0 (1)