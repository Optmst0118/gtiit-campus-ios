# Duo beta.3（109）

- 最终实现：iPhone直接进入系统TabView，移除自定义UISplitViewController容器和宽屏强制隐藏tabBar；iPad保留原实现。右侧平板菜单尝试已撤销。
- 现有iPhone Duo iOS27.1模拟器：折叠横屏显示紧凑图标玻璃栏，工具空间不足时由系统溢出；展开横屏显示右侧玻璃标签栏及独立工具按钮，校园标签点击通过。截图来自同源隔离预览包，合成数据。
- top-canvas回归227/227通过，Release构建及App/扩展签名、版本、App Group校验通过。
- Air同Beta Bundle ID原位安装109；未卸载或清理用户登录/缓存。
- 苹果依据：https://developer.apple.com/videos/play/tech-talks/111461/ 、https://developer.apple.com/videos/play/tech-talks/111462/ 、https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo 。让标准容器协调导航/工具/标签栏及动态安全区，不手工搬运bar。
