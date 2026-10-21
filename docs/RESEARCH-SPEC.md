# GTIIT iOS App · 研究与文案规格（RESEARCH-SPEC）

> 版本：v1.0 ｜ 编写日期：2026-10-21 ｜ 研究快照：2026-10-21（Asia/Shanghai） ｜ 适用范围：首版「网页套壳 + 底部标签栏」
> 读者：项目 Lead / Swift 实现者 / 后续写 README 与隐私说明的人
> 本文只写规格与中文文案，不含 Swift 源码。所有事实来自第 0 节列出的研究资料；无法确认的内容一律写「未验证」，不编造字段、接口或页面 URL。

**状态声明**

研究资料中的四站结论是 2026-10-21 的只读观察快照，不保证网站后续配置不变。本轮没有任何系统的「原生接口」被验证可用：学生门户、Moodle、Booked 房间预约、MIKEX 体育中心都只有网页访问证据。因此本文把「网页能打开」「App 内能浏览」「能原生读取」「能原生提交」当作四种不同状态，首版 App 只争取做到第二种，且需真机验证。

---

## 0. 证据分级与来源

### 0.1 证据等级

| 等级 | 含义 | 例子 |
|---|---|---|
| E1 | 本轮直接观察：登录状态下用 Safari 实访，或独立浏览器实际加载页面 | 门户 Dashboard、Moodle 课程页、Booked 新建预约表单、体育羽毛球会员登录关口 |
| E2 | 公开静态声明：公开前端代码、公开 JSON/配置、未登录页面 | 门户路由表、Moodle 移动公开配置、Booked 资源目录、体育 15 个场馆配置 |
| E3 | 官方文档 / 官方源码 | WebKit Profiles API、Microsoft 回调文档、Moodle launch.php、Apple 后台执行说明 |
| E4 | 研究推断 / 产品建议 | 信息架构、文案建议、能力边界取舍 |
| E5 | 当前实现快照：只读 Lead 并行编写的 Swift 源码（2026-10-21），仅用于文案与界面结构对齐，不作为研究证据 | AppTab、WelcomeView、SiteInfoView、MyTabView、SiteID 等 |

一条结论可能同时有多级证据。本文表格中的「证据」列给出文件名与等级，便于回溯。

### 0.2 来源文件

| 文件 | 本文用到的内容 | 日期 |
|---|---|---|
| 任务总结.md | 四站原始入口、已完成/未完成边界、必须保留的判断 | 2026-10-21 |
| START_HERE.md、handoff-state.json | 交接范围、未开始的实现、凭据/会话不随包转移 | 2026-10-21 |
| research/GTIIT-iOS客户端调研与架构方案.md | 四站实际情况、五层架构、功能层级、登录安排、证据方法 | 2026-10-21 |
| research/moodle-findings.md | Moodle 登录方式、公开配置、认证/通知边界 | 2026-10-21 |
| research/sports-findings.md | 体育 15 场馆、注册字段、两张营业时间表冲突、能力配置 | 2026-10-21 |
| research/coverage-audit.json | 覆盖状态、证据清单、明确未完成项 | 2026-10-21 |
| research/portal-static-inventory.json | 门户公开前端路由、GET/写操作字面量 | 2026-10-21 |
| research/portal-evaluation-public-config.json | 教学评价题目配置：Lecturer 10、Tutor 10、Lab 8 | 2026-10-21 |
| research/portal-booked-inventory.json | 门户首页、房屋预约未登录跳转与登录表单字段 | 2026-10-21 |
| research/booked-resource-inventory.json | 10 个排程、91 个资源、resource 78 元数据、API 关闭回执 | 2026-10-21 |
| research/moodle-public-config-evidence.json | Moodle 移动公开配置、Office 365 SAML2 入口 | 2026-10-21 |
| research/rendered-public-pages.json | 四站独立浏览器最终 URL 与公开页面文本（门户跳转 Tenant ID） | 2026-10-21 |
| research/sports-functional-inventory.json | 15 场馆配置、登录边界、成功提示、取消/签到线索 | 2026-10-21 |
| research/sports-index.json、sports-image-index.json | 16 个体育直接目标、营业时间图来源 | 2026-10-21 |
| research/portal-mobile.png、moodle-mobile.png、sports-mobile.png、sports-info-*.png | 430px 浏览器截图（非 iPhone 真机）、两张营业时间表 | 2026-10-21 |
| 续研/可行性分析-20261021.md | Safari 登录后逐页盘点、iOS 17 数据容器建议、首版边界、练习房规定 | 2026-10-21 |
| 续研/capability-matrix.json | 四站「已验证 / 未验证 / 首版路线」矩阵 | 2026-10-21 |
| 续研/后续验证清单.md | 后续验证项、数据模型验收、未来最小 iPhone 验证 | 2026-10-21 |
| 续研/Moodle-只读接口验证方案.md | 只读候选函数、read/write 分类、令牌边界 | 2026-10-21 |

截图说明：三张 `*-mobile.png` 为 430px 宽度浏览器截图，不是 iPhone 真机测试（架构方案 §7），只能作视觉参考，不能当作 iOS 兼容性证据。

### 0.3 完成度三档（全文统一口径）

1. **网页可打开**：WKWebView 能加载官方页面（本轮在 macOS 浏览器验证，iOS 真机未验证）。
2. **App 内可浏览**：网页在 App 容器中可登录、可跳转、可刷新、会话可保留（未验证）。
3. **原生读取 / 原生提交**：不经过官方网页，直接调用接口或代填表单（本轮全部未验证，首版不做）。

---

## A. 四站入口与深链 URL 表

### A.0 通用前提

- 表中 URL 均为 2026-10-21 快照；是否长期有效未验证。
- 「可深链」只表示该 URL 在研究资料中有证据，**不表示 App 内直接打开一定成功**；未登录时是否回落登录页、登录后是否跳回目标页，全部未验证。
- 深链只作为 WKWebView 的初始请求地址使用，App 不解析页面内容来确认是否到达目标页。
- 门户子路由来自公开前端静态声明（E2）并叠加登录后 Safari 实访（E1）；它们不是可用 API。
- 所有链接应集中在一个配置文件中维护（建议名：SiteCatalog），便于网站改版时替换；链接失效处理属未验证项（见 G）。

### A.1 站点总览

| 站点 | 用途 | 首页 URL | 研究时的登录边界 |
|---|---|---|---|
| 学生门户 | 个人学业事务：成绩、选课、考勤、申请、培养计划、评价、成绩单入口 | https://students.gtiit.edu.cn/ | 未登录跳转学校 Microsoft 登录页（E1） |
| Moodle | 课程学习：课程资料、作业(assign)、测验(quiz)、论坛、日历、服务空间 | https://moodle.gtiit.edu.cn/moodle/my/ | 未登录跳转 /moodle/login/index.php（E1） |
| 房间预约（练习房） | 乐器练习室、讨论室、Student Hub 等空间预约（Booked 2.8.5） | 登录页 https://roombooking.gtiit.edu.cn/Web/index.php ；登录后首页 https://roombooking.gtiit.edu.cn/Web/dashboard.php ；原始目标 https://roombooking.gtiit.edu.cn/Web/reservation.php?rid=78 | 未登录跳转 /Web/index.php?redirect=...（E1） |
| 体育中心 | 15 个场馆预约、会员注册、票券/记录入口（MIKEX） | https://gtiit.mike-x.com/0x2Rg | 首页公开；场馆页要求会员登录（E1） |

证据：任务总结.md「原始目标与入口」；rendered-public-pages.json；portal-booked-inventory.json；sports-findings.md（2026-10-21）。

### A.2 学生门户（students.gtiit.edu.cn）

| 页面 | URL | 证据 | 备注 / 边界 |
|---|---|---|---|
| Dashboard | https://students.gtiit.edu.cn/ | E1 可行性分析-20261021.md §2A；E2 portal-static-inventory.json | 学期选择、课程代码/名称/学分、考试类别/时间/时长/地点 |
| 成绩 Grades | https://students.gtiit.edu.cn/grades | E1 §2A；E2 | 有 Code of Conduct 关口；答卷下载按钮存在但未下载；不保存成绩数值 |
| 选课 Enrollments | https://students.gtiit.edu.cn/enrollments | E1 §2A；E2 | 首帧先显示 Courses: 0 / Credits: 0 / CLOSED，异步后才出现真实数据 |
| 考勤 Attendance | https://students.gtiit.edu.cn/attendance | E1 §2A；E2 | Summary / Records / Leave Requests 三个页签；含刷卡时间 |
| 申请 Applications | https://students.gtiit.edu.cn/apps | E1 §2A；E2 | 另有 /apps/leave、/apps/addcredits 两个子页面（下表） |
| 请假申请 Leave Request | https://students.gtiit.edu.cn/apps/leave | E1 §2A；E2 | 含日期、课程/班组/时段多选、原因、证明上传、Submit；未填写未提交 |
| 额外学分申请 | https://students.gtiit.edu.cn/apps/addcredits | E1 §2A；E2 | 含课程搜索、说明、学分汇总、提交；未提交 |
| 教学评价 Evaluations | https://students.gtiit.edu.cn/evaluations | E1 §2A；E2 | 调研快照页面显示 2026-12-21 09:00 开放；问卷本身未看到 |
| 培养计划 Checklist | https://students.gtiit.edu.cn/checklist | E1 §2A；E2 | PCC/PEC/GE/MOE、自报 Passed/In Progress、替代课程、Review & Submit |
| 旧版培养计划 | /checklist-v1 | E2 portal-static-inventory.json | 旧路由，不应作为用户可见入口（架构方案 §1.1） |
| 使用规范 | /itpolicy | E2 portal-static-inventory.json | 本轮未单独打开运行时页面（未验证） |
| 学业知情授权 | /authorization | E2 portal-static-inventory.json；架构方案 §8 | 有明确同意/不同意选项，同意需至少一位家人姓名与关系；不能自动勾选 |
| 成绩单 | 无独立路由证据；入口在 Grades / Applications 页面内的按钮 | E1 §2A；架构方案 §1.1 | GT 与 Technion 两类；下载未执行（未验证） |
| 消息 / 个人资料 | 由页面内组件与接口字面量体现（notifications、profile） | E2 portal-static-inventory.json | 无独立深链证据；不承诺 App 内消息聚合 |

门户后端线索（仅作研究证据，**不是**开发者可用授权）：前端为 MSAL SPA，后端为 校内教务接口地址（已隐去），带 Bearer 认证（架构方案 §1.1，E2）。独立 App 直接调用需要学校应用注册与 Scope，当前未具备。

### A.3 Moodle（moodle.gtiit.edu.cn/moodle）

| 页面 | URL | 证据 | 备注 / 边界 |
|---|---|---|---|
| 我的 / Dashboard | https://moodle.gtiit.edu.cn/moodle/my/ | E1 可行性分析 §2.1；E2 moodle-public-config-evidence.json | 未登录跳 login/index.php；含课程概览、Timeline、日历 |
| 登录页 | https://moodle.gtiit.edu.cn/moodle/login/index.php | E1 rendered-public-pages.json | Office 365（SAML2）或邮箱密码 |
| 课程首页 | https://moodle.gtiit.edu.cn/moodle/course/view.php?id={课程ID} | E1 §2.2、§2.6 | 观察样本：3054、3052、3168、3056、3034、3035；服务空间 81、149 |
| 作业（assign） | https://moodle.gtiit.edu.cn/moodle/mod/assign/view.php?id={活动ID} | E1 §2.2 | 样本 162976；含附件、提交/批改状态、截止、Add submission |
| 测验（quiz） | https://moodle.gtiit.edu.cn/moodle/mod/quiz/view.php?id={活动ID} | E1 §2.2 | 样本 159592；允许 4 次尝试、独立开放/关闭时间、Last attempt 计分 |
| 分组选择（choicegroup） | https://moodle.gtiit.edu.cn/moodle/mod/choicegroup/view.php?id={活动ID} | E1 §2.6 | 样本 161368；取消选择链接带删除动作参数，不能当只读链接预取 |
| 课程考勤（attendance） | https://moodle.gtiit.edu.cn/moodle/mod/attendance/view.php?id={活动ID} | E1 §2.6 | 样本 160987；存在 `?` 状态，不能自动归为缺勤 |
| 学校自定义课表 | https://moodle.gtiit.edu.cn/moodle/local/calendar/index.php | E1 §2.4 | 标题 GTIIT calendar，学期 2026-27 WINTER；初始 Courses: 0 / Credits: 0，不能当作未选课 |
| 日历 Upcoming | https://moodle.gtiit.edu.cn/moodle/calendar/view.php?view=upcoming | E1 §2.5 | 同时列出 Assignment 截止与 Quiz 开启/关闭事件 |
| 日历导出 | https://moodle.gtiit.edu.cn/moodle/calendar/export.php | E1 §2.5 | 筛选表单可读；未生成订阅 URL、未下载（未验证内容与认证） |

注意：`?id=` 后的数字是 Moodle 内部课程/活动 ID，不能跨站或跨课程复用；表中样本 ID 只用于说明证据存在，不应硬编码为 App 功能入口。

### A.4 房间 / 练习房预约（Booked Scheduler v2.8.5）

| 页面 | URL | 证据 | 备注 / 边界 |
|---|---|---|---|
| 登录页 | https://roombooking.gtiit.edu.cn/Web/index.php | E1 portal-booked-inventory.json | 标题 GTIIT Room Booking Service - Log In；页脚 Booked v2.8.5 |
| Dashboard | https://roombooking.gtiit.edu.cn/Web/dashboard.php | E1 可行性分析 §2B | Announcements、Upcoming Reservations、Resource Availability |
| 原始目标资源 78 | https://roombooking.gtiit.edu.cn/Web/reservation.php?rid=78 | E1 §2B；E2 booked-resource-inventory.json | 未登录跳 index.php?redirect=...；资源为 D4-103-9（配电子琴练习室） |
| 我的日历 | https://roombooking.gtiit.edu.cn/Web/my-calendar.php | E1 §2B | 月/周/日、All Reservations、Resource Groups、公开分享入口（未启用） |
| 预约查询 | https://roombooking.gtiit.edu.cn/Web/search-reservations.php | E1 §2B | 默认本人；结果列 User/Resource/Title/Description/Begin/End/Duration/Reference Number/Created/Last Modified |
| 查找可用时间 | https://roombooking.gtiit.edu.cn/Web/search-availability.php | E1 §2B | 资源、时长、指定时间、日期范围、重复、容量、资源类型 |
| 公开排程目录 | https://roombooking.gtiit.edu.cn/Web/view-calendar.php | E2 booked-resource-inventory.json | 10 个排程、91 个资源选项；公开排程可能显示他人姓名（rendered-public-pages.json 已省略该页文本） |
| 标准 API | https://roombooking.gtiit.edu.cn/Web/Services/ | E1 §2B；E2 | 返回 Booked API has been configured as disabled；不能作为接口路线 |

resource 78 的公开元数据（E2，booked-resource-inventory.json）：资源 ID 78、名称 D4-103-9（Equipped a Electronic Piano）、所属组 Instrument Practice Room、scheduleId 6、requiresApproval=0、isCheckInEnabled=0、maxConcurrentReservations=1。这些只是公开目录字段，**不代表本人有预约权限**，也不代表当前时段可订。

排程与资源规模：10 个排程（Student Hub、Hotel、Meeting Room、Teaching Room、Test、Instrument Practice Rooms、Students Group Discussions、SC 讨论室、SC 冬季讨论室、Student Activity Rooms），91 个资源选项（booked-resource-inventory.json）。同名地点可能出现在不同排程，模型需保留资源 ID，不能只按名称去重（架构方案 §1.3）。

### A.5 体育中心（gtiit.mike-x.com）

首页：https://gtiit.mike-x.com/0x2Rg （E1，sports-mobile.png；标题 GTIIT Sports Center 广东以色列理工学院体育中心）
注册页：https://gtiit.mike-x.com/VK31S （E2 sports-index.json；公开姓名/邮箱/手机/身份字段，按身份条件上传证件）

15 个场馆入口（E2，sports-index.json + sports-functional-inventory.json；均为「会员登录后才有表单」）：

| 场馆 | URL | 取消配置线索 | 签到配置线索 | 每日限次线索 |
|---|---|---|---|---|
| 北校区乒乓球室 | https://gtiit.mike-x.com/0TZPp | 开 | 开 | 有 |
| 室外网球场 | https://gtiit.mike-x.com/ACOAm | 开 | 开 | 有 |
| 南校区乒乓球台 | https://gtiit.mike-x.com/J8PeH | 开 | 开 | 有 |
| 小足球场 | https://gtiit.mike-x.com/KeoJR | 开 | 开 | 有 |
| 室内篮球半场 | https://gtiit.mike-x.com/N9MTj | 开 | 开 | 有 |
| 室内排球场 | https://gtiit.mike-x.com/NqBp3 | **关** | 开 | 有 |
| 攀岩墙 | https://gtiit.mike-x.com/QuPzR | 开 | 开 | 有 |
| 游泳馆 | https://gtiit.mike-x.com/SKANr | 开 | 开 | 有 |
| 南校区瑜伽房 | https://gtiit.mike-x.com/ZbkLQ | **关** | 开 | 有 |
| 北校区瑜伽室 | https://gtiit.mike-x.com/bMWdH | 开 | 开 | 有 |
| 羽毛球场 | https://gtiit.mike-x.com/kcr2S | 开 | **关** | 有 |
| 普拉提晚场 | https://gtiit.mike-x.com/o2DRD | 开 | **关** | 无 |
| 匹克球场 | https://gtiit.mike-x.com/ogyYI | 开 | 开 | 有 |
| 大足球场 | https://gtiit.mike-x.com/ypF4B | 开 | 开 | 有 |
| D3 栋乒乓球台 | https://gtiit.mike-x.com/yspKN | 开 | 开 | 有 |

「取消/签到/限次」是公开前端配置线索（sports-findings.md；sports-functional-inventory.json），**不是已登录实测**，不能当成 App 按钮的可用依据；场馆层面的能力必须逐馆确认。

### A.6 深链使用约束

1. 深链 = WebView 初始 URL，不做页面解析；到达与否由网页自己决定。
2. 未登录打开任意深链可能先跳 SSO；登录后是否回到原目标页，未验证。
3. 门户的 `/grades`、`/enrollments` 等是单页应用前端路由（E2），直接打开时的默认筛选可能与从首页进入不同；调研已观察到 Dashboard 与 Grades 的默认学期不一致（可行性分析 §2A），不能把某页默认筛选当成全局当前学期。
4. Moodle 的 `course/view.php?id=` / `mod/*/view.php?id=` 的 ID 是服务器内部 ID；App 不硬编码、不猜测、不遍历。
5. 练习房 `reservation.php?rid=78` 只对应一个资源；不要把 rid 当房间号，也不要遍历 91 个资源（公开排程可能含他人姓名）。
6. 体育每个场馆是独立短码表单；`kcr2S` 只是羽毛球场，不能当体育总入口。
7. 所有 URL 必须可集中替换；网站改版导致的失效未验证（见 G）。

---

## B. 会话与登录前提

### B.1 每站登录矩阵

| 站点 | 登录方式 | SSO / 域名 | 账号前提 | 证据 | 首版 App 处理 |
|---|---|---|---|---|---|
| 学生门户 | 学校 Microsoft Entra 账号登录（MSAL SPA） | login.microsoftonline.com，Tenant `(tenant id redacted)` | 广以系统账号，格式 `username@gtiit.edu.cn`；密码重置入口：门户登录页提示 https://sites.gtiit.edu.cn/pwm，Moodle 报告另记 pwm.gtiit.edu.cn（两处来源，是否同一服务未验证） | E1 rendered-public-pages.json、portal-mobile.png；E2 架构方案 §1.1 | WKWebView 内官方网页登录；不代填、不接管密码 |
| Moodle | ① Login via Office 365（SAML2 插件）② 邮箱 + 密码手动登录 | /moodle/auth/saml2/login.php?wants&idp=(idp id redacted)；身份提供方名称 Login via Office 365 | GTIIT 邮箱与密码；找回入口指向 pwm | E2 moodle-public-config-evidence.json；E1 moodle-mobile.png | WKWebView 内官方网页登录；不生成移动令牌、不做 ASWebAuthenticationSession 回调 |
| 房间预约 | Booked 本站账号：Username or Email + Password，可勾选 Remember Me | 无 SSO 证据；页面为独立 Booked 登录 | 本站账号（与 Microsoft 账号关系未验证） | E1 portal-booked-inventory.json；§2B | WKWebView 内官方网页登录 |
| 体育中心 | MIKEX 独立会员：邮箱认证（`-830 → MemberLogin`，`email_login_type=4 → UNI_EMAIL_AUTH_ALLOW_PASSWORD`） | gtiit.mike-x.com；与学校 SSO 关系未验证 | 需会员账号；没有账号需在 VK31S 注册，可能需资格/资料审核（未验证） | E2 sports-findings.md；sports-functional-inventory.json | WKWebView 内官方网页登录或打开注册页 |

补充事实：Moodle 公开移动配置为 `enablewebservices=1`、`enablemobilewebservice=1`、`typeoflogin=2`（官方源码定义为浏览器登录）、`guestlogin=0`，launchurl 为 /moodle/admin/tool/mobile/launch.php（moodle-public-config-evidence.json，E2）。这只能说明「服务开启 + 浏览器登录」，**不证明**学生账号能生成令牌、相关函数可调用、自有 URL Scheme 回调可用。

### B.2 会话隔离与「一次登录」的边界

- **不能宣传「一次登录四站全通」**：四站账号体系、Cookie 与令牌互相独立；门户走 Microsoft，Moodle 走 SAML2/本站账号，Booked 是本站账号，体育是 MIKEX 会员（任务总结.md；架构方案 §3.1、§4.1）。
- **Safari 登录 ≠ App 会话**：本轮 Safari 登录只用于研究，不能直接给未来 App 提供会话；系统浏览器/ASWebAuthenticationSession 完成登录，也不代表 WKWebView 得到同一会话（可行性分析 §3.1；架构方案 §4.1）。
- **不读取密码框、不代填、不复制官方 App 回调 Scheme、不把账号交给自建服务器**（架构方案 §4.1；任务总结.md「接手时需要保留的判断」）。
- **门户使用规范风险**：登录后 Grades 首次出现 Code of Conduct，明确限制未经授权的脚本、其他软件及直接访问应用资源，并要求本人账号、本人设备上的浏览器使用；调研代理未勾选同意（可行性分析 §2A）。**学校是否允许第三方网页容器嵌入，未确认**——这是首版最大合规风险，必须列进「已知限制」。
- 每站会话独立、可单独断开与清理；一个站点退出登录不影响其它站（架构方案 §3.1、§4.1）。

### B.3 iOS 17 多持久化 WKWebsiteDataStore：依据与限制

**依据**：WebKit 从 iOS 17 起提供多个「带标识的持久化 `WKWebsiteDataStore`」（Profiles API），可用于让不同站点的 Cookie、缓存与登录态分别落盘、互不覆盖，并可单独清理（可行性分析 §3.2，E3）。官方说明：[WebKit: Building profiles with new WebKit API](https://webkit.org/blog/14423/building-profiles-with-new-webkit-api/)。

**建议实现（E4）**：

| 站点 | 建议 identifier | 说明 |
|---|---|---|
| 门户 | `gtiit.portal` | 含 Microsoft 登录 Cookie |
| Moodle | `gtiit.moodle` | 含 MoodleSession 与 SAML 状态 |
| 练习房 | `gtiit.rooms` | Booked 本站会话 |
| 体育 | `gtiit.sports` | MIKEX 会员会话 |

**限制（必须写进 README / 已知限制）**：

1. 最低系统版本尚未确定；若低于 iOS 17，只有默认持久容器，多个非持久容器无法在重启后保留各站会话（可行性分析 §3.2）。是否将最低版本定为 iOS 17 需 Lead 决策，本文不擅自决定。
2. 隔离的副作用：同一个 Microsoft 账号在门户与 Moodle 的 Office 365 登录可能需要在两个容器里各登录一次；实际体验未验证（可行性分析 §3.2）。
3. 按本产品「不读取页面内容」的承诺，App 无法判断某站点是否已登录；不能显示「已连接/已登录」徽标，只能提示「登录状态以网页为准」。
4. WKWebView 与 Safari / ASWebAuthenticationSession 的存储不共享；具体站点行为未在 iOS 真机验证（B.2）。
5. Microsoft 登录是否允许在嵌入式 WKWebView 内完成、还是必须交给系统浏览器/ASWebAuthenticationSession，未验证；若必须外跳，App 内网页将拿不到会话（架构方案 §4.1）。
6. 清理某一站点容器只影响该站；「清除网页数据」必须按站提供，并明确不影响其它站。
7. 会话过期时长、切后台长时间后是否要重登，未验证（见 G）。

**低于 iOS 17 的降级选项（均未验证，需 Lead 决策）**：共享单一持久容器（会话可能互相覆盖，需在文案中说明）或每次进入重新登录（体验未验证）。本文不把任一方案写成已成立。

---

## C. 能力边界表

### C.1 首版能力矩阵（原生 / 网页 / 不承诺）

| 模块 | 首版原生做（导航外壳层） | 只做官方网页容器 | 明确不承诺 |
|---|---|---|---|
| 学生门户 | Tab、入口、返回/前进/刷新、Safari 外开、站点说明卡、深链快捷入口 | 登录、Dashboard、成绩、选课、考勤、申请、评价、培养计划、成绩单/答卷下载 | 原生读取成绩/课表/考勤；原生选课/退课/申请/评价/签署/提交；自动同步；成绩单批量下载与离线管理 |
| Moodle | Tab、入口、返回/刷新、说明卡、my/日历/导出深链 | 登录、课程、资料、assign、quiz、forum、folder、url、choicegroup、attendance、服务空间、日历导出 | 原生课程/待办列表；作业/测验作答或提交；文件批量下载与离线；消息聚合；通知推送 |
| 房间预约 | 预约 Tab 内的「练习房 / 讨论室」分段、入口、说明卡 | 登录、Dashboard、排程、我的日历、预约查询、查找可用时间、reservation.php?rid=78 表单、创建/取消（用户自行操作） | 原生预约/取消/改期；实时余位；个人预约自动同步；把所有 91 个资源都做成可预约目录；公开排程中他人姓名的采集/缓存 |
| 体育中心 | 预约 Tab 内的「体育场馆」分段、场馆说明卡、15 个入场链接 | 会员登录、注册、各场馆表单、票券、记录、取消/签到（以场馆实际为准） | 原生预约/票券/签到；余位与价格；代注册、上传证件；判定营业中/闭馆；统一「可取消」按钮 |
| 我的 | 原生设置页：站点与会话（缓存状态、按站/全部清除）、常用快捷入口、可选生物识别锁（Face ID/Touch ID，仅遮挡界面）、隐私说明、免责声明复看、已知限制、版本与官方链接 | —（不加载网页） | 检测登录状态；账号管理；令牌/Keychain 管理；消息中心 |
| 网页下载与上传 | 用 WKDownload 接管网页下载，落临时目录后交系统分享；网页上传用系统文稿选择器 | 文件内容、下载权限与失败处理由网页决定 | 离线资料库、批量下载管理、断点续传、自动上传、把文件发到自建服务器 |
| 全局 | 首次启动免责声明、错误态/空态、外部打开、字体与无障碍基础 | — | 模拟数据「假装打通」；自动同步/固定轮询/推送；后台定时；跨站搜索；数据统计 |

### C.2 硬红线（写进验收，不满足即不通过）

1. **不用模拟数据假装打通**：没有接口的模块不能展示示例成绩、示例课程、示例预约、示例余位，也不能把网页入口包装成「已同步」。（任务总结.md）
2. **不承诺自动同步**：没有数据接口、没有后台任务保障，就不能说「自动更新」「实时同步」「每分钟检查」；iOS 后台任务由系统调度，不能承诺固定间隔（架构方案 §4.2；[Apple 后台执行说明](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)）。
3. **不代填表单**：任何账号、密码、验证码、申请说明、评价选项、预约字段，都不由 App 预填或代填。
4. **不提交业务**：选课、退课、请假、额外学分、教学评价、培养计划、Code of Conduct、学业知情授权、房间预约、体育预约/取消/签到，全部由用户在官方网页内自行确认提交。
5. **不读取页面数据**：不注入脚本抓取成绩、作业、预约记录、表单字段；不把网页内容写入开发者服务器。
6. **不宣传「一次登录四站全通」**（B.2）。
7. **不展示、不缓存、不采集他人信息**：Booked 公开排程可能含预约人姓名（rendered-public-pages.json 对该页文本做了省略），App 不截图缓存、不做分析。

### C.3 与研究建议的差异

研究方案（架构方案 §5 阶段 1）建议首版包含「原生场地目录、运动/校区筛选、收藏、手动日程与本地提醒」。当前项目聚焦「网页套壳 + 底部标签栏、原生只做导航外壳」，因此这些原生能力**不在本版范围**，本文不承诺，也不把它们写成已实现；若后续加入，应另立任务并重新验收，避免把网页入口与本地目录混为一谈。

---

## D. 信息架构

### D.1 四个底部 Tab 映射

| Tab | 覆盖系统 | 首屏 | 内容来源 |
|---|---|---|---|
| 门户（默认选中） | 学生门户 students.gtiit.edu.cn | 官方网页首页（未登录则由网页自行跳转 SSO） | WKWebView + 独立数据容器 |
| 学习 | Moodle moodle.gtiit.edu.cn/moodle | https://moodle.gtiit.edu.cn/moodle/my/ | WKWebView + 独立数据容器 |
| 预约 | 练习房（Booked）+ 体育（MIKEX），顶部二段切换 | 练习房：/Web/dashboard.php（未登录由网页跳登录页）；体育：0x2Rg 首页 | 两个独立 WKWebView + 两个独立数据容器 |
| 我的 | 原生设置与说明 | 原生列表 | 无网页 |

### D.2 映射理由

1. **按学生的任务对象分组，不按网站各占一个 Tab**：四站背后是三件事——个人学业事务（门户）、课程学习（Moodle）、场地预约（两个预约平台）；「我的」是原生设置。四个网站若各占一个 Tab，底部会变成 5 项且把「账号/平台」差异暴露给用户，反而更难用。
2. **门户与学习必须分开**：账号体系不同（Microsoft Entra vs Moodle SAML2/邮箱）、会话必须隔离、页面与信息密度差异大；合并会掩盖「为什么这里又要登录一次」。
3. **两个预约平台合并进「预约」但用二级切换**：用户任务是「找场地」，但练习房与体育的账号、规则、可用能力完全不同。用 UISegmentedControl 分出「练习房 / 体育」，既保持一级导航简洁，又能分别显示各自的说明卡与前提，不误导为同一系统。
4. **「我的」不承载业务**：只放站点说明、隐私、免责声明、清理与关于，避免与「门户/学习」的账号入口混淆。
5. **默认选中「门户」**：首版核心是学业事务入口；不做「今日」聚合是因为没有数据接口，聚合页只能是网页快捷入口，容易被误读为「App 已掌握个人数据」。

### D.3 每个 Tab 的导航层级

```text
根容器（TabView / UITabBarController）
├─ 门户 (导航容器 + WKWebView)
│  ├─ L1 门户（工具栏：返回 / 前进 / 刷新 / Safari 打开 / 站点说明）
│  ├─ L2 站点说明卡（sheet：用途 / 首版边界 / 已知前提）
│  ├─ L2 深链快捷入口（建议，见 A.2；点击后在同一个 WebView 内加载）
│  └─ L3 网页内部跳转（由网页自身管理历史，不压入原生导航栈）
├─ 学习 (导航容器 + WKWebView)
│  ├─ L1 学习（工具栏同上）
│  ├─ L2 站点说明卡
│  ├─ L2 深链：我的 (my) / 日历 (calendar/view.php?view=upcoming) / 导出 (calendar/export.php)
│  └─ L3 网页内部跳转
├─ 预约 (导航容器 + 两个独立 WKWebView)
│  ├─ L1 预约（顶部 UISegmentedControl：练习房 / 体育）
│  ├─ L2 练习房：网页 dashboard.php；说明卡；深链快捷：我的日历 / 查找可用时间 / D4-103-9 表单
│  ├─ L2 体育：网页 0x2Rg；说明卡；深链快捷：羽毛球场 / 注册页
│  └─ L3 各网页内部跳转（两个 WebView 的历史互不干扰）
└─ 我的 (原生，无 WebView)
   ├─ L1 我的（Section：站点与数据 / 隐私与说明 / 关于）
   ├─ L2 站点说明卡（门户 / 学习 / 练习房 / 体育）
   ├─ L2 隐私说明
   ├─ L2 首次启动免责声明（复看）
   ├─ L2 已知限制（引用本文 G 节）
   └─ L2 清除网页数据（按站点确认）
```

层级规则：

- 网页内部页面跳转由 WKWebView 历史管理；原生导航栈只在「说明卡 / 隐私 / 已知限制」等原生页面之间 push。
- 预约 Tab 的两个 WebView 各自保留返回栈与独立数据容器，切换分段不共享历史、不共享 Cookie。
- 从「我的」进入站点说明卡时，不触发该站网页加载。

### D.4 与研究「今日」Tab 的对照（供 Lead 决策）

研究建议的功能层级是「今日 / 学习 / 预约 / 我的」，其中「今日」是跨站聚合视图（架构方案 §2）。当前任务描述里也曾出现「今日」，但首版没有数据接口、也不读页面内容，无法产出真实聚合。本文按当前实现口径使用「门户」，理由：

- 首版 Tab 1 的实质就是门户网页入口，命名「门户」与屏幕内容一致，不制造「App 已经汇总了你的学业」的暗示。
- 若后续通过获准接口实现了只读聚合，可把 Tab 1 更名为「今日」，在聚合页内保留「门户」入口，A 节 URL 表与深链不变。

两种命名都只是标签文字，不影响 URL 与容器划分；但**应用内不能同时出现两套说法**（例如 Tab 叫「门户」而说明卡写「今日」）。需 Lead 在实现前定稿。

### D.5 WebView 行为规范

1. 每个 Tab 一个 WKWebView；预约 Tab 内两个独立实例，不共用一个实例切 URL（避免历史与会话串台）。
2. 每站使用独立持久化数据容器（见 B.3）；App 启动不预热、不预加载任何站点。
3. 站内导航留在 WebView；跨域或用户点「Safari 打开」时交给系统浏览器。
4. 工具栏提供返回、前进、刷新、Safari 打开、站点说明；无网络/失败时显示错误态（E.4），不自动循环重试。
5. 网页下载由 WKDownload 接管，落临时目录后交系统分享；上传由系统文稿选择器完成。首版不做离线资料库，文件预览、清理与失败处理仍未在真机验证（见 G）。
6. 不注入读取凭据/页面内容的脚本；若未来确有 JS 桥，必须限定到明确可信的页面与消息类型（架构方案 §4.1）。
7. 网页跳转到外部 App（如 Microsoft Authenticator、邮件）时，行为未验证；不得假设能自动回到原页面。

### D.6 首次启动流程

1. 启动 → 首次启动免责声明全屏页（E.1）。
2. 用户必须点「我已了解并继续」（不默认勾选、不自动跳过）；旁边提供「查看隐私说明」。
3. 进入主界面，默认选中「门户」。未点继续前不加载任何网页。
4. 之后可在「我的 → 免责声明」随时复看；卸载重装后重新出现。

---

## E. 可直接落进 App 的中文文案

### E.1 首次启动免责声明

**标题**：使用前请阅读

**正文（155 字）**：

> 本应用由学生个人开发，非广东以色列理工学院官方应用，与学校无隶属关系。它只是四个官方网页的浏览入口，不修改任何学校功能。登录与网页数据仅保存在本机，开发者不采集、不上传。选课、申请、评价、预约等业务请在官方网页内自行确认并提交，本应用不代填、不代提交。使用需能访问校园网络及相关校内域名，网络受限时可能打不开。

**按钮**：「我已了解并继续」（主）｜「查看隐私说明」（次）

**要求**：

- 必须由用户主动点击才继续；不默认勾选、不自动跳过（与门户「知情授权/规范不能自动勾选」同一原则，架构方案 §8、可行性分析 §2A）。
- 首次启动展示一次；「我的」内可复看。
- 字号支持动态字体，长文案可滚动，不截断。
- 当前实现（WelcomeView，E5）由 5 个要点卡 + 「开始使用」按钮 + 「继续使用即表示你已了解」页脚组成，没有上面这段完整声明。建议把 155 字全文放进底部强调框，主按钮改为「我已了解并开始使用」，并删除「继续使用即表示」式默示同意，改为用户显式确认。

### E.2 隐私说明

**标题**：隐私说明

**正文（分条）**：

1. 本应用不要求你注册新账号，也不保存账号或密码；登录在官方网页内完成，凭据不经过开发者。
2. 网页 Cookie、缓存与本地存储由 iOS WebKit 保存在本机，每个站点使用独立容器；可在「我的 → 清除网页数据」按站点删除。
3. 不接入第三方统计、埋点、广告或崩溃上报 SDK；不收集设备标识、位置、通讯录。
4. 不注入脚本读取或抓取页面内容（成绩、作业、预约记录、表单字段等），也不把这些内容上传到开发者服务器。
5. 没有自建业务服务器；账号、会话、页面内容均不上传。研究资料中的官方链接仅用于导航。
6. 网页需要选择或上传文件时，使用 iOS 系统文稿选择器；如网页要求拍照，权限由 iOS 询问，App 不主动申请相机或相册。拒绝不影响浏览。
7. 本机网页数据可在「我的」中随时清除；卸载 App 会删除本机数据（系统备份行为由 iOS 决定，未验证）。
8. 可选的面容 ID / 触控 ID 锁定只在本机由 iOS 验证，App 不接触、不保存生物识别数据；锁定只遮挡界面，不改变学校的登录状态。
9. 本说明是学生项目的自述，正式上架前会按 App Store 要求补充完善；当前不构成法律承诺。

**按钮**：「我知道了」

### E.3 站点说明卡

每张卡结构：用途 / 首版边界 / 已知前提 / 按钮。入口在对应 Tab 的「站点说明」，也可从「我的 → 站点与数据」进入。

当前实现（SiteInfoView，E5）只有「首版边界」三条、入口地址与「清除本站网页数据」，没有「用途」与「已知前提」。建议至少补齐「已知前提」（登录方式、网络前提、规则来源），否则用户容易把网页能力当成 App 能力。

#### 卡 1：学生门户

**用途**

- 查看本学期课程、考试安排与学业概况。
- 查看成绩与成绩单、答卷下载入口。
- 选课与退课、查看周课表。
- 考勤、请假、额外学分申请、教学评价、培养计划。

**首版边界**

- 本应用只提供官方网页容器与入口，不解析页面、不做原生表单。
- 不代填、不代提交，也不替你勾选使用规范或学业知情授权。
- 不提供成绩/课表的原生同步，也不做消息提醒。

**已知前提**

- 需要学校 Microsoft 账号（`username@gtiit.edu.cn`），登录由学校页面完成。
- 首次使用可能遇到 Code of Conduct 与学业知情授权页面，需你本人阅读并确认。
- 各页面默认学期可能不同，以网页显示为准；学校是否允许第三方客户端访问尚未确认。

**按钮**：「打开官方网页」「了解已知限制」

#### 卡 2：学习（Moodle）

**用途**

- 查看课程资料、文件夹、视频与外链。
- 查看作业（assign）与测验（quiz）的开放、截止、提交与批改状态。
- 查看课程日历、公告、论坛与学校服务空间（本科教学、学生事务）。

**首版边界**

- 只做官方网页容器；不在 App 内作答、上传、提交作业或测验。
- 不聚合课程待办、不读取成绩、不做消息与推送。
- 日历导出只是网页表单入口，未验证能否生成可用的订阅链接。

**已知前提**

- 支持 Office 365 登录与邮箱密码登录，登录由 Moodle 页面完成。
- 学校已开启 Moodle 移动服务，但当前为「浏览器登录」模式；App 内不申请移动令牌。
- 学校自定义课表（GTIIT calendar）是插件页面，其数据接口未验证。

**按钮**：「打开官方网页」「了解已知限制」

#### 卡 3：练习房预约（房间预约）

**用途**

- 进入 Booked 房间预约系统，查看练习室、讨论室、Student Hub 等资源。
- 查看排程、我的日历、预约查询与可用时间。
- 在官方网页内创建或取消预约。

**首版边界**

- 只提供官方网页入口；不承诺原生预约、原生取消或个人预约同步。
- 不展示实时余位：排程里的空白格不等于「可订」。
- 不缓存、不展示公开排程中的他人预约姓名。

**已知前提**

- 需要 Booked 本站账号登录，与学校 Microsoft 账号是否通用尚未验证。
- 系统 API 当前为关闭状态，没有可用的原生数据接口。
- 乐器练习房有书面规定（工作日 09:00–22:00、周末 09:00–17:00；最多提前两天；每天每间房最高一小时；一天内不允许重复预订）；文件未标生效日期，系统是否按此执行未验证。
- 预约 D4-103-9（电子琴练习室）时，官方表单有必填的「Usage of Instrument」。

**按钮**：「打开官方网页」「查看练习房规定」（官方来源链接见附录 A1）

#### 卡 4：体育中心

**用途**

- 进入体育中心会员系统，查看 15 个场馆的预约入口。
- 在官方网页内完成会员登录、预约、票券、取消与签到。

**首版边界**

- 只提供官方网页入口与场馆清单；不承诺余位、价格、票券、取消或签到。
- 不代注册、不代上传学生证/员工证/家属资料。
- 不判断「当前营业中」：首页两张开放时间表存在冲突且未标生效日期。

**已知前提**

- 体育中心使用独立的 MIKEX 会员账号（邮箱登录），与学校统一身份是否互通未验证。
- 没有账号需先在官方注册页提交资料，审核与可用时间未验证。
- 各场馆的取消、签到、每日限次配置不同；以场馆页面实际显示为准。
- 官方联系方式：体育中心前台 (0754)88077051，sportcenter@gtiit.edu.cn。

**按钮**：「打开官方网页」「会员注册页」「了解已知限制」

#### 卡 5：预约总览（预约 Tab 首屏提示条）

**标题**：两个预约系统互相独立

**正文**

- 练习房使用房间预约系统（Booked），体育中心使用 MIKEX 会员系统，账号与规则不同。
- 本应用不合并两边的预约记录，也没有原生预约接口；所有预约请在对应官方网页完成并确认。
- 预约前请阅读该场馆/房间的官方规则，规则以官方页面为准。

**按钮**：「练习房」「体育中心」

### E.4 错误态与空态文案

| 场景 | 触发条件（实现参考） | 标题 | 正文 | 按钮 |
|---|---|---|---|---|
| 加载失败 | WKWebView didFailProvisionalNavigation / didFail | 无法打开{站点名称} | 可能是网络受限或页面暂时不可用。你可以重试，或改用 Safari 打开。 | 「重试」「回到站点首页」「在 Safari 中打开」 |
| 无网络 | 系统网络不可用 / NSURLErrorNotConnectedToInternet | 当前没有网络连接 | 请先连接网络。部分校园页面可能只在校园网或特定网络下可用，这一点尚未验证。 | 「重试」 |
| 需要登录 | 网页跳转到登录页（无法自动判断时由用户触发） | 需要登录 | 该页面需要学校账号。请在官方网页内登录，本应用不会代填账号或密码。 | 「刷新」 |
| 登录已过期 | 网页自行回到登录页 | 登录状态已失效 | 请在网页内重新登录；其他站点的登录状态不受影响。 | 「重新加载」 |
| 首次加载中 | 页面尚未有可展示内容 | 正在打开{站点名称} | 显示站点域名与进度；页面内容以官方网页为准。 | —（显示进度） |
| 加载完成但无记录 | 网页显示空表/零数据 | （不使用 App 文案） | 初始占位、零数据、CLOSED 状态不等于「没有记录」；以网页实际业务结果为准。 | — |
| 教学评价未开放 | 网页显示未开放 | 评价暂未开放 | 开放时间以官方网页为准。本应用不代填、不代提交。 | 「刷新」 |
| 练习房规则提示 | 进入练习房说明卡或首次打开预约页 | 预约前请先读官方规则 | 练习房一般需提前预约，且有使用时长、提前天数与重复预订限制；具体以官方规定为准。 | 「查看练习房规定」「前往预约」 |
| 体育营业时间提示 | 进入体育说明卡或首页 | 开放时间以体育中心官方为准 | 官方首页展示的两张时间表存在冲突，且未标注生效日期。本应用不判断当前是否营业。 | 「查看官方首页」 |
| 体育会员未登录 | 场馆页要求会员登录 | 需要体育会员登录 | 体育预约使用独立会员账号；没有账号请先在官方注册页注册。 | 「会员登录」「注册页」 |
| 我的预约（无聚合） | 我的/预约 Tab 无数据区域 | 暂不提供预约聚合 | 两个预约系统都没有可用的原生接口，App 不合并预约记录；请在各官方网页查看「我的预约」。 | 「打开练习房」「打开体育中心」 |
| 清除网页数据 | 用户点「清除网页数据」 | 清除「练习房」网页数据？ | 将退出该站点并删除本机缓存的网页数据，不影响其他站点。 | 「清除」「取消」 |
| 免责声明未确认 | 首次启动未点继续 | 使用前请阅读 | 需先阅读并确认免责声明，才会加载官方网页。 | 「我已了解并继续」「查看隐私说明」 |

要求：

- 错误态不得伪装成空数据；「未连接」「未刷新」「没有记录」「页面不可用」要分开表达（架构方案 §4.2）。
- 错误提示不显示原始 URL 中的凭据参数；不显示网页 HTML 报错。
- 不自动无限重试，不做后台轮询。

### E.5 其他界面微文案

| 位置 | 文案 |
|---|---|
| Tab 1 | 门户 |
| Tab 2 | 学习 |
| Tab 3 | 预约 |
| Tab 4 | 我的 |
| 预约分段控件 | 「练习房 / 讨论室」「体育场馆」（短称：练习房 / 体育；分段下方显示各站一句边界） |
| 工具栏辅助标签 | 返回、前进、刷新、在 Safari 中打开、站点说明 |
| 我的 · 站点与会话 | 学生门户、Moodle、练习房预约、体育中心（点击进入站点；左滑「说明」「清除」） |
| 我的 · 常用入口 | 学习与课程、学业与成绩、校园服务、场地与预约四组快捷链接 |
| 我的 · 设置 | 「使用{面容 ID / 触控 ID / 密码}锁定」「清除全部网页数据」「重新查看首次启动说明」 |
| 我的 · 关于 | 非官方说明与隐私、版本号、研究快照 2026-10-21、官方入口链接 |
| 外部打开提示 | 「将在 Safari 中打开该页面」 |
| 首次启动按钮 | 「我已了解并继续」「查看隐私说明」（当前实现为「开始使用」，见 E.1 说明） |
| 应用名 / 标语 | GTIIT 校园助手 ｜ 四个官方网页，一个 App |
| 锁定页 | 「GTIIT 已锁定」/「成绩、考勤与预约页面已隐藏。解锁后继续浏览官方网页。」/「使用{面容 ID / 触控 ID / 密码}解锁」 |
| 我的 · 站点缓存状态 | 「本机已缓存网页数据（不代表已登录）」/「本机暂无网页缓存」 |
| 我的 · 清除全部 | 「清除全部站点的网页数据？」/「四个站点都需要重新登录，App 内不会保留任何账号信息。」 |

---

## F. 验收清单

### F.1 入口与深链

- [ ] 四个站点的首页 URL 与 A.1 完全一致，且可集中配置、不散落在各 View。
- [ ] 门户深链包含 `/grades`、`/enrollments`、`/attendance`、`/apps`、`/checklist`，且不暴露旧路由 `checklist-v1`。
- [ ] 未在门户公开路由清单中的路径（如当前源码里的 `/transcripts`）不作为默认深链；若保留，必须标注「未验证」并真机确认不会 404。
- [ ] Moodle 深链使用 `/moodle/my/`、`calendar/view.php?view=upcoming`、`calendar/export.php`；课程/活动 ID 不被硬编码为固定功能。
- [ ] 练习房深链包含 `/Web/dashboard.php`、`/Web/my-calendar.php`、`/Web/search-availability.php`、`/Web/reservation.php?rid=78`。
- [ ] 界面明确 rid=78 是 D4-103-9 电子琴练习室，不把 rid 当房间号，不遍历 91 个资源。
- [ ] 体育提供 15 个场馆链接，且 `kcr2S` 只对应羽毛球场，不被当作体育总入口。
- [ ] 所有深链在 App 内都是 WebView 初始 URL，不伴随页面解析或结果断言。
- [ ] 未验证项（登录后是否跳回目标页、深链是否回落登录页）在「已知限制」中可见。

### F.2 会话与登录

- [ ] 四站使用四个独立持久化 WKWebsiteDataStore（或明确的降级方案），不共用一个默认容器。
- [ ] 一个站点退出登录/清理数据后，其它三站仍可用。
- [ ] 不保存账号密码；不出现自建账号登录表单。
- [ ] 不宣传「一次登录四站全通」；界面文案不出现「一次登录」。
- [ ] 未登录时由网页自行跳转 SSO，App 不代填账号、不代点授权。
- [ ] 「我的 → 清除网页数据」按站点确认，提示不影响其他站点。
- [ ] 若最低版本低于 iOS 17，界面或 README 明确说明会话隔离限制（未验证项）。

### F.3 能力边界

- [ ] 全 App 无原生预约/取消/签到按钮；预约操作全部发生在官方网页。
- [ ] 全 App 无成绩、课程、作业、预约的本地示例/演示数据。
- [ ] 不出现「已同步」「实时更新」「自动刷新」等承诺（除「刷新」按钮本身）。
- [ ] 不出现作业/测验/评价/申请的原生提交或上传功能。
- [ ] 不显示「已登录/已连接」状态徽标；缓存状态文案明确「不代表已登录」。
- [ ] 网页下载只做「临时文件 + 系统分享」，不出现离线库、批量管理或自动上传。
- [ ] 门户、Moodle、练习房、体育的「首版边界」在站点说明卡中逐条出现。
- [ ] 体育「营业中/闭馆」不由 App 判定；开放时间冲突有提示。
- [ ] 不展示、不缓存、不分析他人预约姓名。

### F.4 信息架构

- [ ] 底部恰好四个 Tab：门户、学习、预约、我的，默认选中「门户」。
- [ ] 「预约」内含练习房 / 体育二段切换，两个 WebView 历史与会话互不干扰。
- [ ] 「我的」不加载网页，只含站点说明、隐私、免责声明、已知限制、清理、关于。
- [ ] 网页内部跳转不压原生导航栈；说明卡/隐私等原生页可返回。
- [ ] Tab 名称与全文文案统一（不混用「门户」与「今日」两套说法）。

### F.5 文案与首次启动

- [ ] 首次启动强制展示免责声明，必须点「我已了解并继续」才加载网页，不默认勾选。
- [ ] 首次启动不出现「继续使用即表示你已了解」式默示同意，改为显式确认；155 字声明全文可见。
- [ ] 免责声明正文与 E.1 一致（155 字，涵盖非官方、仅网页容器、账号仅本机、不采集不上传、不代提交、网络前提）。
- [ ] 「我的」可复看免责声明与隐私说明。
- [ ] 隐私说明 9 条齐全，包含 WebKit 本地存储、无埋点、不读页面内容、无自建服务器、清理方式与可选的生物识别锁定说明。
- [ ] 门户、Moodle、练习房、体育、预约总览五张说明卡均有「用途 / 首版边界 / 已知前提」。
- [ ] 练习房卡包含书面规则与「文件未标生效日期」说明；体育卡包含两张时间表冲突说明与官方联系方式。
- [ ] E.4 中每一种错误态/空态都有对应界面文案，不把加载中显示成「没有数据」。

### F.6 研究结论 ↔ App 行为一致性（逐条对账）

- [ ] Booked API 已关闭 → App 不出现任何原生预约/余位入口。
- [ ] Moodle 仅浏览器登录、移动令牌未验证 → App 不出现原生课程/待办/通知。
- [ ] 门户原生 OAuth 未获授权 → App 不出现「用学校账号登录 App」的自制登录。
- [ ] 体育会员独立、15 场馆能力不同 → 不出现统一的「可取消」「可签到」按钮。
- [ ] 两张体育开放时间表冲突 → App 不硬编码任一张为权威。
- [ ] Booked 公开排程可能含他人姓名 → App 不展示/缓存该页文本。
- [ ] 门户初始帧的 0/CLOSED 是占位 → App 不据此提示「没有课程/不能选课」。
- [ ] 教学评价开放时间是页面显示值（快照 2026-12-21 09:00）→ App 不写死、不倒计时承诺；快捷入口副标题不写具体日期。
- [ ] 门户 `/transcripts` 等未验证路径不进入默认快捷入口，或明确标注未验证。
- [ ] 练习房规定文件未标生效日期 → 文案写「以官方规定为准」而非「当前有效」。
- [ ] 研究快照日期 2026-10-21 → 「关于」页显示该日期。

### F.7 隐私与合规

- [ ] 无第三方统计/广告/崩溃 SDK（或明确列出并更新隐私说明）。
- [ ] 无自建业务服务器上传；网络请求只到四个官方域名（含登录重定向域名）。
- [ ] 日志不记录 URL 中的凭据参数、不记录页面 HTML。
- [ ] 不申请相机/相册/通讯录等非必要权限；文件上传由网页触发系统选择器。
- [ ] 生物识别锁只做界面遮挡，文案说明「不改变学校登录状态」，隐私说明包含生物识别数据由 iOS 处理。
- [ ] 明确标注「非官方学生项目」；学校名称/标识使用权限未确认。
- [ ] App Store 发布前补充正式隐私政策与 4.2 最低功能评估（未验证项，见 G）。

---

## G. 未验证事项汇总（供 README「已知限制」引用）

### G.1 未验证清单

| 编号 | 系统 | 未验证事项 | 当前状态 / 风险 | 来源 |
|---|---|---|---|---|
| V-01 | 门户 | 登录后完整菜单、角色差异、条件字段 | 只读到部分页面；角色与动态条件未盘完 | 可行性分析 §2A；capability-matrix.json |
| V-02 | 门户 | 原生 OAuth（Entra 应用注册、回调、Scope） | 未获学校支持，不能假定可用 | 架构方案 §1.1 |
| V-03 | 门户 | 成绩单/答卷下载的实际结果与文件授权 | 按钮存在，未下载 | 可行性分析 §2A |
| V-04 | 门户 | 第三方客户端/网页容器是否被允许；Code of Conduct 边界 | 规范限制「其他软件」；许可未确认 | 可行性分析 §2A |
| V-05 | 门户 | 使用规范、知情授权页面的运行时行为 | 未单独打开 | portal-static-inventory.json |
| V-06 | 门户 | 未登录打开子路由的回落行为、登录后是否跳回 | 未验证 | A.0、A.6 |
| V-07 | Moodle | 自有回调、移动服务令牌、可用函数清单 | 仅有公开配置；未生成令牌 | moodle-findings.md；Moodle-只读接口验证方案.md |
| V-08 | Moodle | 日历导出的内容完整性与订阅认证 | 只看到表单，未生成链接 | 可行性分析 §2.5 |
| V-09 | Moodle | 自定义课表 local/calendar 的数据接口 | 插件页面可见，接口未知 | 可行性分析 §2.4 |
| V-10 | Moodle | 文件下载/视频/文件夹/批量与离线 | 未验证 | 可行性分析 §2.3 |
| V-11 | Moodle | 账号时区与时间戳转换 | 页面日期未与 API 对照 | 可行性分析 §2.2 |
| V-12 | Moodle | 通知、消息、推送 | 自制 App 不继承官方推送 | moodle-findings.md |
| V-13 | 练习房 | 资源权限、提前开放期、配额的实际执行 | 只有书面规定与服务端未知 | 可行性分析 §2B |
| V-14 | 练习房 | 已有预约的详情、修改、取消、审批/等待名单 | 未创建预约，取消未验证 | 可行性分析 §2B |
| V-15 | 练习房 | Booked API 当前关闭，未来是否开放 | 直接观察为 disabled | booked-resource-inventory.json |
| V-16 | 练习房 | 练习房规定的生效日期与当前有效性 | 文件未写生效日期；系统执行未验证 | 可行性分析 §2B；练习房 PDF |
| V-17 | 体育 | 会员登录后的表单、余位、价格、票券、取消、签到 | 仅到会员登录关口 | capability-matrix.json |
| V-18 | 体育 | 两张开放时间表的优先级与生效期 | 内容冲突、无生效日期 | sports-findings.md；sports-info-*.png |
| V-19 | 体育 | 供应商 API、学校身份与会员映射 | 未知 | sports-findings.md |
| V-20 | 体育 | 注册审核流程与会员资格 | 未注册 | sports-findings.md |
| V-21 | 全局 | iPhone 真机在校园 Wi-Fi / 蜂窝 / 校外 Wi-Fi 的四站可达性 | 只验证了 Mac 网络（且需直连/DNS 修复） | 可行性分析 §1；后续验证清单.md |
| V-22 | 全局 | Safari / ASWebAuthenticationSession 与 WKWebView 的会话关系 | 具体站点未真机验证 | 可行性分析 §3.1 |
| V-23 | 全局 | 最低 iOS 版本与 iOS 17 多数据容器真机行为 | 方案建议，未实现未验证 | 可行性分析 §3.2 |
| V-24 | 全局 | 后台刷新、固定轮询、APNs 推送 | 未验证且不承诺 | 架构方案 §4.2 |
| V-25 | 全局 | Microsoft 登录能否在 WKWebView 内完成 | 未验证；可能需系统浏览器 | B.3 |
| V-26 | 全局 | App Store 4.2 最低功能、学校名称/标识使用权限 | 未评估 | 架构方案 §6 |
| V-27 | 全局 | 网站改版导致 URL 失效 | 快照仅 2026-10-21 | A.0 |
| V-28 | 全局 | 会话过期时长、后台恢复是否需重登 | 未验证 | 后续验证清单.md |
| V-29 | 全局 | 网页触发的文件下载在 iOS 中的去向与预览 | 未验证 | 架构方案 §4.1 |
| V-30 | 全局 | 校外网络下的证书与登录跳转 | 未验证 | 后续验证清单.md |

### G.2 README「已知限制」建议条目

- 本应用是学生个人项目，非学校官方应用，与广东以色列理工学院无隶属关系。
- 四个网站以官方网页形式嵌入，App 不原生读取成绩、课程、作业、考勤或预约数据。
- 学生门户是否允许第三方客户端/网页容器访问尚未确认；如学校限制，相关页面可能无法在 App 内使用。
- 四个站点账号体系不同，不能一次登录全部打通；部分站点可能需要在 App 内分别登录。
- 练习房预约系统的 API 当前关闭；体育中心无公开接口。App 不提供原生预约、取消、签到或余位。
- 体育中心首页两张开放时间表存在冲突且未标生效日期，App 不判断营业状态。
- 不做后台自动刷新与推送；不存在「自动同步」。
- 全部结论基于 2026-10-21 的公开页面与只读观察，网站改版后链接可能失效。
- 最低 iOS 版本、iOS 17 数据容器、校内/校外网络可达性均待真机验证。

---

## 附录

### A1. 关键外部参考链接

- WebKit 多持久化数据容器：[Building profiles with new WebKit API](https://webkit.org/blog/14423/building-profiles-with-new-webkit-api/)（可行性分析 §3.2）
- Microsoft iOS 回调注册：[Redirect URIs for MSAL iOS](https://learn.microsoft.com/en-us/entra/msal/objc/redirect-uris-ios)（架构方案 §1.1）
- Microsoft 浏览器与 WebView：[Customize webviews](https://learn.microsoft.com/en-us/entra/msal/objc/customize-webviews)（可行性分析 §3.1）
- Moodle 移动登录握手：[launch.php（MOODLE_39_STABLE）](https://github.com/moodle/moodle/blob/MOODLE_39_STABLE/admin/tool/mobile/launch.php)
- Moodle 外部服务：[External services](https://moodledev.io/docs/apis/subsystems/external)
- Moodle 通知：[Moodle app notifications](https://docs.moodle.org/en/Moodle_app_notifications)
- Apple 后台执行：[Choosing background strategies](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)
- ASWebAuthenticationSession：[Apple 文档](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
- Booked API：[API overview](https://www.bookedscheduler.com/help/api/api-overview/)
- App Store 4.2：[Minimum functionality](https://developer.apple.com/app-store/review/guidelines/#minimum-functionality)
- 乐器练习房书面规定（官方来源入口，来自 Moodle 服务空间文件）：https://moodle.gtiit.edu.cn/moodle/mod/resource/view.php?id=87735 （本地证据：续研/evidence/instrument-practice-regulations-2025.pdf；文件未标生效日期）

### A2. 文案字数核对

- E.1 免责声明：155 字（含标点），在 100–160 字要求内。

### A3. 变更记录

| 版本 | 日期 | 内容 |
|---|---|---|
| v1.0 | 2026-10-21 | 首版：A 深链表、B 会话前提、C 能力边界、D 信息架构、E 文案、F 验收、G 未验证汇总 |

### A4. 与当前实现快照的对照（E5，只读源码，2026-10-21）

> Lead 正在并行编写 Swift 源码。以下只记录「规格 vs 当前实现」的差异，供实现时取舍；源码以 Lead 最新版本为准，本文不修改源码。

| # | 当前实现（E5） | 研究 / 规格要求 | 建议动作 |
|---|---|---|---|
| 1 | 门户快捷入口包含 `https://students.gtiit.edu.cn/transcripts`（QuickLink `portal.transcripts`） | portal-static-inventory.json 的公开路由清单中**没有** `transcripts`，只有 `grades`、`apps`、`enrollments`、`attendance`、`evaluations`、`checklist` 等；成绩单入口在 Grades / Applications 页面内 | 真机确认前不要放进默认快捷入口；若保留，标注「未验证」并准备 404 回退 |
| 2 | 教学评价快捷入口副标题写死「页面显示 2026-12-21 开放」 | 这是 2026-10-21 快照里页面显示的开放时间，日期过后会误导，且学校可能调整 | 改为「开放时间以网页为准」，不在 App 内写死日期或倒计时 |
| 3 | WelcomeView 由 5 个要点卡 + 「开始使用」+ 页脚「继续使用即表示你已了解…」组成 | E.1 要求 155 字完整免责声明、显式主动确认；默示同意弱于门户「不能自动勾选授权」的原则 | 加入完整声明段落；主按钮改「我已了解并开始使用」；删除「继续使用即表示」式表述 |
| 4 | SiteInfoView 只显示 capabilityNotes 三条、入口地址与清除数据 | E.3 要求「用途 / 首版边界 / 已知前提」 | 至少补「已知前提」（登录方式、网络前提、规则来源、未验证项） |
| 5 | 我的站点状态显示「已保存网页数据 / 尚未产生数据」 | App 不读取页面，无法判断登录状态；该文案易被读成「已登录」 | 改为「本机已缓存网页数据（不代表已登录）/ 本机暂无网页缓存」 |
| 6 | DownloadCoordinator 把网页下载落临时目录并交系统分享；FilePickerCoordinator 用系统文稿选择器上传 | 与「不做离线库、不自动上传」的边界一致 | 隐私说明补一句「下载文件只落在本机临时目录，上传文件由你在系统选择器中自行选择」；明确临时文件清理策略（未验证） |
| 7 | 可选生物识别锁（Face ID / Touch ID）遮挡界面 | 研究未涉及；属于新增原生能力 | 隐私说明与锁定页文案已按「只遮挡界面、不改变学校登录状态、生物识别由 iOS 处理」补齐（E.2 第 8 条、E.5） |
| 8 | 应用名「GTIIT 校园助手」、标语「四个官方网页，一个 App」 | 无冲突；但发布前需核对学校名称/标识使用权限（V-26） | 保留，同时在「关于」页保留「非官方学生项目」声明 |

**结论**：当前实现的容器划分（四个独立持久化容器）、预约分段、清除数据、下载交接与锁定方向与研究一致；主要待修是免责声明强度、`/transcripts` 未验证路径、评价日期写死与站点说明卡信息不完整。

> 本文档只描述规格与文案。若实现与研究结论冲突，以研究资料原文与真机验证结果为准，并回写本文档。
