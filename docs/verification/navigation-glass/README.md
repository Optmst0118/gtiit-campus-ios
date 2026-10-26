# 共享玻璃导航控件验证

2026-10-26。2.0.3-beta.1 build 72，前置提交 16c2649。macOS 27.0.1 / Xcode 27.1，独立 iOS 26.5 模拟器。

## 实现

- 持久的 SidebarNavigationGlass 管理两个 44pt 点击目标，间距 12pt；一个 UIGlassContainerEffect 合并两个交互玻璃元素。在页面切换协调器中同时改变返回元素的位置、材质和可见性，取消交互返回时由页面重新确认状态。
- nativeNavigationSurface 使用生命周期 probe 注册当前页面和返回动作，仅当导航栈确实属于主 split controller 且侧栏收起时替代原生返回。独立 sheet 栈不注册。没有轮询、重建导航栈或改写导航控制器 delegate。
- 正常页面调用原有 dismiss，网页内部返回／未提交编辑调用 NativeWebPageView 原有逻辑。隐藏系统返回时保留其交互 pop 识别器；代理转发其他手势判断，并在 push/pop 时展开代理链，防止循环。
- 背景 canvas 和原生滚动边缘效果不变；玻璃容器仅用于按钮，不是新增整条标题栏 material。VoiceOver 标签随语言刷新，Reduce Motion 取消形变。

## 检查

- 完整回归 **385/385** 通过。其后补充的专项断言只在宽布局执行；最终另补充了辅助功能标签刷新。
- iPhone 横屏专项 [61/61](iphone-island-left-results.json)：原有各 Tab／push／浅深色检查，增加按钮分离、不相交、系统返回隐藏、native pop delegate 可开始、点击返回后收回。
- iPad 横屏专项 [59/59](ipad-landscape-results.json)：实际收起侧栏后执行同样的返回／手势检查。
- Device Hub 人工操作：收起侧栏 → 我的 → 设置 → 语言 → 设置 → 我的，确认第三层只有一组控件、连续返回正常、回根后返回按钮消失。[设置截图](settings-collapsed-landscape.png)。
- 初次连续返回暴露代理循环，崩溃栈指向 BackGestureProxy.responds；已通过展开代理链修复，之后连续返回与专项均通过。一次完整运行的 PDF fixture 未就绪，单独重跑完整回归后 385/385 通过，没有修改 PDF 产品逻辑。
- 没有录制手指交互进度视频；手势可开始由系统识别器 delegate 断言检查。设备预览工具在后续旋转操作中出现 noWindowsAvailable，未将该操作当作成功验证。

最终源码专项[61/61](final-results.json)再次通过；Release 构建、App／Widget 版本、签名与 profile 校验均通过。

真机交付：Release 已覆盖安装至 iPhone Air，devicectl 确认启动成功；未卸载或清理登录、下载数据。设备系统为 iOS 27.0.1，布局专项使用 iOS 26.5。
