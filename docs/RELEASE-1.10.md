# GTIIT 1.10 (14)

## Changes

- WebKit hosts reattach the shared portal view when a timetable-import modal releases it. Background SwiftUI updates cannot take the view away from its visible host. This fixes a reproducible blank-view lifecycle defect.
- On iOS 26+, the host supplies WebKit obscured content insets from the actual safe area. Full-screen and nested-scroll layouts extend beneath the native tab bar while fixed page controls remain above it. Existing root-document scroll behavior remains covered.
- Read-only, unedited ordinary GET documents can recover once per minute after a foreground WebKit process termination. Forms, edited documents, POSTs, authentication addresses and one-time query links are not automatically replayed. Recovery is disabled while locked, inactive or clearing data. Manual recovery of unsafe requests returns home rather than resubmitting them. The edit observer transmits only a boolean, never field contents.
- Moodle summaries are protected local Application Support files, excluded from backup. Matching-term summaries younger than seven days restore immediately; relevant dates still filter the displayed items. Automatic updates use a 30-minute interval, and manual refresh is available. Cancelling a scan on backgrounding allows a subsequent retry. Signing out or clearing Moodle website data removes the summary.
- Course scans request Moodle's in-progress classification, then exclude explicit old-term labels, future/past course dates and invisible courses. The current term comes from the bundled academic-calendar semester starts (2026 Winter at this release). Untagged courses can remain eligible when Moodle marks them active. Empty active-course results do not fall back to all courses. At most two assignment-page requests run together. Merely opening an assignment no longer invalidates the cache.
- Cards without context actions use restrained press-to-shrink feedback. Shortcuts use native context menus for sharing website links, removal and management. Source-sized previews avoid the earlier wide enlargement; the page softly blurs and dims while the selected preview and menu remain clear. Dismissing the menu restores the page. Reduced Motion disables the additional animation and shrink.
- Settings → General → Manage Shortcuts enables adding, hiding and restoring entries; changes persist. Removing a shortcut does not change website data. Settings → Timetable now uses the same NavigationStack push hierarchy as peer settings pages; import and local timetable management are inside it.
- Download list and grid context menus include a large system Quick Look preview. The preview reads an independently coordinated temporary copy and releases it with the preview; it does not own or dismiss the full document viewer.
- Privacy text and English translations describe the local summary cache. Fixed the existing aTrust completion-handler Sendable warning.

## Validation and limits

264 isolated regression checks passed, including active-term filtering, empty-course behavior, summary persistence/clearing, backup exclusion, shortcut-preference persistence, fixed-position inner-scroll layout and shared-host handoff/restoration. Simulator does not expose iOS Data Protection attributes; the cache explicitly uses complete file protection, but device protection-class metadata was not separately queried.

The final context-menu blur/dim refinement was visually verified after the core regression pass. System long-press file preview rendered the synthetic PDF; shortcut-menu sharing/removal controls and small preview were inspected; menu dismissal restored sharpness and brightness. Settings → Timetable navigation was exercised in the isolated app. No real-account data is included in screenshots.

Device crash-log inventory did not contain a GTIIT native crash report. The inspected recent memory-pressure event listed GTIIT as suspended without a kill reason. This is not proof that all intermittent crashes are resolved. The reproducible shared-view defect is fixed, and WebKit recovery is defensive. The real student-portal host could not resolve on the Mac's current network, so authenticated portal behavior still needs observation on campus Wi-Fi/VPN; nested/fixed layout regressions use synthetic same-origin fixtures.

Signed Release build succeeded. Installation over the existing app via local-network transport succeeded; the phone inventory confirmed 1.10 (14). No uninstall or data-container reset was performed. Automatic launch was initially denied because the phone was locked.

References: [Apple WKWebView obscuredContentInsets](https://developer.apple.com/documentation/webkit/wkwebview/obscuredcontentinsets), [WebKit: Safari 26 APIs](https://webkit.org/blog/17333/webkit-features-in-safari-26-0/), and the installed UIKit/WebKit SDK declarations.

Follow-up: after the user opened the app on the unlocked phone, the same GTIIT process was observed in two snapshots more than ten seconds apart. This confirms startup survival, not a complete real-account website regression.
