# 加载与一体化优化（alpha.30）

## 启动路径

1. SwiftUI 首帧：Tab、启动页、设置和缓存对象可用。
2. 后台并行创建门户、Moodle、预约、体育四个 BrowserModel。
3. 不可见的 WebPrewarmHost 为四个 WKWebView 提供窗口与布局，不接收触摸、不遮挡 UI。
4. 约 250ms 后启动 Moodle 摘要；考试摘要再延后 200ms。
5. LaunchPreparation 结束后移除隐藏 host；进入 Tab 时复用同一 WKWebView，不重新加载。
6. 有 Moodle 缓存时，约 1.2s 后检查登录页并自动点击现有 Office 365 SAML 链接。

## 策略

- 非阻塞预加载：没有全屏等待层。
- 并行四站预热：首次打开即加载 Student、Moodle、预约和体育。
- 摘要错峰：Moodle 摘要与考试摘要分开启动。
- 隐藏 host 生命周期：启动准备结束后移除，避免长期保留重复宿主。
- 统一 NativeWebPageView：进度条、加载占位、错误重试、预约背景色和 push 返回。
- 统一 NativePageIcon：Learning/Booking 使用相同图标尺寸和内容边距。
- MoodleAutoLogin：只点击现有 Office 365 链接，不填写密码。

## 完整性

- 四站仍是独立持久化数据容器。
- 官方登录、SSO、MFA、表单和页面行为不变。
- 清除数据、App 锁、下载、Live Activity、Widget 不改。
- 关闭“启动时预加载网站”时回到按需创建。

## 复测

用 Instruments App Launch 看首帧和内存；用 Points of Interest 看页面/摘要区间；用 Network 模板确认门户不重复加载。命令行 simctl launch 只代表进程启动，不等于首帧时间。
