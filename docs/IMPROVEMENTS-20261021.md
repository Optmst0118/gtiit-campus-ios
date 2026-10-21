# 1.1 改进与验收记录

日期：2026-10-21。此文替代旧版 QA 文档中的现状描述；旧文保留用于追溯。

## 审查问题的处理

| 原问题 | 实现 | 证据 |
| --- | --- | --- |
| 跨站 POST 变 GET | 只有用户点击的普通 GET 链接可以切容器，表单及认证留在原 WebKit 上下文 | 回归 `cross_site_post_keeps_request_context`、`real_webkit_post_reaches_echo` |
| 3 秒防抖允许串站 | 移除有漏洞的防抖分支；每次跨站路由都取消来源导航 | `repeated_cross_site_link_cancelled` 返回 cancel/cancel |
| blob 等被交给系统 | WebKit 内部 scheme 与可支持的外部 App scheme 分流 | `internal_scheme_*`、`real_blob_preview` |
| Safari 入口名实不符 | 默认浏览器通过 UIApplication 打开；内置 Safari 单独命名 | 两个独立路由分支和回归 `external_link_*_route` |
| 停止加载就显示安全锁 | 使用不暗示连接安全的 globe 图标 | SiteBrowserView 顶栏源码与界面检查 |
| 新窗口扁平化 | 按提供的 WKWebViewConfiguration 创建真实子窗口 | `real_popup_opener_postMessage`、`popup_window_close` |
| 清数据后旧页面/历史仍存在 | 空白化旧文档、移除代理、切换新容器并删除旧容器、替换内核，不自动访问首页 | `clear_replaces_webview_and_history`、`old_document_cannot_repopulate_storage`、`clear_does_not_autoload` |
| 设置内容少、入口埋得深 | 独立设置与八类管理页，真实偏好持久化 | `preferences_persist` 与设置页 UI 检查 |
| 下载只有立即分享 | 本机下载任务、进度/取消/可用时续传/保留期/分享/清理 | `renderable_pdf_attachment_download`、`download_progress/cancel/resume`、`download_retention_*` |
| 锁状态观察和模态遮挡 | 转发锁状态变更，独立遮挡窗口位于 alert 层上方 | `privacy_shield_over_modal`、`privacy_shield_removed_on_return` |

## 设置能力与约束

“我的”保留常用入口、四站入口和下载，右上角齿轮直达设置。设置分为通用、隐私与锁定、网页浏览、站点与登录、存储空间、下载管理、帮助与诊断、关于。

系统 Form / List / NavigationStack、语义字体及系统蓝适配浅深色和 Dynamic Type。浏览栏按钮至少 44×44 点；辅助功能字号时将前进与刷新收进菜单，保留更大的地址显示空间。

缓存清理不删除 Cookie 或 LocalStorage，不刷新正在编辑的文档。清登录数据会销毁页面和历史，UI 明确提示未提交内容会丢失。网页数据数量不冒充登录状态，也不虚构无法测量的网页缓存大小。

恢复地址只保存同站、不含参数的普通 HTTPS 路径；关闭即删除。诊断使用独立 ephemeral URLSession，不带 Cookie/Authorization、不跟随重定向；摘要不含完整请求 URL、账号或网页内容。

## 自动检查

最新机器结果：`verification/regression-results.json`。56 项通过，包含原产品代码与本地 HTTP 测试页的实际交互。

认证的成功、失败、取消、不可用通过可注入的认证接口验证锁状态；生产实现始终使用 LocalAuthentication 的 deviceOwnerAuthentication，支持设备密码回退。模拟器现场验证已到达系统密码回退界面；没有猜测或输入设备密码，不能据此声称真实 Face ID/Touch ID 硬件已验收。

最终 Debug 模拟器、Release 模拟器、Release 真机目标三种构建均成功；全程 `CODE_SIGNING_ALLOWED=NO`。机器记录见 `verification/build-results.json`，含源文件摘要。`Tools/check_project.py` 校验 34/34 源文件及图标资源通过，`git diff --check` 通过。构建仅有未使用 AppIntents 时跳过元数据提取的工具提示，没有 Swift 编译警告。无签名真机目标构建不等于已签名安装或 App Store 可发布。

视觉与交互检查覆盖 iPhone 17、iPhone SE（375 点宽）、iPad 13 英寸竖屏/横屏、浅色/深色，以及最大的辅助功能字号。大字号选择器会进入独立列表，长值可以换行，选择后返回并更新。SE 检查使用独立 UIReview 包与原产品视图（截图中的测试包版本可不同）；iPhone 17 与 iPad 使用 GTIIT 产品目标。截图保存在 `verification/`。

缓存验证不仅检查记录数量：本地页面先确认命中可缓存响应；清理后重新请求并取得服务器更新的响应。Cookie 与 LocalStorage 通过网页实际读取确认清空，并验证四站容器互相隔离、单站清理保留其他站点、全站清理删除所有合成 Cookie。旧容器删除由 WebKit API 结果验证。测试异步等待使用真实 Promise 完成回调，测试编译开启 warnings-as-errors，运行标识防止误用旧结果。

## 尚需真实校园环境验证的部分

本地测试确认容器层机制，不能代替学校当前所有登录和业务流程。四站分别登录、学校 SSO 的具体策略、真实附件以及真实账号下的冷启动恢复，仍需要用户在 App 内的账号环境下复核。Safari 登录状态不会自动共享到 App 的四站数据容器。

本轮不自动提交真实预约、作业或其他学校业务，不修改 Clash、学校账户、证书信任或真机数据。这些外部验证边界不以绿色构建或本地模拟结果代替。

## 可回溯性

修改前 Git 基线 `0de31f5`；功能实现 `b25fbe1`。README 包含独立 worktree 恢复方法及完整压缩快照路径。新源码包单独命名，不覆盖原 ZIP；本机签名配置不进入 Git 和更新 ZIP。

## 界面证据

| 场景 | 截图 |
| --- | --- |
| 小屏设置页 | [iPhone SE](verification/settings-iphone-se.png) |
| 最大辅助功能字号 | [设置页](verification/settings-iphone-se-largest-text.png)、[完整选项列表](verification/choices-iphone-se-largest-text.png) |
| iPad 竖屏 / 横屏 | [竖屏](verification/settings-ipad-portrait.png)、[横屏](verification/settings-ipad-landscape.png) |
| 深色外观 | [iPad 通用设置](verification/settings-ipad-dark.png) |

最终源码与回溯历史分别导出为同级 `GTIIT-iOS-App-1.1-reviewed.zip` 和 `GTIIT-iOS-App-history.bundle`，原 ZIP 保留。源码 ZIP 不包含 `.git`、个人签名环境文件或编译产物；Git bundle 用于恢复完整提交历史。
