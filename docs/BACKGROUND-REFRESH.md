# 后台任务与刷新审计（alpha.27）

范围只覆盖会受后台执行影响的功能；下载、PDF、主题、锁屏等不需要后台刷新的模块不展开。

## 结论

当前 App 没有注册任何应用级后台任务：

- Info.plist 没有 UIBackgroundModes；
- 没有 BGTaskScheduler / BGAppRefreshTask / BGProcessingTask；
- 没有后台 URLSession；
- 没有远程推送（APNs）；
- 没有持续后台定位。

真正会在 App 不活跃时继续工作的只有系统管理的 WidgetKit timeline，以及已经排定的本地通知。Live Activity 的倒计时由系统绘制，不需要 App 后台刷新。

## 统计表

| 机制 | 代码/配置 | 触发方式 | 频率 | 是否需要 |
| --- | --- | --- | --- | --- |
| Widget next bus | GTIITWidgets/ShuttleHomeWidget.swift | WidgetKit TimelineProvider | 请求 after 600 秒；系统决定实际时间 | 需要，系统管理 |
| Widget 定位 | NSWidgetWantsLocation=true；WidgetLocationFetcher | 仅 Widget 被视为使用中时 | 每次 timeline 请求 | 需要，系统管理 |
| Live Activity | NSSupportsLiveActivities=true；ShuttleLiveActivityController | 用户开始活动；系统显示时间 | 无后台刷新 | 可选，系统计时 |
| 班车本地提醒 | ShuttleNotificationCenter | 用户主动设置 | 精确到发车前的 leadMinutes | 可选，系统投递 |
| Moodle 摘要 | MoodleUpcomingStore | 前台 launch/active/视图 task | 1800 秒，且只在 App 活跃时 | 当前前台功能需要，不是后台任务 |
| 考试摘要 | StudentExamStore | 前台 launch/active/视图 task | 1800 秒，且只在 App 活跃时 | 当前前台功能需要，不是后台任务 |
| 启动预热 | AppModel | 前台首帧后的 Task.sleep | 650 / 700 / 1500 / 1200 ms | 只是启动优化，不是后台任务 |
| 定位推荐 | CampusLocationRecommendation | ShuttleView 可见时 startUpdatingLocation | 页面可见期间 | 前台交互，不后台 |
| 时间线导出/日历 | 静态资源或前台读取 | 用户操作 | 无 | 不需要 |

## 哪些真的需要后台刷新

### 1. 班车 Widget：需要，但交给 WidgetKit

Widget 显示下一班和倒计时；用户期望回到主屏还能看到较新的班次。当前请求 10 分钟刷新：

- 由 WidgetKit 调度，不保证精确 600 秒；
- 地点读取只在 Widget 被视为使用中时可用；
- 没有 App Group 时，教学周/语言可能使用回退值。

这属于系统管理的后台刷新，不需要在 App 里注册 BGTask。

### 2. Live Activity：不需要应用后台任务

活动使用 ActivityKit，pushType 为 nil；倒计时由系统 Text(timerInterval:) 绘制。App 只在活动创建、恢复、语言/教学周设置变化时 reconcile；被挂起后不会运行代码。发车时间到达后活动变为过期/结束状态。

### 3. 班车提醒：不需要应用后台任务

本地通知由 UNUserNotificationCenter 在指定时间投递，App 不需要醒来。当前最多保留 48 条同类请求；教学周或语言变更后需要下次前台 reconcile 更新内容。

### 4. Moodle 摘要 / 考试摘要：当前不需要后台刷新

两者都是 1800 秒的前台刷新，且视图进入后台会 cancel：

- 数据只在 App 前台展示；
- 当前没有 Moodle/考试相关的后台通知或 Widget；
- 因此后台刷新不会改善任何现有可见结果，反而增加耗电、WKWebView 进程和失败重试。

如果以后要做“Moodle 截止日期通知”或“考试 Widget”，才需要评估后台刷新；但用 WKWebView 在 BGAppRefreshTask 里重新登录/抓取并不可靠，也不符合现有只读边界。

### 5. 定位：不需要后台定位

ShuttleView 使用 When In Use 定位，离开页面就 deactivate；Widget 的定位由 WidgetKit 提供，不是 App 持续定位。

## 当前限制

- WidgetKit 的 10 分钟是请求值，不是保证值；
- 通知内容是排定时的语言快照，App 下次前台会 reconcile；
- App Groups 当前默认关闭，Widget 的教学周/语言共享可能不完整；
- 没有远程推送，因此不存在服务端唤醒。

## 建议

1. 保持当前“无 BGTask”设计；当前功能集合不需要它。
2. 若要让 Widget 更精确，优先给 Timeline 提供未来多个发车 entry，而不是依赖 10 分钟轮询。
3. 若以后增加 Moodle/考试提醒，先争取学校 API；BGAppRefreshTask 只能做 best effort，不应承诺准点。
4. 若要让 Widget 读取最新教学周/语言，启用 App Groups 并重新签名。
5. 所有涉及后台的建议都应在真机上用 Instruments 的 App Launch、Energy、Network 模板复测。

## 审计依据

- GTIIT/Info.plist 中没有 UIBackgroundModes；
- 全仓库 Swift 中没有 BGTaskScheduler / beginBackgroundTask / background URLSession / APNs；
- GTIITWidgets/Info.plist 有 NSWidgetWantsLocation，但没有后台模式；
- ShuttleHomeWidget 的 timeline policy 为 .after(600)；
- MoodleUpcomingStore/StudentExamStore 的 refreshInterval 为 1800 秒，均绑定前台视图生命周期。
