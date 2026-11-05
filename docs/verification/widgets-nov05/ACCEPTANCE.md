# GTIIT 2.1.0-beta.20 · R1–R7

2026-11-05。沿用现有简洁 Apple 风格、透明锁屏活动，不新增说明段落。

| 需求 | 实现与验收范围 | 尚未满足 / 需真机确认 |
|---|---|---|
| R1 | 新增作业小/中/大组件；小组件两条、截止升序、课程去代码、相对日期和 +N。共享只读快照；清理账号同时清理共享摘要；未核对或过期时不会宣称全部完成。 | 当前工程无独立线下作业数据源，未新增录入或同步接口。线上/线下若均由既有 MoodleWork 提供则同一排序，不按类型过滤。真实账号的小组件同步待验证。 |
| R2 | 班车大小组件共用时间、倒计时、线路三级结构；未指定方向的小组件选择真正最早发车方向。 | 真实桌面容器与系统着色模式待确认。 |
| R3 | WidgetStyle 集中定义家庭组件的字体、间距、主次色、强调色与临近截止色；外边距和圆角由 WidgetKit 容器负责。 | 不强制修改原有锁屏活动的独立版式与透明材质。 |
| R4 | 家庭组件用系统背景和自适应文字/状态色；渲染实际视图，检查小/中 × 深/浅共八张。 | 大尺寸已编译，未做真实桌面截图；锁屏 accessory 与真实墙纸对比需真机确认。 |
| R5 | 提醒先说未交数量，再用完整句子给出课程、作业、日期和时间；考试也改为句子；去课程代码。 | 空态只在数据足够确认时表达无待交作业；无数据不能当作全部完成。通知实际投递待验证。 |
| R6 | 紧凑左区先提取 B104/304313 等教室号；ViewThatFits 整段选取，放不下时换楼栋或定位图标，不截断地址。左右仍为相同固定宽度。 | 已渲染教室号；真实灵动岛随系统布局需确认。 |
| R7 | 课程匹配保留到下课后 300 秒；班车恢复与结束时刻统一为计划发车后 300 秒（用户选择）；取消旧计时并检查活动 ID，避免旧计时结束新活动。 | 本地 Task 只在进程获运行时间时执行；App 被挂起/终止时不能保证准点结束。staleDate 或 after dismissal 不等价于定时结束，未用它们冒充完成。当前无 APNs 后端，本项未全量通过。 |

## 范围说明

保留 Moodle 数据结构和学校接口。为新组件补充只读共享摘要，并在读取失败、登录过期和账号清理时同步核对状态。App Group 已通过真机签名及 profile 校验，工程生成器默认开启，可用 GTIIT_APP_GROUPS=0 关闭。

## 验证方式

- `python3 Tools/check_project.py`
- `python3 Tools/check_localization.py`
- `SIMCTL_CHILD_REGRESSION_FOCUS=moodle python3 Tools/run_regression.py <disposable simulator>`
- `python3 Tools/render_widget_review.py <disposable simulator>`：直接渲染产品 SwiftUI View；familyOverride 仅指定 WidgetKit 只读环境在审核目标中的尺寸，不重写布局。输出不是桌面截图。
- Release 真机 xcodebuild + `Tools/verify_bundle.py`，验证 App/扩展版本、签名、描述文件、App Group。

浅色背景按白色、深色按 #1C1C1E 计算相对亮度：次要文字 6.25:1 / 8.48:1；蓝色强调 7.10:1 / 8.41:1；橙色状态 6.70:1 / 9.17:1。系统着色、亮度和墙纸不是此静态计算的覆盖范围。

## 最终结果

- Release 真机构建成功，App 与扩展均为 beta.20 / build 101；签名及 App Group 验证通过。
- Moodle / 提醒 / 活动专项回归 **104/104 通过**。
- 小/中 × 深/浅两类组件共八张实际 SwiftUI 渲染完成，教室 B104 与 304313 渲染完整。
- 已覆盖安装到配对 iPhone Air；系统接受启动请求。真实桌面、锁屏和账号数据仍需手机观察。
- 生命周期限制参考 [Apple ActivityKit 文档](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)：本地结束依赖 App 获得运行时间，远程结束需 APNs。
