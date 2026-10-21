# Support

GTIIT Campus Assistant is an **unofficial, student-built** iOS client. It is not
affiliated with, endorsed by, or supported by GTIIT, and it is maintained by one
student in their spare time.

This page explains where to ask, what to include, and which problems are expected
limitations rather than bugs.

## Before you ask

Please check, in this order:

1. The [README](README.md), especially **Known limitations**.
2. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the web shells, per-site
   storage, downloads, and app lock work.
3. The latest release notes under [docs/](docs/).
4. Existing [issues](https://github.com/Optmst0118/gtiit-campus-ios/issues) and
   [discussions](https://github.com/Optmst0118/gtiit-campus-ios/discussions).
5. For a website problem, open the same page in Safari. If it also fails there, the
   problem is on the school side, not in the app.

## Where to get help

| I need to... | Go to |
| --- | --- |
| Ask a question, get setup help, or discuss an idea | [Discussions](https://github.com/Optmst0118/gtiit-campus-ios/discussions) |
| Report a reproducible bug | [Bug report form](https://github.com/Optmst0118/gtiit-campus-ios/issues/new?template=bug_report.yml) |
| Request a feature | [Feature request form](https://github.com/Optmst0118/gtiit-campus-ios/issues/new?template=feature_request.yml) |
| Report a security or privacy problem | Privately, via [SECURITY.md](SECURITY.md) — never a public issue |
| Fix a problem with your school account, enrollment, grades, or room booking | Contact the relevant GTIIT office or IT support |

## Collecting diagnostics

When you ask for help, include:

- **App version and build**: Settings → 关于 (About), for example `1.5 (9)`, or the
  commit SHA if you built from source.
- **iOS version and device model** (or the Simulator name).
- **Which of the four sites** is involved, and whether the official login page
  appeared.
- **Network diagnostics**: Settings → 帮助 → 网络诊断. The shareable summary contains
  only the app version, site, HTTP status, and time. It uses a cookie-free HEAD
  request that does not follow authentication redirects.
- **Logs** if you built from source: the filtered Xcode console output.
- **Screenshots**, with names, student IDs, URLs with tokens, and other personal
  data redacted.

Do not send passwords, one-time codes, session cookies, or full authenticated URLs.
The maintainer does not need them and cannot use them.

## Common questions

### Do I have to log in separately for each site?

Yes. The portal, Moodle, room booking, and sports booking sites each keep their own
session in a separate persistent WebKit data store. Cookies from Safari or from
another site in the app are not migrated. This is intentional isolation, not a bug.

### The app says I need to log in, but I am already logged in

Login detection is a best-effort check for visible password/captcha fields and
authentication URLs. It can be wrong after the school changes a page. Open the site
in the app and check; if the page works, report the false warning with the site, date,
and a redacted screenshot.

### A school page changed and a shortcut or feature stopped working

The four sites are official web pages, so the app can only follow them. When the
university redesigns a page or changes single sign-on, native shortcuts, probes, and
deep links may need updates. Please open an issue with what changed and when.

### Does the app work on the campus network or through a VPN?

The app connects directly and does not proxy or reroute traffic. Network diagnostics
only checks whether a public page answers a HEAD request; it does not prove you are
logged in or that school services are usable on that network.

### The app stopped opening after about a week

Builds signed with a free Apple personal team stop working when the provisioning
profile expires after 7 days. Re-sign and reinstall with your own team. This is an
Apple limitation, not an app bug.

### How does the app lock work?

The lock uses Face ID, Touch ID, or the device passcode through iOS Local
Authentication, and it shows a privacy shield when the app goes to the background.
It protects the local UI only. It does not protect your school account, and it does
not replace the university's own authentication.

### Where are downloads saved, and why did they disappear?

Downloads default to Files → On My iPhone → GTIIT → Downloads. A retention period
can be chosen for new downloads; external locations such as iCloud Drive are not
cleaned automatically. Deleting the app removes its local downloads, so keep
important files elsewhere.

### Why do some websites not turn dark?

The appearance feature adjusts colors for the four official campus hosts only, in an
isolated WebKit content world. PDFs and pages that opt out with a
`darkreader-lock` marker keep their original colors. Other sites and the native UI
are unaffected.

### Why do some links open in a different browser?

You can choose whether links open in the current web page, the in-app Safari view,
or your default browser. POST requests, logins, and server redirects stay in the
original web context so authentication is not lost.

### Does the shuttle countdown show real-time positions?

No. It counts down to the planned departure time from the published timetable. The
teaching-week toggle affects which trips are shown. It is not live vehicle tracking.

### Does the app collect my data or send statistics?

No. There is no backend, no analytics or advertising SDK, and no telemetry. The
maintainer cannot see your usage, your pages, or your account.

## What this project cannot help with

- Password resets, account recovery, MFA enrollment, or access permissions.
- Enrollment, grades, attendance, bookings, or leave requests, including errors in
  the school's own pages.
- School server outages, network policy, or changes to the official websites.
- Requests to bypass captchas, MFA, certificates, or school permissions.
- Problems caused by modified builds, jailbreaks, or third-party tweaks.

## Response expectations

Replies are best-effort. The maintainer is a student, so please be patient; a clear,
reproducible report with diagnostics is the fastest way to get help. Security reports
follow the timelines in [SECURITY.md](SECURITY.md).
