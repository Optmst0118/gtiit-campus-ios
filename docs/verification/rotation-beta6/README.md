# 2.1.0-beta.6（87）旋转检查

主内容固定在 secondary；不再移除 compact/secondary 中的控制器。由系统折叠/展开保留相同 HostingController 与导航内容。

183 项 layout 回归通过，包含连续 20 次紧凑/宽屏控制器身份保留；原生与网页上下边界、页面推入和共用 WebView 保留检查。

Device Hub 中手动从竖屏向左旋转四次返回竖屏，再旋转到横屏，学习页合成课程与作业仍可见。截图为独立测试数据。没有声称覆盖所有偶发条件，也没有进行真实账号作业操作。

- portrait-after-rotation.png
- landscape-after-rotation.png

Apple API 参考：https://developer.apple.com/documentation/uikit/uisplitviewcontroller
