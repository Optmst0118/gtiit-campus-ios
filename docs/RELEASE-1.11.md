# GTIIT 1.11 (15)

## Long-press corrections

- Shortcut context previews retain a 1.12 scale for the entire time the menu is open, rather than returning to source size after the initial gesture. Width, height, icon, text and continuous corner geometry scale together. Geometry is measured per shortcut so a tall accessibility label cannot stretch another card. Accessibility text sizes use a single column with preview margins to avoid narrow, fragmented labels.
- Both source and preview explicitly define the context-menu outline. The source uses the card’s 24-point continuous rounded rectangle, and the enlarged preview uses its proportionally scaled outline; the preview is clipped to the same shape.
- Download grid items retain their full interaction hit area but use a document-only context-menu source silhouette: the centered 72×88-point thumbnail with 4-point continuous corners. Captions and the grid-cell background are excluded. The independent coordinated Quick Look preview and native menu remain available.
- Existing subtle page defocus/dimming and dismissal restoration are retained. Cards without context-menu actions keep the separate restrained press-to-shrink feedback.

The 12% scale follows the user-provided Shortcuts reference, rather than an Apple-prescribed numeric token. The system still controls menu presentation, accessibility and placement. References: [Apple Context Menus HIG](https://developer.apple.com/design/human-interface-guidelines/context-menus) and [SwiftUI contextMenuPreview shapes](https://developer.apple.com/documentation/swiftui/contentshapekinds/contextmenupreview).

## Documentation and history

README, CHANGELOG, architecture, design rules and the documentation index now cover local changes from 1.6 through 1.11: calendar/holidays, confirmed timetable import, native language selection, Yilong, separate timetable/upcoming cards, portal shared-host and bottom-inset handling, cached current-term Moodle work, file management and shortcut customization. Older release documents remain as historical evidence with their original validation limits.

The existing origin main branch is an ancestor of this work. Synchronization uses a normal Git push of the complete local commit history and the version checkpoints, without rewriting the remote branch. Personal signing configuration, user data and licensed school-calendar PDFs remain excluded by .gitignore; only source, generated app assets, synthetic review screenshots and documentation are published.

## Verification

264 isolated regression checks passed. The context menu was visually checked after holding the gesture and leaving the menu open: enlargement remains, corners retain their continuous proportion, and the selected card remains sharp over the defocused/dimmed page. Download grid long press showed the file page rather than the grid/caption card. Final per-shortcut geometry is additionally checked with English, dark appearance and accessibility text.

The iOS Release build, device delivery, source fingerprints and GitHub synchronization evidence are recorded in docs/verification/features-1.11.json. The existing website-network and intermittent-crash limitations from 1.10 are unchanged; this release does not claim a new full authenticated-site regression.

Delivery: 1.11 (15) was installed as an overlay over the local network, and device inventory confirmed both version fields. After the user unlocked the iPhone, remote launch succeeded and the same app process remained running across two observations more than 10 seconds apart. This confirms startup survival, not a full authenticated website regression. The published source commit `3a44f67` passed the [GitHub simulator build](https://github.com/Optmst0118/gtiit-campus-ios/actions/runs/39804884244); all seven preceding local commits and historical version checkpoints were synchronized.
