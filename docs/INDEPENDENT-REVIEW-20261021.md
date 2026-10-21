# GTIIT iOS App 独立验证（2026-10-21）

结论：工程可以构建和启动，适合作为四站网页容器的首版原型；尚不足以据此认定四站业务完整可用。优先修复导航策略，再完善设置页。此次只增加审查材料与测试证据，没有改动产品源代码、重签手机或覆盖原 ZIP。

## 样本与验证范围

- 样本：工作区 `GTIIT-iOS-App` 与同级 `GTIIT-iOS-App.zip`。逐一比较 App 内 24 个 Swift 文件，内容完全一致。
- ZIP SHA-256：`74dd244797c940c0c0e4053eb746653cf318e52c88ffcb557367daa616b3612f`。
- ZIP 是源码工程与文档包，不是可直接安装的 IPA。
- Xcode 27.1；独立 derived data：`/tmp/GTIIT-independent-review`。Debug、Release 模拟器构建均成功；只有未使用 AppIntents 时跳过元数据提取的工具提示。
- `Tools/check_project.py` 通过：24/24 源文件引用、资源及图标检查正常。此检查不覆盖业务行为。
- 新建隔离 iPhone 17 / iOS 26.5 模拟器：`GTIIT-Independent-Review`。已安装并启动原工程 Debug App，检查首次引导勾选与进入、门户跳转 Microsoft 登录页，以及“我的”首屏。没有改动原模拟器或真机中的登录数据。
- 导航边界使用原始 BrowserModel / AppModel 编译专用测试 App。测试构造 WKNavigationAction 输入，直接调用原导航策略；目标请求由真实 WKWebView 的导航代理截获并取消，不提交学校表单。源码与机器结果见 `independent-review/`。
- 未验证四站完整登录、真实预约/作业提交、真实附件下载、Face ID、后台快照、VoiceOver 全流程。Safari 会话不自动共享给本 App 的独立 WKWebsiteDataStore。此次没有把“能跳到登录页”计为业务验收通过。
- Device Hub 的坐标点击/滚动接口返回 `noWindowsAvailable`，限制了本次 UI 自动化覆盖；没有把工具错误记为 App 缺陷。“我的”下部设置区域依据源码审查，未声称逐项实机操作通过。

## 已确认问题

### 1. [P2] 跨站表单路由丢失 POST 方法与请求体

位置：`GTIIT/Services/BrowserModel.swift:279–287`、`GTIIT/App/AppModel.swift:121–128`、`GTIIT/Services/BrowserModel.swift:94–99`。

导航策略将 `.formSubmitted` / `.formResubmitted` 纳入跨站切 Tab，但 BrowserRouter 只传 URL，目标容器重新构造 URLRequest。测试输入 POST、带非敏感测试请求体，原导航被取消；目标 WebView 实际收到 GET。跨站表单或 POST 登录交接若触发此分支，会丢失字段，无法按原请求完成操作。尚未确认学校实际页面是否采用这一种跨站交接。

建议：普通链接可按 URL 路由；表单与带 body 的请求需保持原请求语义，并验证会话、origin、重定向。不能无条件改成 GET，也不能在不核对认证上下文的情况下跨容器重发敏感 POST。优先让此类导航在原上下文完成，再设计站点切换策略。

验收：GET、POST、POST 重提、307/308 重定向分别保持预期方法和字段；不重复提交。

### 2. [P2] 路由防抖反而允许第二次跨站导航进入原容器

位置：`GTIIT/Services/BrowserModel.swift:282–290,311–320`。

同一个跨站链接在 3 秒内连续触发两次，第一次返回 cancel 并切 Tab，第二次 `shouldRoute` 为 false 后落到 allow。测试结果为 `[cancel, allow]`，路由回调仅一次。重复点击或回调会让目标站留在来源站的容器，违背四站隔离的交互约定，并可能出现相同站点在两个容器拥有不同登录状态。

建议：分开判断“是否取消原导航”和“是否需要再次切换”；重复路由应取消原导航，不应放行。

验收：相同链接连续触发两次、不同链接快速触发，来源 WebView 始终不加载被路由站点。

### 3. [P2] 所有非 HTTP(S) 导航都被当成系统 App 链接

位置：`GTIIT/Services/BrowserModel.swift:294–296`。

测试 `blob:https://students.gtiit.edu.cn/review`，结果为取消导航并交给系统外部打开。`blob:` 属于当前网页环境的资源，无法通过 UIApplication 外部打开恢复其内容；网站若以 blob 页面做文档预览/导出，此路径会失败。`data:`、`about:blank` 也没有按 WebKit 内部页面区分。带 `shouldPerformDownload` 的导航有更早的下载分支，本问题不代表所有 blob 下载都失败。

建议：区分 WebKit 内部 scheme、可下载资源和受支持的外部 App scheme；为各分支建立明确策略。使用真实本地测试页补测 blob 预览、下载及空白弹窗后赋值流程。

### 4. [P2] “在 Safari 中打开”实际呈现 App 内 Safari 控制器

位置：`GTIIT/Views/SiteBrowserView.swift:128–131`、`GTIIT/App/AppModel.swift:131–138`。

菜单名称及方法名表示外部浏览器，HTTP(S) 实际使用 SFSafariViewController。用户需要跳到已登录 Safari 继续访问时，当前动作不能提供这个出口。此项由原始代码路径确认，未声称本次做过 Safari 会话互通测试。

建议：提供真实的“在默认浏览器中打开”，通过系统打开 URL；如保留内置 Safari，单独命名。说明不同浏览容器可能需要分别登录。

### 5. [P3] 顶部锁图标与页面安全状态无关

位置：`GTIIT/Views/SiteBrowserView.swift:53–60`、`GTIIT/Info.plist` 的网页 ATS 设置。

只要停止加载就显示 lock.fill，未判断当前 scheme 或安全内容。工程允许 WebView 加载 HTTP，所以 HTTP 页面、混合内容、失败状态也可能显示锁。应按真实连接状态展示，或改成没有安全含义的站点标识。

## 设置页应如何接近完整 App

目前 AppSettings 只有“看过引导”和“锁定”两项偏好。“我的”页把品牌介绍、四个站点、长篇技术说明、快捷入口、三项设置、关于全部串在一个长列表中，首屏看不到设置入口。视觉基础已有原生感，主要问题是信息层级与可管理能力不足，不需要继续堆介绍卡片。

建议让“我的”承担常用入口和站点概览，右上角提供始终可达的齿轮入口，进入独立的原生设置页。设置用系统 grouped Form、语义字体、统一行高与图标；每行只保留名称、当前值、必要的短说明。复杂说明放详情页。

| 分组 | 建议项目 | 必须接通的行为与边界 |
| --- | --- | --- |
| 通用 | 外观：跟随系统/浅色/深色；启动页面；默认预约分类 | 偏好持久化，重启仍生效；首次引导不能被启动页偏好绕过 |
| 隐私与锁定 | App 锁定；锁定时机；后台内容遮挡；立即锁定 | Face ID/设备密码回退；取消后保持锁定；包括分享、Safari、说明页等模态层的快照保护 |
| 站点与登录 | 四站详情、打开站点、站点说明、清除本站数据 | “有网页数据”不能冒充“已登录”；清除需说明影响并处理活动页面与历史 |
| 浏览 | 外部链接打开方式；恢复浏览位置的明确策略 | 真正区分 App 内网页、内置 Safari、系统默认浏览器；表单编辑中切换要验证 |
| 存储 | 缓存、Cookie/登录数据、临时下载分别管理 | 清缓存不应无意退出登录；数据大小只有能准确测量时才显示，否则使用可核对的状态/数量 |
| 下载 | 当前任务状态、失败重试、临时文件管理 | 当前实现仅下载后分享、下次启动清理；若添加下载中心，需明确保留周期及保存到“文件”的区别 |
| 帮助与诊断 | 四站网络检测、校园网络说明、常见登录问题、反馈 | 只读检查不自动提交业务；可复制脱敏错误信息，排除 Cookie、token、账号与完整认证 URL |
| 关于 | 版本与构建号、隐私、非官方说明、已知限制 | 与实际实现和发布包一致；长篇技术实现从主设置页移到这里 |

第一轮优先实现：独立设置入口、外观、启动页、站点数据详情、真实外部浏览器出口，以及清晰的锁定设置。第二轮再做下载管理与诊断。没有服务端或系统任务支持时，不放置“成绩自动同步”“作业推送”等无实际作用的开关。

## 发布前仍需补测

1. 在 App 内逐站完成真实登录与冷启动恢复；门户 Microsoft、Moodle 登录交接、房间登录、体育登录分别记录结果。
2. 新窗口登录需覆盖 window.open、opener/postMessage 回调。当前返回 nil 并改在原 WebView 打开，不能据此保证全部 SSO 可用。
3. 清数据后验证当前页面、前进/后退历史、进行中请求、本地存储与 Cookie；目前清除后复用 WebView 并加载首页，不能仅凭提示断言所有账号相关内容都消失。
4. App 锁覆盖后台、控制中心、认证取消、应用启动及模态控制器；Root 对嵌套 lock 的依赖未直接观察，应补测解锁后触控/VoiceOver 状态，必要时统一观察层级。
5. 真实附件覆盖 PDF、Content-Disposition、重名并发下载、取消分享、失败重试与大文件；上传仅使用无敏感内容的测试文件，不提交真实作业。
6. 小屏、大字体、深色、横屏及 iPad；浏览栏按钮目前固定 34×34，需扩大有效触控区域，确认超大字体不截断关键信息。

业务提交应在明确的测试环境或由用户本人操作，不以真实预约、选课或作业提交作为自动化探针。

## 测试证据与重跑说明

- `independent-review/ReviewHarness.swift`：独立 UIKit 测试入口，和原 GTIIT 全部 Swift 文件（排除 GTIITApp.swift）共同编译；不放入产品 target。
- `independent-review/results.json`：本次模拟器输出。WKNavigationActionPolicy 原始值 0=cancel、1=allow。
- 专用测试包 ID 为 `local.gtiit.independentreview`，不同于原 App 的 `io.github.optmst0118.gtiit`。只安装在新建测试模拟器。
- Debug 构建日志 `/tmp/gtiit-review-build.log`，Release 日志 `/tmp/gtiit-review-release.log`。构建均使用 `CODE_SIGNING_ALLOWED=NO`，结果只证明模拟器可构建，不能替代真机签名和发布验证。
