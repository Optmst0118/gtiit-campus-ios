# 实时活动与 Widget 验证 · 2.1.0-beta.13 (94)

基线 `3587e4d`；第一阶段改动保存于 `0d4a609`。本轮仅涉及实时活动、班车 Widget 与隔离测试入口。

## 改动

- 班车锁屏与展开灵动岛共用大倒计时／目的地色块，橙色高亮；标题为方向，底部保留计划发车时刻与弱化班车号。删除旧轨迹、车辆位置装饰与图标。
- 课程采用相同结构与蓝色教室色块。锁屏整体 160pt，展开内容为灵动岛摄像头区域留出高度；计时 46pt／38pt、目的地 36pt／30pt，适配容器缩放。
- compact 显示方向或教室与倒计时，minimal 显示目的地或课程标识。
- 默认 Widget 保留 `ShuttleHomeWidget` kind，改为不依赖 Intent 的静态时间线；单独 `ShuttleConfiguredWidget` 保留方向与教学周配置。小号用两行，中号分两列。没有启用新的 App Group 权限。
- 课程生产调度和 Debug 合成测试共用 `CourseLiveActivityController.request`。清理已变更课程时先保存 issued 索引，避免取消任务后留下无法重试的旧键。

高度约束依据：[Apple Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities) 与 [ActivityKit](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)。超过 160pt 可能被系统裁切。

## 已完成的验证

- Debug 和 Release 的 App + Widget 模拟器 `xcodebuild` 均成功。
- `python3 Tools/check_project.py`：97 App Swift、12 Widget Swift，结构检查通过。
- `python3 Tools/check_localization.py`：716 tr、48 format、985 strings、3 Info.plist keys，通过。
- 完整 `python3 Tools/run_regression.py <SIMULATOR_UDID>` 最终 **573/573 通过**，包括两项系统容器高度约束；结果见 `../regression-results.json`。
- **真实 ActivityKit 立即创建课程**：系统返回 `active`，见 [system-activity.txt](system-activity.txt)。
- **真实 ActivityKit 预排课程**：合成课程 615 秒后上课，复用生产的 `start - 600` 计算，在 15 秒后安排激活；系统先返回 `pending`，18 秒后回报 `active`。这验证了系统预排创建与激活，不代表真机锁屏测试已完成。
- **真实已添加的小号 Widget**：原先 AppIntent 路径产生 `No AppIntent in timeline`、`CHSErrorDomain 1101`，该模拟器的扩展调用 Siri helper 被权限检查拒绝。不能据此断定所有真机的故障原因。切换静态入口后，原来已添加的 kind 成功迁移；chronod 接收 49 个时间线条目，见 [widget-timeline.txt](widget-timeline.txt)。默认入口不需要 App Group 或 Intent 解析成功。

## 尚未完成

Mac 的 UI 验证接口在本轮中途返回 `cgWindowNotFound`；Device Hub 和 Finder 均找不到可操作窗口。已请求恢复解锁并打开独立模拟器预览。最终锁屏、展开灵动岛、小号与中号桌面 Widget 的截图仍待补充，不能把旧截图或 App 内示例当作这些系统截图。

本轮没有真机安装；可配置 Widget 的 Siri helper 路径仍需在具备正常系统权限的环境单独核对。未把默认 Widget 的修复视为该路径已验证。

## 重复系统验证（仅 Debug／隔离模拟器）

```sh
SIMCTL_CHILD_UI_REVIEW_ACTIVITY=1 SIMCTL_CHILD_ACTIVITY_REVIEW_KIND=scheduled \
  xcrun simctl launch --terminate-running-process <SIMULATOR_UDID> io.github.optmst0118.gtiit.beta
```

`ACTIVITY_REVIEW_KIND=course` 立即创建课程，`scheduled` 15 秒后按课前 10 分钟逻辑预排，`shuttle` 创建班车，`end` 结束示例，`widget` 请求 WidgetKit 重新加载。除 `widget` 外会先结束该 Beta App 现有活动，不修改个人课表。结果和 ActivityState 更新写到模拟器 App 的 `Documents/activity-review.txt`。

也可先启动示例页面，再使用 `gtiit-beta://activity-review?kind=course` 等 Debug URL；系统可能出现打开 App 的确认。Release 不包含上述入口。

界面示例在“设置 → 学习与提醒 → 课表 → 实时活动示例”。生产功能继续只预排接下来两节课，前台、课表更新与重新打开 App 时补排；没有长期后台无限续排机制。
