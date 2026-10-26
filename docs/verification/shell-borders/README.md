# 套壳网页外框清理

2026-10-26，2.0.3-beta.2 build 73。

WebViewHostView / WebViewContainer 没有设置边框。修改官方域名隔离样式的 shellCSS：仅移除 html/body、已知页面根节点、Moodle 内容外壳与顶层 iframe 的外边框；不使用 `* { border: 0 }`，不移除普通 input、table cell、content card 的边界，不改动 DOM 或表单业务事件。

[专项 30/30](results.json)使用四个官方 baseURL 的隔离 WKWebView fixture，在浅／深色下逐一验证根节点 border=0、outline=0、box-shadow=none；内部输入框、卡片和表格仍为 2px 边界，输入值与按钮事件不变。fixture 使用横屏 874×402 尺寸，CSS 没有横竖屏条件。此检查是可复现的样式回归，不等同于逐站真实登录后的目视检查。

工程结构、本地化检查、Release 构建及 App／Widget 签名与版本校验通过；完整回归 [401/401](../regression-results.json) 通过。

真机安装尝试被 CoreDevice 拒绝（4016，设备 unavailable），本次 build 73 尚未安装。此前 build 72 的共享玻璃导航已覆盖安装并成功启动；待恢复设备连接后安装 build 73，保留已有数据。
