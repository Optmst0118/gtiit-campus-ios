# 2.0.3-beta.2 · build 73

2026-10-26，在 beta.1 的共享玻璃导航修复上继续整理网页外观。

移除四站官方网页最外层 canvas／page wrapper 的灰色边框、outline 和外阴影，覆盖 Moodle 的 region-main、main-inner 等活动页外壳。处理在浅色／深色、横屏／竖屏都生效，不改变页面结构、业务事件和登录会话，不移除内部表单、表格和普通内容卡片的边框。

四站浅深色专项 30/30（含 14 项基础检查、16 项外框与内部控件检查）。完整结果见[验证记录](verification/shell-borders/README.md)。保留 [beta.1 共享玻璃导航](RELEASE-2.0.3-beta.1.md)的所有修复。
