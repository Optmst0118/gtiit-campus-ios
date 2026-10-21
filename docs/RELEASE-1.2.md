# GTIIT 1.2 (6) · 2026-10-21

1.2 (6) 签名 Release 已覆盖安装到 iPhone Air（iOS 27.0.1），并由 devicectl 确认启动。

本次交付覆盖原客户端，保持同一 bundle identifier。1.1 完整代码与历史在 Git 标签 `gtiit-before-1.2`；原始 1.0 基线为 `0de31f5`。本轮没有适配非全面屏设备。

## 实现

- 顶栏不再显示域名、前后退箭头或一级刷新按钮；点击标题回本站主页；刷新在更多菜单中。
- 基于用户给出的校徽，完成天蓝／橙色二维制图改绘；可编辑的 Icon Composer 工程保存在 docs/design/AppIcon.icon（需 Xcode 27 才能编译 Liquid Glass）；主工程为兼容 Xcode 26 使用 PNG 图标。预览与来源见 [设计看板](design/DESIGN.md)。
- 原生班车标签在最左侧，南→北与北→南双栏展示下一班和随后两班，自动处理跨午夜、教学周指定星期和重复发车时间。40 项独立检查通过。
- 数据全部来自用户给出的 2026-10-12 生效时刻表，共 58 个独立车次；官方时刻表原图不在本仓库再分发，只保留解析后的车次数据。教学周需手动确认；19:30 后提示 9 号门关闭，保留原表站点顺序，不擅自推断车辆改线。
- PDF 响应直接交给 WKDownload，不额外发 GET；POST、一过性链接、Cookie 仍留在原 WebKit 会话。右下角天蓝面板显示进度、预览和系统另存位置选择器。
- WebKit `WebKitErrorDomain:102` 是下载／导航策略导致的中断，不再误显示断网页；真正网络、证书错误仍显示。
- 完成面板约 4 秒后以 250ms 渐隐；切换标签、预约分类或网页时立即收起。打开预览或保存位置选择器也会收起面板。隐藏面板与下载文件独立。
- 文件默认永久保存在 Documents/Downloads，支持“文件 → 我的 iPhone → GTIIT”，可另存到 iCloud Drive。旧缓存目录会迁移，不卸载、不主动清除手机登录数据。

- 下载完成不再另叠 Toast；主页面与网页子窗口交接唯一下载面板。iOS 26+ 使用原生 glassEffect 液态玻璃。
- “GTIIT 校园助手”卡片从“我的”移至“设置 → 关于”。

- 班车页标题改为“Shuttle Bus时刻表”；关于页详细说明移入“隐私与安全”“技术日志”两个独立入口。“我的”删除校园网站四个重复入口。

## 验证

- 原产品全部 37 个 Swift 源文件进入工程；结构、资源和不透明 1024px 备用图标检查通过。
- 73 项真实 WebKit／产品源码集成检查通过：PDF 附件、inline PDF、POST PDF 原响应、无额外 GET、持久文件、浮窗自动隐藏和保留文件、下载取消／续传、清理与数据隔离、隐私锁等。
- 40 项班车独立检查通过：七天每日车／教学周车数量、重复时间两车、发车边界、秒数进位、跨午夜和生效日期。
- 模拟器 Debug 与真机签名 Release 构建检查；结果见 `verification/build-results-1.2.json`。
- 实机已实际出现 PDF 下载完成浮窗；用户同时复现的 Frame load interrupted 误报已修复，并加入回归。

## 限制

班车没有 GPS 或实时到站接口，倒计时只表示距计划发车。教学周、假期与调休没有自动校历数据，校方最新通知优先。网页仍使用学校原设计，天蓝／橙色视觉覆盖原生界面。图标是非官方改绘，不代表学校发布。

## 回溯与复现

```sh
git worktree add ../GTIIT-iOS-App-v1.1 gtiit-before-1.2
python3 Tools/gen_project.py
python3 Tools/check_project.py
python3 Tools/run_regression.py <Review测试模拟器UDID>
xcrun swiftc GTIIT/Models/ShuttleSchedule.swift Tests/ShuttleRegression.swift -o /tmp/gtiit-shuttle-tests
/tmp/gtiit-shuttle-tests
```

源代码 ZIP 与全历史 Git bundle 会随最终版本一并导出；本机个人签名配置不进入源码包。
