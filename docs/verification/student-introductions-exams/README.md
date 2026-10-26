# Student 引导及考试页整理

2026-10-27。2.0.4-beta.1 build 74，基线 cd2f20c。

## 诊断

读取 Student 的[公开前端脚本](https://students.gtiit.edu.cn/assets/main-04ae7cda.js)（版本字符串 0.1.171），确认存在两套独立逻辑：

- 首次导览：读取 localStorage 的 showcase.landing / landing_v2 / grades / enrollments。
- 每日账户提示：超过一天时给 `[data-filter]` 添加 disabled 类；提示自己的 Continue 处理器写入站点偏好并移除该锁定样式。仅隐藏提示会留下模糊与点击阻断。

## 修改

只关闭已核对的四个 showcase 标记，保留其他同名记录字段。通过已核对的静态提示文字与 Logout / Continue 按钮组合定位账户提示，调用已有 Continue。已有 Joyride 导览调用自身 Skip，避免留下页面焦点／滚动锁。Student 域名专用 MutationObserver 只调度这项轻量处理，覆盖 12 秒后挂载和 SPA 路由。

不读取账户 ID、口令或表单值；不改写 lastLogin 或会话凭据。授权／行为准则对话框不匹配提示规则，不自动接受。

考试页删除独立顶部 Section；更新时间改为考试安排 footer。登录、失败重试、首次加载状态并入考试安排，仅在需要时出现。

## 验证

[专项 21/21](results.json)：含 14 项基础检查及 7 项针对测试。真实 WKWebView 非持久隔离存储，模拟门户自己的 Continue 事件、13 秒后再次弹出、延迟 Joyride、业务按钮、输入内容和其他域名。确认额外偏好字段保留，授权按钮未触发，其他站点不自动关闭提示。

工程、本地化检查通过；Release 构建及 App／Widget 版本、签名与 profile 校验通过。新增场景并入常规回归后，最终[完整回归 408/408](../regression-results.json)通过。

整合过程两次遇到原有检查不稳定：同 URL 加载的旧文档被误判就绪，另有测试 WebKit 进程启动超时。回归工具现用旧文档标记消失与 readyState=complete 验证新文档，避免在旧页面上继续 popup 操作；测试 fixture 的启动等待改为 15 秒，生产预加载时限测试仍单独使用 0.2 秒并要求 1 秒内结束，未放宽产品时限。修改仅涉及测试。

设备交付：build 74 已覆盖安装至 iPhone Air，devicectl 确认启动成功。未卸载或清理现有登录与下载数据。
