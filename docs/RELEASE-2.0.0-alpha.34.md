# 2.0.0-alpha.34 · build 51

## Changes

- Removed unavailable South Campus classrooms 402–409 (both E1 and E2 entries) from the native booking directory; E1-202–205 remain.
- Onboarding page two now offers one sign-in entry for Student, Moodle, room booking and sports. A large bottom sheet presents each existing official web session. Users explicitly confirm sign-in before advancing; checked progress stays when the sheet is closed and reopened during onboarding.
- Completion is a **user confirmation**, not a claim of server-side authentication validation. Loading, failed, unvisited, off-site and authentication-redirect pages disable confirmation. Successful page rendering alone never checks a site automatically.
- After four confirmations, the sheet closes and the onboarding next step becomes available. No passwords or authentication tokens are read by this flow. The same `BrowserModel` / persistent WebKit stores continue in the main tabs.
- Icons and rows appear in reading order with 55 ms staggering; headers fade upward by 10 pt over 320 ms. Reduce Motion removes the offset, stagger and symbol effects. Long onboarding pages scroll while keeping a centered 540 pt content column.
- Native Chinese / English text and standard localization tables updated.

## Verification

- Project consistency and localization checks passed.
- Full isolated regression: **284 checks passed**, including 9 new checks covering unavailable rooms and confirmation eligibility.
- Debug simulator build passed; signed Release device build passed, including the embedded Widget extension and bundle/profile validation.
- Isolated UI review harness compiled and launched with synthetic campus pages. Interactive screenshot verification could not complete: the computer-use service returned `noWindowsAvailable`. Real campus authentication and large-text visual inspection are not claimed as verified.
- The iPhone was disconnected during this delivery. No phone installation or data reset was performed.

Design references: [Apple onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding), [Apple motion](https://developer.apple.com/design/human-interface-guidelines/motion). These inform restraint and accessibility; specific timing values are app choices.
