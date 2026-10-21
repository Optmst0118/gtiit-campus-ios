# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

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