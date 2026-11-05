# beta.21 (102) · 2026-11-05

- 修复定位建议两分钟后失效、时间线一天后才重建的错配。组件每十五分钟请求刷新；校区变化触发刷新。App 与组件只共享方向及时间，不共享原始坐标。手机已观测到新的 southToNorth 推荐。
- App 与组件共用未来截止窗口，排除已提交、过期与无截止时间项目，并使用用户设置的范围（真机当前为 30 天）。手机旧摘要中 4 条过期未交项目不再显示。
- assignments/study、timetable、exams 路由进入对应原生页面；班车方向参数保留。已截图验证作业页与课表页。
- 共用标题、内容、底部基线，直接复用 App 天蓝／暖橙色板。中组件截止时间右对齐，缩短重复作业标题。
- 24 张实际产品视图渲染覆盖大小、深浅色、中英文与两种附近方向；另保存模拟器画面。图片中数据为合成样例。comparison.png 为并排校验，preview.png 为简版预览。
- 115/115 Moodle、截止、提醒与跳转专项检查通过；25/25 班车位置及日期规则通过。工程、本地化、真机构建、签名和 App Group 校验通过。
- beta.21（102）已覆盖安装到配对 iPhone Air 并启动。用户解锁后摘要时间已推进，位置推荐也已更新；共享摘要 verified 仍为 false，不能宣称所有课程已完整在线核对。
- 补充后台刷新清理过期活动。后台准点唤醒仍由 iOS 控制，不保证强制终止 App 后准点结束。当前按 Moodle 作业来源展示，不新增独立手工线下作业数据库。

系统行为参考：[WidgetKit 位置更新](https://developer.apple.com/documentation/widgetkit/accessing-location-information-in-widgets)、[ActivityKit 后台更新与结束](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)。
