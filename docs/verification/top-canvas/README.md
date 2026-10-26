# 连续顶部 canvas 与原生滚动边缘效果验证

2026-10-26。请求基线 dbfab00 / 2.0.2-beta.2 build 71；实际工作起点 c12a278（后续仅文档／验证记录）。macOS 27.0.1、Xcode 27.1。产品改动仅在 RootTabView.swift。

## 根因与修复

先对隔离 UIReview App 使用只读 LLDB UIKit View Debugger，读取 recursiveDescription、窗口坐标、安全区与解析后的背景颜色。没有将调试用内部类名或调试代码加入产品，也没有使用 Instruments 性能录制。

| 状态 | 导航宿主窗口起点 | 顶部系统效果起点 | 窗口顶部安全区 |
| --- | --- | --- | --- |
| 修复前，静止 | y=62 | y=62 | 62pt |
| 修复后，静止 | y=0 | y=0 | 62pt |
| 修复后，滚动 | y=0 | y=0 | 62pt |

浅蓝来自 Theme.pageUIColor（RGB 0.95 / 0.97 / 0.98）。静止时系统顶部 ScrollEdgeEffectView alpha=0，滚动后 alpha=1；这不是一块常驻蓝色 glass。原 native 宿主没有忽略顶部安全区，且根部另有纯色 overlay，导致系统效果从状态栏下方才开始。

修复让 NativePrimaryNavigation 忽略垂直容器安全区、删除独立顶部 overlay；现有 page canvas 与 UIKit 原生滚动边缘效果共同覆盖到窗口顶端。横向安全区不变，控件仍由 UIKit 安全区定位。没有新增 UIVisualEffectView、UIGlassEffect 或第二层 material；Theme、WebViewContainer、会话和导航实现未改动。

原始摘录：[修复前](before-view-hierarchy.txt)、[修复后静止](after-rest-view-hierarchy.txt)、[修复后滚动](after-scrolled-view-hierarchy.txt)。

## 验证

- 完整回归 **385/385**（保留原 352 项，新增 33 项），见[结果](../regression-results.json)。
- 专项模式覆盖全部五个 Tab 的浅／深色导航几何、安全区，以及 Moodle、房间预约、体育预约的真实应用 push 路由；确认四个 WKWebView 对象未重建。班车原本隐藏系统导航栏，继续保留。
- iOS 26.5 iPhone：横屏 Dynamic Island 在[左侧 47/47](iphone-landscape-left-results.json)、[右侧 47/47](iphone-landscape-right-results.json)。
- iOS 26.5 iPad： [竖屏 47/47](ipad-portrait-results.json)、[横屏 47/47](ipad-landscape-results.json)，保留原生 Sidebar。
- Tools/check_project.py、Tools/check_localization.py、Release 构建、Tools/verify_bundle.py 均通过；App 与 Widget 的版本、签名与 profile 一致。App Groups 仍沿用原有未启用配置。
- 独立 UIReview 实际检查了原生页面、设置 push 与滚动折叠、门户横屏隐藏标题栏、深色横屏 push 和 iPad Sidebar；截图由 Device Hub 原始捕获，未处理图片。

视图专项测试使用隔离网页 fixture，不替代实际校园网登录与业务内容验收。滚动状态通过系统辅助功能 Scroll Down 操作确认，没有录制连续手指动画。一次工具坐标滚动触发 UIKit 手势异常，改用系统辅助功能滚动后完成检查；未据此声称排除了所有系统手势问题。iPad push 几何测试等待目标 Tab 切换稳定后再检查，避免将过渡帧作为最终布局。

## 截图

- [修复前：浅色竖屏](build71-before-light-portrait.png)
- 修复后竖屏：[学习浅色](after-learning-light-portrait.png)、[预约深色](after-booking-dark-portrait.png)、[班车浅色](after-shuttle-light-portrait.png)、[门户浅色](after-portal-light-portrait.png)
- 修复后横屏：[门户／岛在左侧](after-portal-light-landscape-left.png)、[深色设置 push／岛在右侧](after-settings-dark-landscape-right.png)
- iPad：[深色横屏](after-ipad-dark-landscape.png)、[浅色竖屏](after-ipad-light-portrait.png)

## 交付

按任务交接约定不提高版本，仍为 **2.0.2-beta.2 build 71**；以 Git 提交区别本次修复。Release 已覆盖安装到 iPhone Air，devicectl 再次确认设备上是 2.0.2 (71)，未卸载或清理用户数据。真机系统为 iOS 27.0.1；远程启动因设备锁定被系统拒绝，真机前台启动尚未确认。iOS 26 的布局证据来自上述 26.5 独立模拟器。
