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


## alpha.36 tuning

Confirmed taps use a rigid impact (default0.9); explicit save actions use medium impact(1.0); tab/picker changes use a softer impact(0.95). Success/warning/error retain system notification patterns. Events inside90ms are coalesced. The global switch and foreground check gate all effects. Card styles do not install gesture recognizers. Learning and booking trigger feedback inside the accepted button action, preserving native tap and scroll cancellation. Actual perceived strength depends on the device and iOS haptic settings and must be judged on hardware.

PDF's complete glass circle scales to1.065 while held and springs back(response0.26,damping0.7). Reduce Motion removes scale animation; Reduce Transparency uses a solid semantic surface. There is no extra post-save duplicate-download action.
