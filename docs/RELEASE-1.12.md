# GTIIT 1.12 (16)

- Adds a separate upcoming-exams card below Moodle upcoming work, with a native detail screen. Student Dashboard exam rows are read from the exam component's pre-pagination memo only; whitelisted fields are course/code/session/date/time/duration/venue. No profile, grades, credentials or general app store are exported. The current authenticated website reader was checked against all 12 entries, including pagination. Cache is protected, excluded from backup, refreshed after 30 minutes and cleared with portal login data.
- Replaces the SwiftUI List-row-embedded file grid with independent UIKit collection cells. Native context-menu highlight and dismissal previews target only each cell's paper thumbnail; menu preview, actions and commit use the selected file ID. Updates are held while a menu owns the source cell, then applied after restoration. The page background is independent of any file preview.
- Uses stable native large navigation titles: Student, Moodle dashboard, GTIT room booking service and GTIT sports center. Booking scope selection sits below the native navigation bar. Home, refresh and other browser actions remain in More.
- Student uses a height-constrained React root and an independently scrolling main. Its WebKit viewport now extends through the bottom tab bar rather than being shortened by obscured insets; only the internal scroll end receives clearance. Other sites retain WebKit obscured-inset handling. The outer browser host also extends through the bottom safe area.


## Verification

- Full isolated regression: **274/274 checks passed**. Covers exam whitelist, pre-pagination extraction, cache/throttle/clear rules, native titles, PDF/download workflows, and all four web-host frame/last-action boundaries. Student's nested-scroller fixed action receives tab-bar clearance.
- Current authenticated Student reader checked against all 12 exam entries, including records beyond the first page. No actual exam records, grades or profile data are committed.
- Device Hub synthetic review: separate timetable/Moodle/exam cards, readable exam detail, Student content visible under the glass bar, independent South/North PDF previews and restoration. Final press transition recorded and inspected; only one paper lifts. First-row clearance increased by 16 points; native targeted-preview shadow source inset 6 points. Global blur strength and system menu material are unchanged.
- Project structure passes: 59 Swift sources; icon is 1024×1024 without alpha. Signed Release build succeeds, version **1.12 (16)**.
- Automated page-boundary checks cover scroll-end access; Device Hub coordinate scrolling was unavailable, so the visual inspection does not independently claim a manual end-scroll pass. Live Student React fields and layout were inspected separately from the synthetic rendering.

Delivery: 1.12 (16) was overlay-installed on the connected iPhone Air. Device inventory confirms the version and a subsequent process snapshot confirms the launched app remains running with the same process ID. Existing application storage is retained; no uninstall or data reset was performed. Live app exam refresh is network/session-dependent; the authenticated website extractor and protected-cache behavior were verified separately.
