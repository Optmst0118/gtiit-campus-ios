# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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