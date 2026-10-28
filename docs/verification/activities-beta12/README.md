# 2.1.0-beta.12（93）排程与实时活动

公共排程：展开区紧凑横行、统一图标、文本及分隔线，Device Hub 截图 booking-expanded.png。

实时活动：共享锁屏布局（160 点基础高度），iOS 26 glassEffect；橙色班车目的地块、蓝色课程教室块。activity-examples.png 为 App 内示例，使用相同 Summary 组件，不是系统锁屏截图。

86 项相关检查通过，包括课程提前 600 秒、地点、稳定身份、两节上限和无课表情况。App/Widget 均构建、结构、本地化和签名检查通过。

iOS 26 使用 Activity.request(... style: .standard, alertConfiguration: ..., start: ...) 系统预排下一两节课程，前台每分钟、重新打开/回到前台、课表变更补排。用户关闭开关会清除本类型活动；修改课名或教室会替换已安排的活动。已发起身份跨启动保存，避免用户移除后立刻重建；课程开始后状态变更，前台清理过期活动。不开 App 不会无限续排，系统容量不足会在之后前台重试。较早 iOS 仅在前台进入 10 分钟窗口时启动。

本轮未在真实锁屏上等待 10 分钟验证系统启动，不能将计划/布局检查描述为实测锁屏自动触发通过。

Apple 参考：https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
本地 Xcode ActivityKit swiftinterface 确认定时 request 的 iOS 26 可用性及 start 参数。
