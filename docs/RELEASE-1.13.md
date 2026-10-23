# GTIIT 1.13 (17)

## Changes

- Native website titles no longer follow negative WebKit refresh overscroll. A noninteractive native scroll tracker forwards nonnegative document/inner-scroll progress to UIKit, preserving its large-to-centered compact title transition on Student, Moodle and both booking services.
- The booking content controller explicitly registers its top tracker so the scope selector does not block collapse. Returning a shared web view from a modal rebinds its scroll handler.
- Navigation appearances are white in light mode and the existing dark native canvas in dark mode across large, compact and scroll-edge states, with matching system title contrast. Website content and bottom glass tabs retain their existing appearance.
- Download location, file-count header, margins and continuous 18-point rounded file container share a single layout. Switching view changes only the file arrangement; grid files now have the same rounded background surface as the list. Removed redundant gesture instruction footers.

## Validation and delivery

- Full isolated regression: **285/285 passed**. Includes four website title collapse/pull stability checks, nested Student scroll/return-to-top, modal scroll-handler restoration, bottom glass geometry and existing PDF/download/privacy/calendar/timetable coverage.
- Signed device Release build and project structure checks pass (59 Swift sources).
- Device Hub review confirms white navigation in light mode and the original dark native canvas with readable title/status text in dark mode. Synthetic list/grid screenshots confirm shared location/count/container placement. Pixel comparison is identical for the location-content/count region and both outer file-container edges; toolbar toggle glyphs and native shadows naturally differ.
- **1.13 (17)** overlay-installed on the connected iPhone Air. Device inventory confirms the version; launch succeeded and the same process remained running in a later snapshot. No uninstall, data clear or file migration was performed.
- Test images contain synthetic documents only. No live student records or device identifiers are committed.
