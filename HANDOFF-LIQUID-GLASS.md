# 液态玻璃状态栏修复任务（交接给更强 Agent）

## 目标

在 iPhone（iOS 26+，含 Dynamic Island）上，让页面标题栏的液态玻璃材质连续覆盖状态栏和 Dynamic Island 区域，而不是只在导航栏那一条。

要求：

- 所有主页面一致：Shuttle / Portal / Learning / Booking / Me；
- push 后的页面同样一致；
- 浅色/深色模式都保持正确的对比度和颜色；
- 竖屏、横屏、iPhone 与 iPad；
- 不改变网页内容、导航行为、Tab/Sidebar、Session 或测试基线；
- 不使用会让页面变灰、变白或出现第二条 material 的临时覆盖层。

## 当前代码状态

仓库：/Users/zhufengyi/Documents/ChatGPT/探索/GTIIT-iOS-App  
基线：dbfab00 / 2.0.2-beta.2 build 71  
构建：macOS 27.0.1，Xcode 27.1，iPhone Air 真机

关键文件：

- GTIIT/Views/RootTabView.swift
  - RootTabView 顶部 overlay 当前是纯色 page canvas：Rectangle fill Theme.pageBackground，frame height = geometry.safeAreaInsets.top。
  - 该层是为了防止状态栏区域出现白色，但它不是液态玻璃。
  - NativePrimaryController 管理 UISplitViewController、Sidebar 和浮动 toggle。
- GTIIT/Core/Theme.swift
  - configureNavigationAppearance 当前使用系统默认透明/滚动边缘 material。
  - pageUIColor / pageBackground 是页面底色。
- GTIIT/Components/WebViewContainer.swift
  - WebView 宿主和 navigationScrollView；滚动时导航栏折叠由 UIKit/SwiftUI 协同。
- GTIIT/Components/NativeWebPageView.swift
  - 共享 push 网页。
- GTIITApp.swift
  - Theme.configureNavigationAppearance 在 App 启动时调用。

## 已经试过但失败的方向

1. 自定义 UINavigationBarAppearance backgroundEffect = systemUltraThinMaterial：
   - 只在导航栏区域出现一块灰白 material；
   - 状态栏仍是页面底色，颜色割裂。

2. RootTabView 覆盖 ultraThinMaterial：
   - 在白色 window 上采样，结果发灰；
   - 和导航栏蓝色不一致。

3. Rectangle fill pageBackground glassEffect regular：
   - 运行时页面基本空白/异常，不能使用。

4. UIViewRepresentable + UIVisualEffectView UIGlassEffect regular：
   - 能编译安装，但状态栏变白/洗掉，和标题栏不一致；把 container 设 pageUIColor 也没有解决。

5. 在 Theme 中给所有 bar slot 设置同一个 material：
   - 破坏颜色，用户明确要求回退。

## 建议的排查/实现路线

1. 用 View Debugger / Web Inspector / Instruments 确认：
   - 标题栏的蓝色究竟来自透明导航栏后面的 page canvas，还是系统 glass 效果；
   - 状态栏区域的白色来自 UIWindow 背景还是导航控制器的 layer；
   - UISplitViewController 的 primary/secondary/child navigation controller 谁拥有顶部 safe area。

2. 优先让 page canvas 本身延伸到 window 顶部：
   - 给 UIWindow / root view / split view 设置正确背景；
   - 检查 UINavigationController.extendedLayoutIncludesOpaqueBars、edgesForExtendedLayout、additionalSafeAreaInsets；
   - 确认 SwiftUI NavigationStack 的 toolbar 是否在状态栏下创建独立 backdrop。

3. 若要复制系统 glass：
   - 使用 UIVisualEffectView + UIGlassEffect，但必须让它采样 pageBackground，不是白色 window；
   - 或使用 UINavigationBarAppearance 的 backgroundEffect 并让导航栏 frame 真正延伸到屏幕顶部；
   - 不允许再出现两块独立 material 的接缝。

4. 状态栏覆盖层需要和导航栏背景使用同一层，不能一个 UIVisualEffectView 叠在另一个 material 上。

5. 验收截图：

- 浅色/深色；
- 竖屏/横屏（Dynamic Island 在左/右）；
- 每个 Tab；
- push 页（例如 Student Attendance、Moodle 课程、Booking 官方页）；
- 滚动前/滚动后导航栏折叠状态。

## 验收命令

~~~bash
cd /Users/zhufengyi/Documents/ChatGPT/探索/GTIIT-iOS-App
python3 Tools/check_project.py
python3 Tools/check_localization.py
python3 Tools/run_regression.py 0FC8885A-CE2A-4118-971E-97C2A718A5F7
xcodebuild -project GTIIT.xcodeproj -scheme GTIIT -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/GTIIT-UI CODE_SIGNING_ALLOWED=NO build
~~~

真机安装：Tools/install_device.sh

## 禁止事项

- 不要把状态栏改成纯白色/灰色 material；
- 不要破坏 RootTabView 的 canvas；
- 不要改变 WebView 会话、导航、Tab、Sidebar；
- 不要为视觉改动提升版本号；本任务属于修复，版本由 Lead 按 docs/VERSIONING.md 统一决定；
- 不要手工改 pbxproj。
