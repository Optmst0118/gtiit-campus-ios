# GTIIT 1.9 (13)

- Timetable import now uses one modal with sequential portal and review screens. Returning from review allows changing the semester without automatically pushing review again. The leading control says 返回; the trailing blue checkmark explicitly saves after review. Replacing an existing snapshot still requires confirmation, and failures preserve the existing timetable.
- Shortcuts retain the two-column layout and continuous 24-point corners, with subtle blue shadows. Saturated blues become lighter row by row; dark appearance uses deeper blues. Icons and labels use white, and the calendar uses the same monochrome SF Symbols treatment as the other entries. Downloads, Settings, and Help remain grouped rows at the bottom.
- Shuttle direction cards remove the top colored marker. Each card fades vertically from its blue or orange tint into the existing card surface, with a separate dark-appearance opacity.
- Fixed the isolated UI review app missing AppSettings injection in timetable-import previews. This caused the reported UIReview EnvironmentObject assertion; the product root already supplied both dependencies.

Validation: project structure check passed; signed iOS Release build succeeded; 250 existing isolated regression checks passed. Synthetic timetable review and light/dark shortcut screenshots were visually inspected. Full real-account timetable-import interaction was not re-executed in this run. The Release build retains an existing CampusNetworkAccess completion Sendable warning.

Delivery: overlaid the existing app via local-network transport, without uninstalling or clearing its container. Device installation and process launch both returned success, and the installed app inventory confirmed 1.9 (13). No login, download, or timetable data migration was introduced.
