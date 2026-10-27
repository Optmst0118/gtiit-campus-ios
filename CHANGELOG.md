# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.0.4-beta.5 (78) · 2026-10-27

- 我的页通知／设置按钮去除额外内部宽度，沿用预约页的系统工具栏尺寸与间距，保留共享玻璃背景。
- 正常通知中心只呈现实际作业、预约及需要重新登录的消息，不显示空栏目或正常登录检测面板；检测继续后台自动执行。
- 右上角 Beta 菜单提供“显示全部通知项目”开关，跨启动保存，展开完整登录状态与缓存入口，关闭后恢复消息模式。
- 用相同 Unix 时间精度判断作业时间边界，消除 Date 转换的微小精度差导致的边界漏项。

## 2.0.4-beta.4 (77) · 2026-10-27

- 我的顶部通知中心与设置共用原生液态玻璃容器。
- 通知中心汇总 24 小时内截止作业、6 小时内练习房／讨论室预约与校园登录状态；点击直达对应页面。
- 每次启动检查五站现有会话，区别需要登录、网络不可达及无法确认，后台切换与隐私锁取消旧检查。
- 本地缓存 Moodle 全课程目录、Student 课程元数据、近期作业／考试和个人预约；目录跨学期保留，去除旧 7 天缓存丢弃条件。体育预约同步按用户要求暂缓。
- 等待已登录页面的异步课程查询完成再缓存；个人预约成功快照替换旧数据，失败保留。
- 修复门户跨脚本世界初始化顺序导致新手提示偏好偶发被覆盖的问题。

## 2.0.4-beta.3 (76) · 2026-10-27

- 作业提醒增加 24 小时、2 天、5 天、1 周四档，持久化并替换尚未发送的排程，保留已发送去重。
- 班车下一班移至靠上第二行，提供轻柔色底／细描边／时间色块三款审核方案；当天标记只显示“下一班”。
- 服务中心加入常用入口，客户工单表使用原生列表，保留独立认证会话和原网页详情、回复、附件操作。
- 五站数据隔离、清除与配色纳入统一注册；启动登录与预加载仍保留原四站。
- 用户选定 A「柔和底色」，签名验证通过后已覆盖安装。详见发布记录。

## [2.0.4-beta.2 · build 75] - 2026-10-27

### Added

- Automatic local reminders 24 hours before checked, unsubmitted Moodle assignment deadlines. Work first discovered inside the window is notified once on detection; known later deadlines are scheduled with iOS for delivery while the app is closed.
- Protected, persistent deduplication ledger; cancel obsolete reminders after submission, deadline changes, complete-snapshot removal, logout or disable. Partial refreshes preserve reminders for courses not checked. Assignment notifications open the corresponding Moodle task without interfering with shuttle notification routing.
- Assignment reminder preference and notification permission controls under Settings → Learning & Timetable; native Chinese/English text. Foreground summaries continue using the 30-minute refresh interval.

### Changed

- Full shuttle timetable highlights the next valid departure and centers it on open, direction changes and departure rollover. Teaching-week/day eligibility and tomorrow rollover reuse the shared schedule; first and last rows can also reach the viewport center.

## [2.0.4-beta.1 · build 74] - 2026-10-27

### Fixed

- Suppress Student first-run tours with the site's dedicated showcase preferences and dismiss its daily informational account reminder through its existing Continue action. Keep a scoped lightweight observer for late loading and SPA changes; release the site's own blur/interaction lock without altering session, consent or business forms.
- Remove the separate Upcoming Exams status card. Place the last-updated timestamp below the exam schedule section, with relevant login/retry/loading actions inside that section.

## [2.0.3-beta.2 · build 73] - 2026-10-26

### Fixed

- Remove borders, outlines and shadows on the outer official-site page canvases, including Moodle activity wrappers. Preserve interior card/table borders, form controls and actions; apply the same chrome rule in light/dark and portrait/landscape.

## [2.0.3-beta.1 · build 72] - 2026-10-26

### Fixed

- Coordinate collapsed-sidebar and back controls in one persistent Liquid Glass container. Back separates to the right on push and merges on return; deep navigation keeps one pair rather than overlapping native back and floating sidebar controls.
- Share navigation-surface registration across native pages, keep modal stacks independent, preserve web-history/unsaved-form back actions and native interactive pop with a forwarding gesture delegate. Unwrap delegates on page changes to prevent proxy cycles.
- Preserve the existing canvas, session, Tab and expanded-sidebar behavior; use non-morphing system-material controls on older iOS and honor Reduce Motion.

## [2.0.2-beta.2 · build 71] - 2026-10-26

### Fixed

- Remove expanded-sidebar toolbar reservations from Booking and wrapped sites; keep the collapsed reveal reservation outside the selector’s shared glass background and reduce iOS 26 spacing to account for native item margins. Keep booking labels at their intrinsic width.

- Align the collapsed iPhone landscape sidebar reveal button with the trailing native toolbar control; convert the window safe area once to avoid doubling the Dynamic Island inset. iPad and expanded sidebar placement are preserved.

- Extend the native navigation container through the status-bar / Dynamic Island region and remove the separate top canvas overlay. Preserve horizontal safe areas and let the existing system scroll-edge effect cover the full top region without adding material. [Hierarchy evidence and validation](docs/verification/top-canvas/README.md): 385 full regression checks plus four 47-check orientation runs.

- Collapsed sidebar toggle aligns with the 20pt page content margin and reserves a 64pt leading slot before Student/Booking leading controls.
- Expanded sidebar toggle uses the sidebar's leading navigation item instead of a floating control.

## [2.0.2-beta.1 · build 70] - 2026-10-26

### Fixed

- Sidebar toggle moves with state: sidebar leading navigation item when expanded, floating detail control when collapsed; detail leading controls reserve its slot.
- Student toolbar icon presentation and rounded card corners are kept minimal and aligned with Learning/Booking.
- Attendance add control and separator cleanup runs repeatedly while the page settles; Attendance rules is a collapsed rounded card.
- Status bar / Dynamic Island uses the previous solid page canvas; experimental material/glass attempts were removed.
- Assignment extraction prefers the number after Homework/Assignment/HW.

## [2.0.1-beta · build 69] - 2026-10-26

### Fixed

- Attendance cleanup now also recognizes icon-only circular blue add controls and removes separator borders drawn on short wrappers.

## [2.0.1-beta · build 68] - 2026-10-26

### Fixed

- Attendance add control cleanup now runs repeatedly while the page settles, recognizes text/aria/small blue circular controls, clears their separator borders and hides the horizontal rule.
- Attendance rules are discovered more broadly and inserted as a default-collapsed 22pt rounded card.
- Status bar / Dynamic Island uses the previous solid page canvas again; the gray material overlay was removed.

## [2.0.1-beta · build 67] - 2026-10-26

### Fixed

- Attendance page: hide the stray add control and horizontal separator, and replace the long attendance rules block with a default-collapsed, 22pt rounded Attendance rules card.
- The status-bar/Dynamic Island area now gets a subtle glass tint over the page canvas instead of a flat separate plate.

## [2.0.1-beta · build 66] - 2026-10-26

### Fixed

- The page canvas now continues through the status-bar and Dynamic Island area on every tab; no separate navigation plate or material is introduced.
- Student toolbar refresh/more icons use the same SF Symbol presentation as Learning and Booking.
- Student portal card and rounded-container corners are increased to 22pt.
- Numbered assignment extraction prefers the number after Homework/Assignment/HW, avoiding earlier course numbers in the title.

## [2.0.1-beta · build 65] - 2026-10-26

### Fixed

- Sidebar collapse/expand is now one floating control anchored to the physical top-left safe area, including the landscape Dynamic Island inset; the duplicate sidebar navigation button is removed.
- Student native toolbar menu is icon-only and its items use semantic icons instead of trailing chevrons.
- Student web navigation/menu/header chrome is removed more thoroughly while preserving the main page and checklist step bar.
- Every numbered assignment object, including calendar and assignment-detail sources, is normalized to Homework N Assignment; unnumbered assignments keep their official name.

## [2.0.1-beta · build 64] - 2026-10-26

### Changed

- Student portal navigation is exposed in native leading controls while secondary official pages remain in the persistent WebKit session; native refresh and actions align with booking controls.
- iPhone landscape detail content reaches the physical right edge, while the collapsed sidebar control stays at the safe-area top-left corner and the sidebar canvas matches the page theme.
- Homework titles such as `Homework 2` display consistently as `Homework (2) Assignment` without mutating cached source names.
- Security-scoped download folders no longer reject lazily materialized cloud-provider directories such as OneDrive.
- Re-selecting a primary native page scrolls to its top with the shuttle page's 0.3s ease-in-out animation and Reduce Motion support; navigation stacks reset only when returning from a secondary route.
- Re-selecting an official site's home scrolls the current page rather than reloading it, including Student's nested main scroller.
- Use a native UISplitViewController and system sidebar List in wide/landscape layouts, retaining the same TabView/page instances through rotation. The system owns materials, selection and sidebar controls.
- Run calendar/course-directory work concurrently and raise course/detail workers to six under one global six-request budget, with cancellation and timeouts. Publish a token-scoped course-directory preview before assignment checks finish; retain final cache updates and authoritative assignment dates.
- Unify the split-view canvas and safe areas with the light/dark page theme; adapt iPadOS navigation to available window width. Match the iPhone landscape leading inset to the sidebar base, with native collapse and glass reveal controls.
- Rename the weekly timetable action to Today / 回到今天.

## [2.0.1-beta · build 61] - 2026-10-26

### Fixed

- Hide native navigation in landscape for Student home and native Student detail routes; restore it in portrait without recreating WebKit or reloading the page.
- Strengthen Sunday/Monday resistance in both directions: half-speed initial travel and a 60% physical-drag threshold. Measure the finger directly instead of accumulating the modified content offset; velocity or repeated short flicks cannot bypass the boundary.

## [2.0.1-beta · build 60] - 2026-10-26

### Fixed

- Restore system-owned scroll-edge navigation materials, using the same canvas at rest throughout native pages, including Language, Yilong, Help and reminder settings.
- Match Student's nested dark canvas to the native surface, including late styles and light/dark changes, without changing business controls.
- Commit timetable selection/haptics at the release target instead of waiting for deceleration; remove implicit cell/highlight fades and persistent highlighting on today's unselected card.
- Keep timetable times on one line with a wider column, tightening/scaling and an accessible-size layout; keep Dynamic Island departure text on one line.
- Verify 338 regression checks, isolated visual checks and Release signing. Cover-install build 60 on iPhone and confirm launch.

## [2.0.1-beta · build 59] - 2026-10-26

### Fixed

- Normalize the oversized app emblem to 800px visible height on a 1024px canvas, center its visible bounds and keep equal 112px vertical clearance. Synchronize native Icon Composer, light/dark fallback and About assets from an immutable source.
- Confirm Release/device and Debug/simulator builds, install build 59 over the existing iPhone app and verify successful launch.

## [2.0.1-beta] - 2026-10-26

### Changed

- Clean the GTIIT icon foreground and ship sky-blue/light and navy/dark appearances with Icon Composer assets and legacy fallbacks.
- Fit five daily classes in a full-screen portrait timetable, retaining time, course and room; reuse native collection cells instead of creating the whole date range, and reduce week-boundary drag resistance.
- Use native collection drag/drop and context menus for shortcuts, matching the continuous corner outline without a separately enlarged preview; edit and remove shortcuts inline.
- Persist the visibility and order of all My-page sections in General → Manage My sections, independently of shortcut selection and order.
- Rename upcoming Moodle work to Upcoming assignments and move the update time below the work section, removing the permanent status card.
- Add refresh and More controls to room/sports booking and embedded detail pages, and standardize native navigation surfaces in both appearances.
- Complete new English labels and add accessible shortcut reordering actions.

## [2.0.0-alpha.40] - 2026-10-24

### Changed

- Morph the PDF download button and saved actions within one persistent Liquid Glass surface, with a trailing anchor and Reduce Motion fallback.
- Add a persistent calendar exam-visibility option using Student's cached, complete pre-pagination exam list, including midterms and finals, with day markers, time and venue.
- Replace seven-day fling jumps with adjacent-day snapping and travel-based resistance at Sunday/Monday boundaries; shorten settling, trigger haptics at snap acceptance, and fade carousel edges.

## [2.0.0-alpha.39] - 2026-10-24

### Changed

- Use month-only menu labels and a single selection checkmark; page through calendar months with native horizontal swipes and animated arrows.
- Center timetable day cards with snapping, selection haptics and stronger whole-card highlighting; faster flings advance seven days.
- Expand the saved PDF control into a horizontal glass action bar with share and Files-location actions, retaining the permanent saved-file URL separately from the temporary preview.

## [2.0.0-alpha.38] - 2026-10-24

### Changed

- Replace month-calendar event dots with translucent red date backgrounds, regularize inset and grid spacing, and mark weekends and source-derived semester gaps.
- Align Live Activity dates and countdown text to the trailing edge in Lock Screen and Dynamic Island layouts; add a compact directional bus-track illustration.

## [2.0.0-alpha.37] - 2026-10-24

### Changed

- Delete downloaded files directly from the list swipe action and list/grid context menus without a second confirmation.
- Apply the native Moodle chrome and canvas to activity routes as well as courses, including assignment and submission pages, preserving activity controls and login navigation.

## [2.0.0-alpha.36] - 2026-10-24

### Fixed

- Remove the extra tap recognizer from card labels so learning and booking cards retain native button activation; trigger haptics in their actions.
- Preserve calendar opening dates when assignment detail pages omit them.
- Clear in-memory Moodle courses with session data; protect session restoration from stale async callbacks.
- Route summaries, shortcuts and cross-site links into visible native detail pages; preserve web entry points and confirm leaving edited pages.
- Respect the 30-minute summary TTL on ordinary back navigation and add failed-request backoff.
- Make the complete PDF glass surface respond to press/release, including Reduce Motion/Transparency fallbacks.

### Changed

- Keep simultaneous four-site preloading; start summary probes after prewarming settles.
- Reuse course directory and settled assignment details for six hours; prioritize timetable and followed courses while keeping other active-course checks.
- Compact Me summaries, move other courses/tools to secondary pages, add course following and Learning & timetable settings.
- Tune stronger, distinct haptics with duplicate-event suppression and no feedback on cancelled scroll presses.
- Add configurable Widget directions/service calendar and precomputed departure timeline nodes.
- Add local aggregate diagnostics and full integrated regression to CI; support neutral public project generation.

## [2.0.0-alpha.34] - 2026-10-24

### Added

- First-launch sign-in hub on onboarding page two: open each official site in a bottom sheet, explicitly confirm sign-in, and continue to the next site with checked progress. Reuses the main tabs' WebKit sessions.
- Sequential icon/row fades and a subtle upward title reveal, with Reduce Motion support and scrolling for larger text.

### Fixed

- Prevent continuing past the sign-in step until all four confirmations are complete; failed, loading and authentication redirect pages cannot be confirmed.
- Add regression coverage for unavailable South Campus classrooms 402–409 and sign-in confirmation readiness.

## [2.0.0-alpha.33] - 2026-10-24

### Changed

- Removed the unavailable South Campus classrooms 402 / 403 / 404 / 405 / 407 / E2-407 / E2-408 / E2-409 from the room directory.

## [2.0.0-alpha.32] - 2026-10-24

### Changed

- Welcome content is now vertically centered with a 540pt centered column, larger header icon, 28pt section spacing, roomier cards and footer padding.
- Welcome page transitions now include haptic feedback (selection), with a success haptic on completion.
- Student portal web pages use the same light/dark canvas as Learning, including the React root and nested main scroller.

### Fixed

- Numeric course codes are preferred when matching Moodle courses to the imported timetable, so Creative Introduction-type courses land in Current courses.

## [2.0.0-alpha.31] - 2026-10-24

### Fixed

- Creative Introduction and similar current-term courses now match their timetable entry by the numeric course code extracted from the Moodle name, not only by shortname/name.
- Student portal pages now receive the same light/dark page background as Learning; title bar and nested page share the app canvas.
- Welcome pages use a wider, more even content column with larger top spacing, icon sizing and footer padding.
- Welcome Next/Back/Skip page changes and final completion now use haptic feedback.

### Changed

- Course-number extraction now prefers an all-numeric code and ignores term slugs such as 2026Winter.

## [2.0.0-alpha.30] - 2026-10-24

### Added

- Haptic feedback infrastructure and a Settings toggle, with light feedback on card press, selection feedback on tabs and booking categories, success feedback on unlock, and light feedback on pull-to-refresh.
- Non-blocking WebPrewarmHost: all four shell WebViews are created in the window behind the UI at launch, so Student, Moodle, booking and sports pages warm in parallel without a blocking launch screen.
- Moodle/Exam summaries start earlier (250ms / +200ms).
- docs/HAPTICS.md.

### Fixed

- Booking official pages now match the app page background in light/dark mode.
- Pushed booking web pages no longer use WKWebView back/forward gestures, so edge back returns to the native booking page.

## [2.0.0-alpha.29] - 2026-10-24

### Fixed

- Booking official pages now paint their canvas with the app page background in light and dark mode, using the same page-container approach as the Moodle course pages.
- Booking page background follows any light/dark appearance change while the page is open.

## [2.0.0-alpha.28] - 2026-10-24

### Added

- Cached Moodle sessions now auto-click the existing Office 365 SAML link when the Moodle login page appears. The helper never reads or fills an email/password form and never attempts to bypass MFA.
- Auto-login starts in the background when Moodle has stored session data, and also starts when the Learning tab opens. If the app is locked during the background attempt, it retries after unlock.

## [2.0.0-alpha.27] - 2026-10-24

### Added

- Native localization regression check (Tools/check_localization.py) in CI, covering 649 L10n keys, 52 format keys, 748 .strings keys and both InfoPlist usage strings.
- Face ID usage description localization (InfoPlist.strings) and widget configuration strings.
- Shared NativePageIcon / NativeWebPageView components; booking now uses the same push navigation and loading chrome as Moodle.
- Staged, startup-tab-aware WebKit warming with a 700ms summary slot, delayed exam probe, low-power skip and a fixed Moodle summary startup race.
- docs/PERFORMANCE.md and docs/LOCALIZATION.md.

### Fixed

- Room names now show a clean room code with a localized description instead of a Chinese parenthetical in the name.
- User-facing dates and durations follow the in-app language.

## [2.0.0-alpha.26] - 2026-10-24

### Changed

- Removed the remaining tinted rounded container from the learning and booking headers; only the icon tile remains.
- Aligned the icon tile with the standard 20pt page content margin in both tabs.

## [2.0.0-alpha.25] - 2026-10-24

### Changed

- Learning and booking top gradient cards now keep only their icon; eyebrow, alpha badge, title, subtitle and descriptive copy are removed.
- The cards are compact icon-only surfaces, reducing vertical space at the top of both tabs.

## [2.0.0-alpha.24] - 2026-10-23

### Fixed

- Course detail pages now really use inline navigation titles only. The previous build still carried the large-title display mode, which caused the title transition/jump the user saw.
- Removed course-page scroll and navigation title resets; the web page now loads without extra title/scroll manipulation.

## [2.0.0-alpha.23] - 2026-10-23

### Changed

- Course detail pages now use only the inline navigation title; the large-title mode is removed to eliminate the entry jump between title styles.

## [2.0.0-alpha.22] - 2026-10-23

### Fixed

- Course-number badge now extracts only the short alphanumeric course code; it never falls back to a full course name.
- Badge typography and padding are smaller to match the gray term line.

## [2.0.0-alpha.21] - 2026-10-23

### Changed

- Current-course cards now show only the course name; the term remains in the gray subtitle.
- The course number is shown as a small tinted rounded badge to the left of the term.
- Course pages use the cleaned course name in the large title.

### Fixed

- Force the course-page navigation host into the large-title state before first appearance and reset the WebKit scroll offset, fixing the entry jump to a centered title.

## [2.0.0-alpha.20] - 2026-10-23

### Fixed

- Course-page web content now uses the same page background as the app in light and dark mode, instead of a white Moodle canvas.
- Course pages reset their native scroll offset when pushed, so they start with the large left title rather than an inline collapsed title.

### Changed

- Course web chrome CSS now also paints Moodle page containers with the app background colour.

## [2.0.0-alpha.19] - 2026-10-23

### Changed

- “其他课程” is now one flat course module without per-category subtitles.
- Course detail pages use the native large navigation title: large and left-aligned at the top, collapsing to the centered inline title while the course content scrolls.

## [2.0.0-alpha.18] - 2026-10-23

### Changed

- Course detail pages now show the native course name followed by the official course content, with Moodle site chrome (navbar, drawer, breadcrumb, page header, footer) hidden.
- Pushed Moodle pages disable WKWebView history gestures, so a back swipe pops the native page instead of moving through web history.

## [2.0.0-alpha.17] - 2026-10-23

### Changed

- Moodle cards now use native navigation push (right-to-left page transition), not a bottom sheet.
- Course cards push a native course page that shows only the course name; no web title bar or Moodle chrome.
- Assignment, calendar and tool cards push a native web page with a standard back button instead of presenting a sheet.
- History remains a pushed native page; course cards inside it push the same name-only course page.

## [2.0.0-alpha.16] - 2026-10-23

### Added

- Native 历史课程 destination: a second-level page with all non-current Moodle courses as cards grouped by term, based on the complete Moodle course list.
- The history entry shows the archived course count and no longer opens the raw Moodle list.

### Changed

- Moodle history fetches the complete course archive (all classifications) instead of only the current-term course list.
- Course history cards open the exact official course page; the toolbar opens the Moodle personal home.

## [2.0.0-alpha.15] - 2026-10-23

### Added

- Timetable-aware current course filtering: 当前课程 now shows only current-term Moodle courses matched to the imported timetable.
- “其他课程” module groups current-term Moodle courses that are not on the timetable by Moodle category (e.g. Career Services and service spaces).
- Moodle course cards now receive shortname and category metadata for matching and grouping.

### Changed

- 历史课程 remains a single entry to the Moodle personal home page; historical course cards are not rendered on the native home.
- Moodle layout defaults now include 当前课程, 临近日程, 其他课程, 历史课程 and Moodle 工具; 当前课程 stays first.

## [2.0.0-alpha.14] - 2026-10-23

### Changed

- 历史课程 is now a single entry that opens the Moodle personal home page; the history course cards under the home section are removed.
- Current courses stay first; history remains available as a separate destination for the full course archive.

## [2.0.0-alpha.13] - 2026-10-23

### Changed

- Split Moodle courses into 当前课程 and 历史课程 modules; current-term Winter 2026 courses are first, all other terms are grouped under history.
- Removed the three summary cards from the Moodle header.
- Course cards now open their exact course/view.php?id= page, and historical courses are grouped by term.
- Moodle section layout is fixed so 当前课程 is always the first module; 临近日程, 历史课程 and Moodle 工具 can be reordered or hidden.
- Courses without an explicit term label are treated as current when their Moodle start/end dates indicate an active current course.
- Removed remaining defensive captions from the Moodle surface.

### Fixed

- Winter 2026 courses with stale Moodle end dates are retained and classified by their explicit term label.

## [2.0.0-alpha.12] - 2026-10-23

### Fixed

- Moodle course list now includes explicit terms from the current year onward (Winter 2026, Spring 2027 and later), instead of only courses that had an upcoming assignment.
- Course cards open the exact course/view.php?id= URL rather than returning to the dashboard.
- Explicit term labels are trusted over stale Moodle end dates, so Winter 2026 courses with old end dates remain visible.
- Removed defensive captions from the Moodle native surface.

### Added

- Moodle layout editor: reorder or hide 临近日程, 课程 and Moodle 工具, with a default-layout reset.
- Moodle course cards are grouped by term and sorted chronologically (Winter before Spring before Summer).

## [2.0.0-alpha.11] - 2026-10-23

### Added

- Native Moodle workspace: one dashboard for upcoming work, course groups and every official Moodle tool, with an alpha badge and an optional classic-web switch in Settings.
- Moodle tool directory covering My courses, timeline, calendar/export, grades, messages, notifications, school timetable, profile, preferences, site home and search.
- Adaptive Moodle layout: compact single-column on iPhone, max-width adaptive grid and three-column stats on iPad; Dynamic Type and dark-mode colours throughout.
- docs/MOODLE-NATIVE-SPEC.md with the control inventory, native mapping, data states, constraints and acceptance checklist.

### Changed

- Quick links to Moodle now open the native dashboard and present the requested official page in an in-app sheet.
- Closing that sheet refreshes the cached Moodle summary so a fresh sign-in is reflected without leaving the tab.

## [2.0.0-alpha.10] - 2026-10-23

### Added

- Optional school-email prefill on the Microsoft sign-in page; the email is stored in settings, the password is never stored or submitted.
- Location-aware Home Screen Widget for the next shuttle. It refreshes its timeline about every 10 minutes, reads the widget/extended location authorization and picks the return direction from the nearest campus.
- New four-page swipe onboarding with animated icons, feature explanations and the privacy boundary confirmation.
- Equal-height departure cards so both directions end on the same baseline.

### Changed

- The widget extension now contains both the Live Activity and the Shuttle Home Widget.

## [2.0.0-alpha.9] - 2026-10-23

### Changed

- Generate the Widget target, dependency, embed phase and bilingual system resources in Python; align both target versions through version.json (build 26). Check both targets and validate unsigned/signed bundle structure separately.
- Rebuild Live Activity layouts with clear campus direction, departure metadata and aligned countdown; restore, deduplicate and reconcile activities on foreground/settings changes, observe termination and handle request failures.
- Add foreground-only campus proximity recommendations with a 5 km cutoff, accuracy/age/ambiguity checks and no location persistence.
- Persist reminder lead time and privacy, use the same preference in Siri, pin notification triggers to the campus calendar and reconcile invalid requests after teaching-week changes.
- Remove redundant shuttle/reminder explanatory footers; add bilingual system localization and date/location/permission boundary tests.

## [2.0.0-alpha.8] - 2026-10-23

### Added

- Live Activity countdown for the next shuttle, with Lock Screen and Dynamic Island presentation in a widget extension.
- Local shuttle reminders with notification categories/actions, permission onboarding, lead-time selection and a deep link back to the Shuttle tab.
- Siri App Shortcut to create a shuttle reminder for the next north/south campus bus.
- App Group sharing for teaching-week, language and preferred shuttle direction.
- ShuttleSchedule is compiled into the app, widget extension and intents/notification code from the same source file.

### Infrastructure

- Added a WidgetKit extension target, app/extension entitlements and a gtiit://shuttle URL scheme.
- The App Group defaults/entitlement scaffolding is present, but this team provision profile does not yet include the group; signing currently omits that entitlement so device builds stay installable. The Live Activity carries its own state and does not depend on the group.
- Added Live Activity support and notification categories to the app target.

## [2.0.0-alpha.7] - 2026-10-23

### Added

- Siri / Shortcuts support for the shuttle countdown. The “north campus shuttle” and “south campus shuttle” App Shortcuts return the next planned departure countdown from the same timetable used in the app.
- Storage settings now show the app's total on-disk footprint (bundle plus sandbox container) alongside downloads.

### Changed

- Renamed the booking directory groups to 南校区学生中心, 北校区讨论室 and 南校区教室; the South Campus classroom group now uses a classroom icon.
- Completed the native English localization audit: every L10n key used by the app now has an English translation, and booking directories rebuild their localized text when the language changes.

## [2.0.0-alpha.6] - 2026-10-23

### Changed

- Removed defensive copy and redundant notes from the native booking screens: long disclaimers under the room/venue headers, the practice-room rules card, booking footers and the category-detail footnote are gone. The room directory now shows only the remaining categories and their room counts.

## [2.0.0-alpha.5] - 2026-10-23

### Changed

- Removed the Teaching classrooms and Meeting/multipurpose room categories from the native room directory; they were not usable for the intended student bookings. Practice rooms, Student Hub, main-campus discussion rooms, Student-Centre discussion rooms and activity rooms remain.

## [2.0.0-alpha.4] - 2026-10-23

### Changed

- Rebuilt the room directory from Booked's actual public schedules and resource mapping. It now groups all 85 student-relevant rooms by use: practice rooms, Student Hub, main-campus discussion rooms, Student-Centre discussion rooms, teaching rooms, meeting/multipurpose rooms and activity rooms.
- Opening a category shows its full room list; each room opens its own Booked reservation form (reservation.php?rid=...). Hotel guest rooms and the two test rooms are intentionally excluded.
- Validated all 85 generated reservation URLs: every one returns Booked's login redirect while preserving the exact resource id.

## [2.0.0-alpha.3] - 2026-10-23

### Fixed

- Room directory rows now open Booked resource reservation forms, matching the practice room: Student Hub Room 1 (rid=84), SC E1-402 discussion room (rid=128), E101 classroom (rid=48), A218 meeting room (rid=19) and D5-101-3 activity room (rid=81). The classroom/meeting row presents both choices natively.

### Added

- Settings → 网页浏览 now has a "新版预约界面（Alpha）" switch. Turning it off restores the previous wrapped web booking experience; turning it back on returns to the native alpha screens.

## [2.0.0-alpha.2] - 2026-10-23

### Fixed

- The native room directory now uses Booked's numeric schedule links (view-calendar.php?sid=10/11/3/2/9), so Student Hub, discussion rooms, classrooms, meeting rooms and student activity rooms open the correct schedule instead of the generic All Reservations calendar.
- 教室与会议室 opens a native choice for Classrooms or Meeting rooms, preserving both official schedules.

## [2.0.0-alpha.1] - 2026-10-23

### Added

- Alpha native redesign of the Booking tab. GTIT Room Booking and GTIT Sports Center now open as SwiftUI screens instead of the raw web pages, with native cards, grouped directory rows, opening hours, practice-room rules, membership actions, Dynamic Type, dark-mode colours and VoiceOver labels.
- The native screens expose every booking action as an in-app official-page sheet. No API, page scraping or booking submission was added; final sign-in, availability, booking, cancellation and check-in remain on the school pages.

### Changed

- Room-booking and sports shortcuts now route to the native screen and present the exact official deep link in a sheet instead of loading a hidden background WebView.
- The Booking tab keeps its Liquid Glass venue switch in the leading toolbar. This is the first alpha of the 2.0 line; the stable 1.x line remains unchanged.

## [1.17] - 2026-10-23

### Changed

- Moodle dashboard removes the "Customise this page" card and collapses the empty region above Recent accessed courses.
- Added a final 邮箱助手 shortcut that opens the Outlook app (falling back to Outlook on the web).
- 选课与周课表 is hidden from the default shortcuts; existing installs migrate once and can re-add it from shortcut settings.

## [1.16] - 2026-10-23

### Fixed

- Moodle's own navigation is no longer pinned/sticky: it returns to the page flow and scrolls away with the content, so it cannot fight the native title. The native Moodle dashboard title keeps its movable large and compact forms.
- Student portal privacy cards keep their border, radius and shadow sharp; only the card contents are blurred, and tapping the card reveals them.
- Moodle upcoming work and Student exams start loading together with app launch, so My shows running progress instead of starting from idle.

## [1.15] - 2026-10-23

### Fixed

- Moodle's own site navigation (drawer control, user menu, calendar, messages) is pinned to the top of the wrapped page while the page scrolls; the native Moodle dashboard title keeps its movable large and compact forms.
- The Student portal's four privacy cards (Overall GPA, success rate, accumulated credits, cohort rank) now reliably blur by default and reveal on tap, including cards rendered after the first paint.
- Student portal title scrolling tracks any real inner scroller, so its large title collapses and expands with the same animation as the booking sites.

## [1.14] - 2026-10-23

### Fixed

- Navigation bars no longer force an opaque white/dark plate over the page. The top state is transparent (the page background shows through) and the scrolled state uses the system material, restoring the title bar background on My, Settings and every wrapped site.
- Returning a wrapped site to the top now re-expands the large left-aligned title again, including when scrolling back, reopening home or re-tapping the current tab. The large/compact transition keeps the native animation, with an iOS 26 guard for the scroll-edge appearance slot.
- The booking navigation titles are now **GTIIT Room Booking** and **GTIIT Sports Center**.
- Re-tapping the currently selected tab returns wrapped sites to their home URL (and animates the title back); Shuttle and My scroll to the top. Tapping a different tab keeps normal switching.
- Booking's room/sports switch moved from the page content to a Liquid Glass menu button at the leading edge of the navigation bar, so it no longer overlaps the wrapped page.
- Moodle keeps a fixed compact native title bar above the page, preventing its own sticky menu bar from colliding with a collapsing large title.
- Student portal's Overall GPA, success rate, accumulated credits and cohort rank cards are blurred by default and reveal on tap.

## [1.13] - 2026-10-23

### Fixed

- Native website titles share a clamped navigation scroll tracker: pull-to-refresh cannot stretch or move the large title; document and full-height inner scrollers drive the same native large/compact transition. Booking navigation explicitly registers its top tracker above the separate scope selector.
- Navigation surfaces use an white appearance in light mode and the existing dark native canvas in dark mode for large, compact and scroll-edge states, with matching title contrast.
- Downloads share one location row, file-count header and rounded file container. List/grid switching replaces only the file arrangement, preserving icons, margins, corner radius and container frame. Removed redundant swipe/preview instruction footers.

## [1.12] - 2026-10-23

### Added

- Separate upcoming-exams card and native detail screen, reading the Student exam component's complete current-semester list. Protected local summaries refresh every 30 minutes and clear with Student sign-out or website-data deletion.

### Fixed

- Rebuilt download grids with independent UIKit collection cells. Native lift/restore targets only the selected paper thumbnail, with deferred cell updates, 16-point extra top clearance and a 6-point inset shadow source. Background defocus remains unchanged.
- PDF context-menu previews use PDFKit and an independent coordinated temporary copy, avoiding Quick Look helper startup delays; other document types retain Quick Look.
- Student's independently scrolling viewport extends behind the glass tab bar, with clearance for its last content/action rather than a shortened viewport.
- Four website tabs use stable native navigation titles and standard navigation bars; booking scope selection sits below the bar.

## [1.11] - 2026-10-22

### Fixed

- Shortcut previews remain proportionally enlarged by 12% for the complete context-menu lifetime; the source and preview explicitly use matching continuous rounded silhouettes.
- Download grid context-menu lift silhouettes include only the document thumbnail, excluding the filename and full grid cell. The coordinated large file preview remains available.
- README, architecture, design notes, document index and changelog now describe all local changes through this version, including releases that had not yet reached the remote branch.

## [1.10] - 2026-10-22

### Added

- Protected on-device Moodle summaries, 30-minute automatic refresh, current-term active-course selection and manual refresh. Moodle sign-out/data clearing removes the summary.
- Persistent shortcut add/hide/restore controls in Settings → General, native share/remove context menus, document context previews, and subtle background blur/dim.
- Settings → Timetable uses standard push navigation with local import, viewing and deletion inside.

### Fixed

- Shared WebKit host handoff/restoration on portal timetable import, iOS 26 obscured-inset handling for fixed/inner-scroll pages, and guarded read-only process recovery. No automatic form/POST replay.

## [1.9] - 2026-10-22

- One modal with portal → review navigation for timetable import; top-right blue checkmark saves, with explicit replacement confirmation.
- Saturated blue shortcut gradients and consistent calendar symbol; blue/orange vertical fade backgrounds on shuttle direction cards.
- Fixed missing settings dependency in the isolated review harness.

## [1.8] - 2026-10-22

- Web content extends beneath native tabs; dark canvases use the same #0E141C background as Me.
- Separate timetable and Moodle cards, two-column shortcut grid, and bottom grouped Downloads/Settings/Help rows.
- Campus Wi-Fi/aTrust recovery guidance for all four website error states.

## [1.7] - 2026-10-22

- Automatic portal timetable recognition followed by explicit confirmation; source-backed holidays and direction-specific shuttle timetable links.
- Moodle upcoming items combine calendar events with per-course assignment pages to find deadlines missing from Timeline.

## [1.6] - 2026-10-22

### Added

- Source-backed academic calendar in Me, with year selection, upcoming events, native month decorations, source PDF viewing and explicit unverified source dates.
- User-initiated registered timetable extraction from the portal Enrollments page. Review validity dates before local protected storage; today/next-class card and weekly view include rooms. Verified calendar holidays and makeup weekdays are applied within the confirmed validity range.
- Persistent Chinese / English native interface selection without reloading website sessions.
- Six-tap About easter egg unlocking Yilong. Three transparent views use bounded SpriteKit collisions and squash/stretch; dismiss, background/lock cleanup and Reduce Motion support.
- About retains the existing CampusMark redrawn icon. Isolated visual-review builds now include that asset and report 1.6 (10).


### Changed

- Wrapped pages hide school/tenant logos (including the Microsoft sign-in banner and
  Booked's navigation/login logos), the sports-centre hero image and title, and the
  Moodle Course overview filter row. The portal's white Tailwind gradient is removed
  so the page background follows the app's light/dark appearance; menus, notification
  and error bars are untouched.
- Wrapped pages now hide the sites' own footers, copyright lines and "Powered by"
  branding with an always-on injected stylesheet plus a small runtime cleanup. The
  Booked "© 2020 Twinkle Toes Software / Booked Scheduler" strip, Moodle's page footer
  and similar blocks no longer show, so pages read as part of the app.
- The welcome hero is a rounded gradient card again instead of a full-bleed square
  gradient.
- Web shell scrolling: pinch and double-tap zoom are disabled in all four site tabs;
  pages now only scroll vertically.
- The site "more" menu is now a native SwiftUI Menu, so iOS 26 renders it with the
  system Liquid Glass material. The four icon-only navigation shortcuts were removed:
  native menus present control groups as submenus, so they cannot sit side by side.
  Back/forward remain available with the edge-swipe gesture, refresh with pull-to-refresh,
  and home by tapping the page title. Share, Safari and clear-site-data entries were
  removed, and the per-site appearance switch is renamed "暗色适配" with a moon icon.
- Downloads management now matches the rest of Settings: the download location is a
  separate rounded card, files live in one grouped card with hairline separators, and
  list rows support trailing swipe-to-delete.
- Dark mode on the student portal: Tailwind header/background gradients are overridden
  to black instead of staying white.

## [1.5.0-beta.1] - 2026-10-22

First public snapshot.

### Added

- Optional web dark appearance for the four campus hosts, implemented with Dark Reader
  (MIT) inside an isolated `WKContentWorld`; page JavaScript prototypes and business
  events are not modified.
- Public repository scaffolding: README, MIT license, third-party notices, contribution
  guide, code of conduct, security policy, issue/PR templates, CI workflow and changelog.
- `Tools/signing.env.example` for local signing configuration.

### Changed

- Removed personal development-team and device identifiers from the public tree.
- Documentation paths are repository-relative; no machine-specific absolute paths.

## [1.4.0] - 2026-10-21

### Added

- PDF preview before saving for Moodle attachments; saving is explicit via a 48 pt
  glass button, and unsaved previews are cleaned up.
- Compact download manager with list/grid views, sorting, long-press actions, and
  retention policies (forever / next launch / 1 day / 7 days).
- Configurable download location through the system file picker (local, iCloud Drive,
  third-party providers) with security-scoped bookmarks.
- Download progress, cancellation, resume where the server supports it, and duplicate
  file numbering.

### Changed

- Download list and default location are separated from the download index; existing
  files are not migrated when the location changes.

## [1.3.0] - 2026-10-21

### Added

- Cold-launch preload of the four campus sites with session reuse; capped at 10 seconds
  and can be disabled in settings.

### Changed

- Simplified the booking header.

## [1.2.0] - 2026-10-21

### Added

- Native shuttle tab: south→north / north→south columns, next departures, countdown,
  following departures and the full timetable (58 trips, 2026-10-12 source table).
- Unified PDF download flow and native campus visual design.

### Changed

- Browser chrome reduced to a tappable title and a "more" menu; refresh moved into the
  menu, back/forward remain available there.

## [1.1.0] - 2026-10-21

### Added

- Independent review fixes: cross-site routing only for user-initiated GET links,
  real popup windows with `opener`/`postMessage`, separated cache/login clearing,
  privacy shield over modal sheets, and network diagnostics.
- Expanded settings with eight groups, appearance, storage, downloads and help.
- App lock with immediate/1/5-minute policies using `deviceOwnerAuthentication`.

### Fixed

- Stopped showing a misleading lock icon for pages that are not secure.
- Clearing website data now blanks old documents and replaces the WebKit data store
  instead of leaving stale history.

## [1.0.0] - 2026-10-21

### Added

- Baseline: SwiftUI + WKWebView shell with four campus sites, per-site persistent
  `WKWebsiteDataStore`, five-tab navigation, downloads and the first privacy boundaries.