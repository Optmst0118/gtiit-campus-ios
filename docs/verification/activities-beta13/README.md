# 实时活动与 Widget 验证记录（待完成）

## 当前结果

- 现有 beta.12 代码在 2.1.0-beta.13 改造前是干净的，基线提交 `3587e4d`。
- 最初的 beta.13 模拟器构建成功；后续为修正灵动岛裁剪和提供无需 App Intent 的默认 Widget 修改源码后，最终 App 构建尚未通过。
- `python3 Tools/check_project.py` 通过；最新 Widget 源码使用 iOS 模拟器 SDK 的 `swiftc -typecheck` 通过。
- 模拟器中曾重现默认 Widget 只有占位图。chronod 返回 `No AppIntent in timeline`；该模拟器的未签名扩展被 siri 服务以权限不足拒绝。不能据此断定真机问题原因。
- 新增静态配置默认 Widget 避开上述 Intent 解析路径；保留单独可配置的 Widget。需要在模拟器实际添加两种尺寸，验证新路径与旧安装的迁移。现阶段没有最终版本的 Widget 截图，也不能宣称已修复。
- 课程示例和计划计算逻辑已保留；未完成系统创建与预排触发验证。
- 本次会话的文件权限限制阻止 CoreSimulator 服务连接，`Tools/run_regression.py` 无法列出设备；最终 `xcodebuild` 因 Icon Composer 无法连接模拟器服务而失败。没有进行真机安装或验证。

## 可重复的 Debug 验证

仅在隔离的模拟器上操作，Debug 构建的测试入口会结束该 Beta App 的现有实时活动。先启动示例页面：

```sh
SIMCTL_CHILD_UI_REVIEW_ACTIVITY=1 xcrun simctl launch <SIMULATOR_UDID> io.github.optmst0118.gtiit.beta
xcrun simctl openurl <SIMULATOR_UDID> 'gtiit-beta://activity-review?kind=course'
```

`kind=course` 立即请求一个合成课程；`kind=scheduled` 通过与生产调度相同的 ActivityKit 方法预排一个 15 秒后启动、课前 10 分钟的活动；`kind=shuttle` 请求班车示例；`kind=end` 结束示例。请求结果写入该 App 的 Documents/activity-review.txt。须分别核对文件、系统锁屏与灵动岛，不要仅把收到 Activity ID 当作预排已触发的证明。URL 仅编译进 Debug 构建。

还需完成：App + Widget 最终模拟器构建、`python3 Tools/run_regression.py <SIMULATOR_UDID>`、Widget 小／中号实际添加截图、锁屏与灵动岛截图、课程立即创建及计划触发核对。
