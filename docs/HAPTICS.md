# 触感反馈（Haptics）

集中实现：GTIIT/Core/Haptics.swift

## 当前触发位置

- 所有 CardPressStyle 卡片按下：轻触感。
- Tab 切换：selection。
- 预约分类切换：selection。
- App 解锁成功：success。
- 网页下拉刷新：轻触感。

## 调整方式

- 修改 Haptics.light / medium 的 intensity。
- 把某处 Haptics.light() 换成 selection()、success() 或 warning()。
- 总开关：设置 → 通用 → 触感反馈，写入 settings.hapticsEnabled。
- 如果某个交互太频繁，直接删除对应调用点。
- 所有调用统一经过 Haptics，不会散落系统 API。

## 注意

模拟器没有真实触感，需要真机验证。UIImpactFeedbackGenerator 每次触发前 prepare，减少首次延迟。
