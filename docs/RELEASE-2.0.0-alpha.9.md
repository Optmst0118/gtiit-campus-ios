# 2.0.0-alpha.9 · build 26

Scope: native extension generation/checking/CI, one version source, Live Activity restore/deduplication/expiry handling, reminder preference/scheduling correctness, bilingual system resources, clearer Live Activity layouts and foreground campus proximity suggestions.

Validation:
- Project generator is byte-identical across repeated runs; app has 71 Swift sources, extension has 6. Both targets use version 2.0.0/build 26.
- Full isolated regression: 275 passed. This includes persisted reminder lead/privacy; date/location/permission policy tests separately pass 19 checks. Final English-label/minimal-island refinements affect presentation only.
- Signed device Release passes bundle verification: embedded extension, same build, signatures, application identifiers and provisioning profiles match. App Groups are absent in both signed products; no shared-container success is claimed.
- Campus coordinate provenance: https://www.openstreetmap.org/way/536680356 and https://www.openstreetmap.org/way/1313755916 ; school campus relationship: https://www.gtiit.edu.cn/campus-design.aspx . Cutoff is measured from the nearest centroid; uncertain positions give no recommendation.
- Raw positions are not saved or uploaded. Location authorization, actual in-campus recommendation and system notification delivery require device checks; policy tests do not substitute for those.

Rendered and end-to-end review:
- Shared lock-screen view checked for both directions in Chinese and English; English route wording is kept concise to avoid truncation. Actual Widget extension compact-island rendering checked in the disposable iPhone 17 simulator.
- Actual app flow with simulated WGS84 coordinates confirms south→north suggestion, north→south suggestion and clearing the suggestion outside 5 km. The OS When In Use permission flow was exercised. No physical in-campus GPS accuracy claim is made.
- An actual ActivityKit activity was created, remained discoverable after app termination/relaunch, and could then be ended. Permission grant, five-minute reminder creation and clearing pending test reminders were exercised. Notification firing at a future real departure time and Siri speech recognition were not independently observed.
- Full-screen lock UI automation did not provide an independently inspectable lock-screen state; screenshots of the shared view and actual compact island are retained instead. Expanded/minimal layouts compile in the extension, but manual expansion/minimal-state transitions were not independently verified.
- Device overlay installed as 2.0.0/build 26, with release label 2.0.0-alpha.9; remote launch succeeded. No uninstall or data reset.

UI images use synthetic review departures or the public timetable on a disposable simulator. No personal student information or real device locations are included.
