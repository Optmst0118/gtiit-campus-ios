# 加载与一体化优化（alpha.27）

## 1. 启动路径

启动时不再等待四个网页全部准备完成。应用先显示真实 Tab，WebKit 预加载在后台分阶段进行。

阶段：

1. SwiftUI 首帧：只创建 Tab、当前原生页面和必要的设置/缓存对象；
2. 立即创建启动页对应的门户 WebView；
3. 门户开始加载后，约 700ms 再启动 Moodle/考试摘要；
4. 约 1.5s 后创建 Moodle WebView；
5. 约 2.7s 后创建预约与体育 WebView；
6. 低电量模式下跳过第 5 步。

这样避免了启动瞬间同时创建四个 WebView、四个网页进程和多个摘要抓取任务。

## 2. 采用的策略

- **非阻塞启动**：删除原来的全屏 LaunchPreloadView 等待层。真实 Tab 直接出现，网页在各自宿主里显示进度和占位。
- **分阶段预热**：只把启动页需要的内核放在首帧热路径；其他站点放到 Task 中按延迟创建。
- **摘要错峰**：Moodle 摘要先启动，依赖第二个隐藏 WebView 的考试摘要延后 650ms，减少主线程/网络争抢。
- **低电量自适应**：跳过后台预约/体育预加载，保留用户点击时的按需创建。
- **统一页面外壳**：Moodle 与预约的官方网页统一使用 NativeWebPageView，带进度条、首次加载占位和错误重试；卡片统一 push 导航。
- **统一起始图标**：学习/预约共用 NativePageIcon，58pt、20pt 内容边距、相同圆角。

## 3. 仍然保持的完整性

- 门户首页仍优先加载；四站会话仍各自持久化；
- 未预加载的站点在首次点击时按需创建，不丢登录态；
- 清除数据、App 锁、隐私遮罩、下载、Live Activity、Widget 等状态没有改变；
- 预加载只是改变时序，不改变浏览器导航策略或官方页面行为。

## 4. 如何复测

用 Xcode Instruments 的 App Launch 模板观察：

- 首帧到 RootTabView 可见的时间；
- WKWebView 首次创建数量；
- MoodleUpcomingStore / StudentExamStore 抓取开始时间。

也可以在本机用 xcodebuild 构建 Debug 模拟器包，冷启动后通过 os_signpost / Instruments 记录。命令行 xcrun simctl launch 只代表进程启动，不等于首帧时间。

## 5. 后续可试验项

以下未在本轮启用，避免破坏现有会话与业务边界：

- AppModel 从 Combine ObservableObject 迁移到 iOS 17 @Observable；
- 四站共享 WKProcessPool（需要真机验证进程复用与数据隔离）；
- 门户/Moodle 的 HTTP preconnect/prefetch（必须不绕过登录与同源策略）；
- 课程摘要从 JSON 文件迁移到 SQLite/增量索引（只有在摘要规模明显增大时才值得）；
- 真正的 Moodle 内容 API 与离线课程内容（需要学校侧接口/授权）。
