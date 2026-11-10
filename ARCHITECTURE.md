# 当前架构

快照：2.1.0-beta.21（build 102），`codex/navigation-2.1-beta`，2026-11-08。历史详细设计见 `docs/ARCHITECTURE.md`（1.11，不可作为当前状态权威）；版本和当前实现以源码为准。

## 应用与导航

- 原生 iOS 17+，Swift / SwiftUI、UIKit、WebKit；`GTIIT/App/GTIITApp.swift` 创建 `AppSettings`、`AppModel`，`Views/RootTabView.swift` 组织首页、学习、班车、预约、校园。iPhone使用系统TabView/NavigationStack，Duo横屏自动呈现侧边紧凑玻璃栏；iPad保留分栏；详见对应视图及 `docs/verification/rotation-beta6/`、`portrait-doublebar-beta9/`。
- `Models/SiteID.swift` 定义 Student、Moodle、练习房、体育和 Service Hub 五个站点；首次引导使用前四个。`Services/BrowserModel.swift`、`BrowserRouter.swift`、`WebDataStoreRegistry.swift` 负责 WebKit 导航、各站独立会话及清理；`WebAppearance.swift` 和 `Resources/WebAppearance/` 负责外观。Safari 会话不自动共享。提交、POST、认证、弹窗与 Cookie 必须保留原上下文。
- `Core/Localization.swift`、`Resources/CampusData/native-en.json` 及 `*.lproj` 处理本地语言；网页内容由原站负责。

## 应用内通知

- `CampusMessageStore` 由 `AppModel` 持有：接收确认的登录失效、六小时内预约、当天作业/考试摘要，以及系统已投递/点击消息。采用稳定标识去重、时间倒序、已读状态及受保护文件存储，保留最近200条与有界去重记录。相同登录失效状态跨重启不重复，重新登录后可开始新一次失效事件。
- 学习提醒复用 `StudyDailyPlan` 与系统每日提醒标识，考试31/14/7/3天里程碑继续合并每日摘要。数据更新及前台每分钟检查本地时间边界；消息生产不会增加学校网络请求。
- 首页铃铛只观察消息未读数；通知页不订阅学校业务Store、不使用整页/工具栏TimelineView、不在进入时读取服务器或重建业务卡片。入口使用统一的 `CampusDetail.inbox` 路径，点击消息按受约束的目的地路由。

## 本地学习数据

- `TimetableExtractor` 从门户识别课表，用户核对保存后交给 `LocalTimetable`。`StudentExamStore` 读取个人考试；`MoodleUpcomingStore` 在现有登录上下文运行 `Resources/CampusData/moodle-activity.js` 与 `moodle-upcoming.js` 获取作业和状态。缓存由 `ProtectedCampusCache` 管理；失败和部分结果需保留已有可信内容。`AcademicCalendar` 合并校历和个人考试；`CampusCalendarExport` 使用 EventKit 分别导出课表、假期与考试。
- `StudyDailyReminders` 基于已缓存的未提交作业和个人考试按校园日期生成每日系统通知，默认 09:00，设置可改小时和提前天数。iOS 的权限、通知容量和后台调度限制仍适用。`MoodleDeadlineReminders` 为旧提醒迁移/清理路径，核对当前调用再修改。`CampusMessageStore` 持久保存应用内消息事件，`CampusInboxView` 只渲染消息快照。业务采集与通知页打开无关。
- 系统后台刷新在允许时使用独立只读 WebKit 内核和既有 Moodle 会话，复用摘要及小组件更新路径；设备受保护数据不可用或启用应用锁时跳过。系统决定运行时机，超时及回到前台会取消该次读取。
- `CourseLiveActivityController` 按时间尝试预排未来课程；iOS 26+ 课前 15 分钟启动，系统可用容量限制实际预排数量。旧系统和后台补排受系统运行时限制。`ActivityLifecycleCleanup` 清理过期活动，不保证被系统挂起后准点结束。

## 班车、组件与共享

- `Models/ShuttleSchedule.swift`、`ShuttleTimelinePolicy.swift` 是计划时刻和时间线来源；`ShuttleLiveActivityController`、`ShuttleNotificationCenter` 和 `ShuttleReminderPlan` 负责活动、通知和路由。班车显示计划发车，不表示实时位置；`CampusLocationRecommendation` 只共享附近方向和时间，不保存原始坐标，超出学校范围不推荐。
- `GTIITWidgets/` 包含班车与课程 Live Activity、班车及学习桌面组件；共享视图在 `ShuttleActivityPresentation.swift` / `WidgetStyle.swift`。`Core/AppGroup.swift` 使用 `group.io.github.optmst0118.gtiit.beta`；beta.20/21 的签名与 App Group 已有真机验证，但仍需为当前构建重新核对 entitlement 与 profile。组件共享最小只读摘要。
- Beta App `io.github.optmst0118.gtiit.beta`、Widget `io.github.optmst0118.gtiit.beta.widgets`、URL scheme `gtiit-beta`；与原版并存。`Tools/gen_project.py`、`widget_project.py` 生成工程，`Tools/version.json` 为版本源。

## 下载、隐私与恢复

`DownloadCoordinator`、`DownloadLocation`、`PDFPreviewCoordinator` 使用原 WebKit 会话处理 PDF 预览、下载及用户选定目录；下载索引独立于保存目录。`LocalAuthenticator` / App 锁及 `WebDataStoreRegistry` 处理本地保护与会话清理。避免重放 POST 或一次性链接、覆盖文件或卸载清理用户数据。

## 考试组件与日期路由（2.4）

`ExamWidgetSnapshot` 是 App Group 内的只读、语言无关摘要，App在考试更新及语言切换时同步。`ExamHomeWidget` 提供三种尺寸，系统时间线覆盖校园零点、考试开始和结束；通过 `gtiit-beta://calendar?date=YYYY-MM-DD` 进入校历选中日期。应用内考试使用当前栈继续进入校历；`CampusWebRoute.replacesStack` 仅允许跨入口重置，当前业务内部追加路径。设置统一在首页类型化路径下；保留原偏好键，不迁移登录或清空缓存。
