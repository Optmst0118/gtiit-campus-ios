# Moodle 原生工作台规格

> 依据 2026-10-21 的公开观察、现有网页实现与 1.x/2.0 构建、审核中暴露的问题整理。
> Moodle 没有可用的原生 API；本文的原生界面是导航与信息层级的原生化，课程内容、提交、测验、成绩和消息仍在官方 Moodle 页面完成。

## 1. 设计目标

1. 把 Moodle 的“网站导航”翻译成移动端的“任务导航”。
2. 首屏回答三个问题：我有哪些近期事项？我有哪些课程？我要去的功能在哪里？
3. 原生层只展示已缓存、已清理的摘要，不伪造课程、成绩、余量或提交状态。
4. 手机单列、平板自适应网格；动态字体、深色模式、VoiceOver 均可用。
5. 所有写操作均跳转官方页面，避免“看起来能提交，实际没有接口”的误导。

## 2. Moodle 页面与控件盘点

### 2.1 全局导航（Boost / 学校主题）

| 控件 | Moodle 位置 | 作用 | 原生处理 |
| --- | --- | --- | --- |
| Logo / 站点名 | 顶部 navbar | 回站点首页 | 站点首页工具入口 |
| Dashboard | 主导航 | 我的主页 | 我的课程 / 时间线入口 |
| My courses | 主导航 | 课程列表 | 我的课程入口 |
| Site pages | 主导航 | 站点页面 | 官方页面内浏览 |
| Notifications | 铃铛 | 作业、测验、论坛提醒 | 通知入口 |
| Messages | 气泡 | 课程与同学消息 | 消息入口 |
| User menu | 头像 | 个人资料、成绩、偏好、退出 | 个人资料 / 偏好设置入口 |
| Search | 搜索框 | 全站搜索 | 搜索入口 |
| Edit mode | 课程页开关 | 教师/管理员编辑 | 不在原生界面提供 |
| Help / About | 帮助菜单 | 使用说明 | 打开官方帮助页 |

### 2.2 Dashboard 区块

| 区块 | 内容 | 原生映射 |
| --- | --- | --- |
| Course overview | 课程卡片、All / In progress / Sort by 三个筛选、课程进度 | 原生课程分组（仅近期有事项的课程）；筛选仍在官方页 |
| Timeline | 按日期排序的作业/测验/事件 | 原生临近日程列表 |
| Calendar | 月/周/日事件 | 日历入口 |
| Recently accessed items | 最近访问的课程与活动 | 我的课程入口 |
| Latest announcements | 站点公告 | 官方页面 |
| Badges | 徽章 | 官方页面 |
| Online users | 在线用户 | 官方页面 |

### 2.3 课程页

| 控件 | 内容 | 原生处理 |
| --- | --- | --- |
| Course tabs | Course / Settings / Participants / Grades / Reports / More | 原生不复制全套管理标签页；提供课程/成绩入口 |
| Course sections | 周次或主题折叠区 | 官方页面 |
| Activities/resources | assign、quiz、forum、resource、folder、url、page、book、choicegroup、attendance、feedback | 原生只列出来自缓存的 assign/quiz 事项；其他类型打开官方页面 |
| Completion checkbox | 完成状态 | 官方页面 |
| Navigation block | 上一节/下一节、课程目录 | 官方页面 |

### 2.4 活动页

| 类型 | 典型控件 | 原生边界 |
| --- | --- | --- |
| Assignment | 截止时间、提交状态、Add submission、附件、反馈 | 只读摘要；提交在官方页 |
| Quiz | 开放/关闭时间、尝试次数、Last attempt、开始作答 | 只读摘要；作答在官方页 |
| Forum | 讨论串、回复、订阅 | 官方页 |
| Attendance | 出勤记录、问号状态 | 官方页；不自动判缺勤 |
| Choicegroup | 选择分组、取消选择 | 官方页；不预取删除动作 |
| Resource / Folder / URL | 文件、目录、外链 | 官方页；下载沿用 App 的下载策略 |
| Feedback / Page / Book | 表单、内容页 | 官方页 |

### 2.5 日历、消息、成绩、个人设置

| 功能 | 官方路径 | 原生入口 |
| --- | --- | --- |
| Calendar upcoming | /moodle/calendar/view.php?view=upcoming | 日历 |
| Calendar export | /moodle/calendar/export.php | 导出日历 |
| Grades | /moodle/grade/report/overview/index.php | 成绩 |
| Messages | /moodle/message/index.php | 消息 |
| Notifications | /moodle/message/output/popup/notifications.php | 通知 |
| Profile | /moodle/user/profile.php | 个人资料 |
| Preferences | /moodle/user/preferences.php | 偏好设置 |
| School timetable | /moodle/local/calendar/index.php | 学校课表 |
| Search | /moodle/search/index.php | 搜索 |
| Login | /moodle/login/index.php，支持 Office 365 SAML2 | 登录入口 |

## 3. 原生信息架构

Moodle Tab
- Header：Moodle / 课程学习 / 登录与同步状态
- Stats：近期事项 / 已核对课程 / 部分更新
- 临近日程（最多 5 条，可查看全部）
- 课程（按课程名聚合近期事项）
- Moodle 工具
  - 学习：我的课程、时间线、日历、导出、学校课表
  - 沟通：成绩、消息、通知
  - 账号：个人资料、偏好、站点首页、搜索
- Footer：最近更新时间、官方页面边界

### 手机

- 单列纵向滚动；
- 统计卡两列；
- 工具/课程为一列；
- 标题栏使用 large title，顶部刷新按钮；
- 内容宽度左右 20pt。

### 平板

- 内容最大宽度 1100pt；
- 统计卡三列；
- 课程与工具使用 LazyVGrid(.adaptive(minimum: 280))；
- 自适应 2–3 列，不拉伸单行文本；
- 所有列表保持 Dynamic Type。

## 4. 数据与状态

| 状态 | 来源 | UI |
| --- | --- | --- |
| 近期事项 | MoodleUpcomingStore.items 过滤 relevant | 列表、统计 |
| 已核对课程 | store.courses / store.checked | 统计 |
| 登录状态 | store.loginRequired | 登录 CTA |
| 部分更新 | store.partial | 橙色提示 |
| 最近更新 | store.updatedAt | Footer |
| 刷新中 | store.refreshing | 进度提示 |
| 官方操作 | WKWebView 复用浏览器 | Sheet |

## 5. 路由

- MoodleTabView 原生/旧版由 settings.nativeMoodleEnabled 控制；
- pendingMoodleURL 接收 My/快捷入口的深链；
- 通过官方 Sheet 复用 BrowserModel，保留登录态；
- 关闭 Sheet 后自动刷新摘要；
- 登录、课程内容、提交、测验和成绩均由官方页面处理。

## 6. 从既有构建中得到的约束

1. 没有可验证的 Moodle API/令牌，不要实现原生提交。
2. 课程/活动 ID 不能写死；只使用缓存返回的安全 assign/quiz URL。
3. 登录需要 Office 365 SAML 或邮箱密码；不能复用 Microsoft 门户会话。
4. 缓存只包含清理过的名称、课程、时间、状态和安全链接，不含成绩、正文或附件。
5. 任何部分更新/登录过期都要可见，不能用空结果假装没有作业。
6. 官方网页改版会破坏深链；入口集中在 MoodleDirectory，便于更新。
7. 平板不是放大手机：使用自适应网格、最大宽度、动态字号。
8. 失效、限流、权限和网络错误必须保留官方回退入口。

## 7. 验收清单

- [ ] 手机/平板均能打开原生 Moodle 首屏；
- [ ] 未登录时显示登录 CTA，登录后返回自动刷新；
- [ ] 近期事项数量与官方页一致（允许官方页延迟）；
- [ ] 每个工具入口打开正确官方 URL；
- [ ] 关闭官方 Sheet 后摘要刷新；
- [ ] 登录过期时显示登录提示，不显示伪造数据；
- [ ] Dynamic Type 最大字号不截断关键按钮；
- [ ] 深色模式下渐变、卡片、文字对比度正常；
- [ ] 旧版网页开关可用。


## 8. 2026-10 补充规则

- 课程列表来自 Moodle 的完整课程清单，不再只来自有近期作业的课程。
- 带显式学期标签的课程按年份纳入：当前年份及其后的 Winter / Spring / Summer 都显示（例如 Winter 2026、Spring 2027）；不再因为课程 enddate 过期而隐藏。
- 课程按学期分组并按 Winter → Spring → Summer、年份升序排序。
- 课程卡片打开 course/view.php?id=课程 ID，而不是 dashboard。
- 首页的临近日程、课程、Moodle 工具支持拖动排序和选择性隐藏；布局保存在本机，可恢复默认。


## 9. 当前课程 / 历史课程（alpha.13）

- 当前课程以 MoodleUpcomingStore.currentTerm() 为基准（当前为 Winter 2026），固定显示在首页第一个模块。
- 当前学期课程按课程名排序；没有显式学期标签但日期处于当前学期的课程也归入当前课程。
- 其他学期统一归入“历史课程”，按学期倒序分组。
- 顶部三个统计卡已移除。
- 课程卡直接打开 course/view.php?id=课程ID。
- 布局编辑器只能调整临近日程、历史课程、Moodle 工具的顺序和显隐；“当前课程”固定在最前。
