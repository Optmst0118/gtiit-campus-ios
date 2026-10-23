# GTIIT 1.11 · Campus in motion

## 参考看板

| 参考来源 | 采用的设计原则 | 本项目应用 |
| --- | --- | --- |
| [ArtCenter College of Design](https://www.artcenter.edu/) | 清楚的内容分区、简短标题、突出核心信息 | 班车页首先呈现两方向的下一班，大字号倒计时 |
| [RISD Graphic Design](https://www.risd.edu/academics/graphic-design) | 编辑式字体层级、网格、内容优先 | 左右平行线路、等宽时间、低密度信息 |
| [Apple Icon Composer](https://developer.apple.com/icon-composer/) | 透明前景和背景分层、系统材质、适配图标外观 | 可编辑的 Icon Composer 工程保存在 `docs/design/AppIcon.icon`（Xcode 27 下可编译 Liquid Glass；主工程默认使用 PNG 图标，以便 Xcode 26 构建） |
| [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/) | 系统导航、44pt 触控、语义字体、动态字号、辅助功能 | 原生 Tab / List / Menu / Quick Look / Files，遵循减弱动态效果 |

参考的是排版和信息层级，天蓝／橙色是本项目的独立配色，不声称上述学校使用同一配色。

## 色彩与材质

| 色彩 | 浅色 / 深色 | 用途 |
| --- | --- | --- |
| 天蓝 | #056BAB / #59C2FF | 操作、南→北、主强调；深色提高亮度 |
| 暖橙 | #B54A0F / #FFA85C | 北→南、教学周车次、校门提示 |
| 纸面 | #F2F7FA / #0E141C | 原生页面背景 |
| 表面 | 系统分组背景 | 信息卡、列表，自动跟随系统 |

浅天蓝只用于下载浮窗和图标的底色，文字使用更深的天蓝以保持可读性。
44pt 菜单按钮；22pt 班车卡圆角；20pt 页面边距；SF 系统字体，时间等宽。

## 图标看板

![浅色 Liquid Glass](icon-light.png)
![深色 Liquid Glass](icon-dark.png)
![透明外观](icon-clear.png)

基于用户提供的校徽进行非官方改绘：保留火炬、几何 V、齿轮、花朵；移除印章式外圈和环绕文字，加入轻量制图辅助线。完整方形背景由 Icon Composer 提供，系统负责外部蒙版，没有额外套一层边框或预留一圈空白。分层工程不在编译目标内，见 `docs/design/AppIcon.icon`。

图像素材使用内置 image_gen 生成，透明 PNG 缩放到 1024px 后导入；玻璃、光照和阴影来自 Apple 原生渲染，并非贴在 PNG 里的假玻璃。原始两次提示词见 `image-prompt.txt`。

## 动效

倒计时使用原生 numericText，只有值变化时短过渡。班车内容初次进入淡入并上移 10pt / 350ms；下载面板约 300ms 滑入。系统“减弱动态效果”开启时取消位移与数字滚动。参考 transitions-dev 的数字变化、浮层出现原则，原生 SwiftUI 实现，无循环装饰动画。

## 数据与交互边界

- 班车以用户给出的 2026-10-12 表为唯一来源，共 58 个独立车次；1 号每日，2 号仅教学周指定星期。教学周由用户手动确认；假期、调休及校方临时通知不推断。
- 倒计时为北京时间计划发车，不具备实时 GPS 或预计到站数据；过末班自动显示次日。
- 顶栏仅显示可点击回主页的页面标题与“更多”；前进、后退、刷新保留在更多菜单，网页边缘后退手势保留。
- Moodle PDF 使用原响应进入临时 PDFKit 预览，点击下载后才创建正式文件与记录；其他站点保留下载行为。默认位置可修改且仅影响新文件，已有文件原位保留。
- 下载完成面板 4 秒后以 250ms 渐隐；切标签、预约分类或继续浏览网页时立即收起。面板生命周期与文件保留独立。
- 文件默认永久保存在 App Documents/Downloads，暴露给“文件”；限时保留为显式可选设置。

下载反馈只使用一个面板：主页面和子窗口互斥呈现，不再叠加下载完成 Toast。iOS 26+ 用原生 glassEffect 与 interactive 材质；App 身份卡片位于设置的关于页。

## 班车页验收

![全面屏 iPhone 班车页](shuttle-iphone-final.png)

## 当前卡片交互（1.11）

- 常用入口使用 24pt continuous 圆角，蓝色按行变浅、相邻卡片略有色相变化；白色单色 SF Symbols 和文字保持一致。
- 无上下文菜单的卡片按住缩放至 0.975，松开恢复；不添加会抢占滚动的长按手势。减弱动态效果下关闭缩放及额外过渡。
- 有分享／移除动作的入口使用系统上下文菜单。预览在整个菜单显示期间保持 1.12 等比放大；无障碍字号改为单栏并留出预览空间。以每张卡片真实源宽高重绘后整体缩放，连续圆角半径同步乘 1.12，避免横向拉伸、方角闪烁或仅在触发瞬间放大。
- 系统菜单外的页面增加轻微模糊与变暗，关闭后恢复；不自绘仿系统菜单。
- 下载网格中只有文档缩略图是长按抬起的源轮廓，文件名与整格不抬起。大预览呈现文件内容，菜单保留系统材质。

依据 [Apple Context Menus HIG](https://developer.apple.com/design/human-interface-guidelines/context-menus) 与 [contextMenuPreview 形状接口](https://developer.apple.com/documentation/swiftui/contentshapekinds/contextmenupreview)；具体 12% 比例取自用户提供的捷径截图参考，不宣称是 Apple 规定的常量。


### 1.12: native files, exams and web chrome

- Upcoming exams is a separate card after Moodle upcoming work, with the same spacing, radius and press behavior as the timetable and Moodle cards. Course, session, start time, venue and duration remain distinct; an unknown venue is displayed explicitly.
- Each grid file is a UIKit collection cell. The native context-menu source is its document thumbnail alone; the system owns lifting, backdrop dimming, dismissal and return to that thumbnail. No SwiftUI List row wraps multiple files. PDFs render directly with PDFKit inside the independent context preview to avoid a blank Quick Look cold-start surface; other file types use Quick Look.
- Fixed site titles use the native navigation bar and system typography. Booking scope selection belongs below that bar; refresh and home stay in More. Native large-title collapse changes the content origin, so verification measures window coordinates after scrolling rather than using the initial header position.
- For Student's full-height React root and inner main scroll view, keep page pixels underneath the floating tab bar. Add clearance to the end of scrolling content and the specific Checklist action bar without shortening the website viewport. Reapply the clearance on each new document.

References: [UICollectionView context menu configuration](https://developer.apple.com/documentation/uikit/uicollectionviewdelegate/collectionview(_:contextmenuconfigurationforitemsat:point:)) and [targeted highlight previews](https://developer.apple.com/documentation/uikit/uicollectionviewdelegate/collectionview(_:contextmenuconfiguration:highlightpreviewforitemat:)).

Download grid source thumbnails have 24-point top clearance (16 points more than the initial grid) and a shadow path inset by 6 points. The full 72×88-point paper remains visible. This changes the lift shadow footprint, not page blur strength.
