# GTIIT 1.7 (11)

## Changes

- Me shows an **Import from Portal** button while the local timetable is empty. It opens Enrollments using the existing portal session, waits for two matching reads after navigation finishes, and presents the courses, rooms and semester dates for confirmation. An expired session can be signed in on the same screen; extraction then continues. No timetable is replaced without confirmation. Cancelling, locking, backgrounding and the four-minute deadline stop recognition without saving a partial result.
- The calendar UI shows only verified Chinese holidays and Passover breaks from the supplied original PDFs. Holiday dates have system-red dots. Cultural festivals, study dates and makeup dates no longer decorate the month or appear in the holiday list. Underlying teaching and makeup records remain available for the local timetable’s semester and weekday logic. Both original PDFs were visually compared with the holiday dates.
- Each shuttle departure card opens the full timetable with the corresponding direction selected.
- Me now includes an **Upcoming on Moodle** card and a detailed list. The reader combines calendar endpoints with paginated enrolled-course lists, each course’s assignment index and every discovered assignment page. Robotics deadlines absent from Timeline are included. Explicit submitted status removes an assignment from pending work; drafts and unknown status are distinguished. Only explicit opening dates are used; first discovery is never treated as an opening date.
- Downloads’ trailing swipe Delete action explicitly uses dynamic `UIColor.systemRed`, with the system destructive role and existing deletion confirmation.

## Moodle behavior and limits

- The original WebKit login session is reused. Reads run within the Moodle page’s origin, without exporting session keys, account identifiers, raw HTML, grades, submission content or attachments. Summary fields remain in memory, and clearing the Moodle login container clears them. Lock/background stops requests. Visiting an assignment or quiz invalidates the freshness marker so returning to Me can recheck a submission. Login/auth pages clear the summary.
- The card shows deadlines within seven days (including one day of overdue work), openings in the last two days and openings within the next day. It refreshes when Me appears and the summary is older than fifteen minutes, or manually in the detail view.
- The source may omit opening times or make pages unavailable. Unknown status is never presented as confirmed unsubmitted. Failed reads and bounds (100 courses, 240 assignment pages, 50 calendar results, 100-second scan deadline) are surfaced as incomplete results. No assignment form is submitted. Calendar calls honor the school server’s 1–50 result limit.
- Times are interpreted/displayed in Asia/Shanghai, as in the verified school pages. Native Chinese/English labels are supplied without changing the language of wrapped sites.

## Validation

- The complete reader was run read-only in an already authorized Safari Moodle session: 44 enrolled courses, 44 assignment indexes checked, zero read failures, seven items in the scan window; Robotics was found with explicit unsubmitted status. Only aggregate counts are retained here.
- Isolated regression includes pagination, a deadline missing from Timeline, English and Chinese dates, explicit submission status, opening events, deduplication, unsafe URLs, partial failures, login expiry and read-only requests. The initial complete run passed 226 checks.
- Release build signed successfully for iOS. Same-bundle installation of 1.7 (11) and device launch succeeded over the phone’s currently active wired connection; final validation and installation are recorded in `docs/verification/features-1.7.json`.
- No real student data was added to the repository. UI review uses synthetic timetable, PDF and assignment fixtures. Existing phone logins, downloads and local timetable are retained by updating the same bundle.

- Final UI checks confirmed the first north-to-south card tap and the subsequent south-to-north tap select their matching timetable. The sheet uses the direction item as its identity to avoid a stale first presentation. Empty timetable import, the synthetic Moodle card/detail and October 1–7 holiday-only red dots were observed in the independent review app.
- The import waits through login and restores Enrollments when a signed-in SSO callback lands on the portal dashboard. A result received after cancellation or locking is discarded. The existing phone timetable was not re-imported or replaced during verification.
