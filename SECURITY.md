# Security Policy

GTIIT Campus Assistant is an **unofficial, student-built** iOS client for official
GTIIT websites. It does not run a backend, does not collect analytics, and does not
handle school credentials on its own: logins happen inside the official web pages.

Because of that, the most interesting security issues are about what happens on the
device: credential exposure, unintended network requests, web injection escaping
its sandbox, link and download handling, and local lock or file protection.

## Supported versions

| Version | Supported |
| --- | --- |
| Latest release | ✅ |
| `main` branch (unreleased work) | ✅ |
| Older releases | ❌ |

The project is maintained by a single student as a side project. Fixes land on
`main` first; older tags are not backported.

## Reporting a vulnerability

**Please do not open a public issue, pull request, or discussion for a security
problem.** That would expose other users before a fix is available.

Report it privately through GitHub Security Advisories:

1. Open the repository's **Security** tab.
2. Choose **Advisories** and then **Report a vulnerability**.
3. Or use the direct link:
   <https://github.com/Optmst0118/gtiit-campus-ios/security/advisories/new>

Please include:

- The affected app version (Settings → 关于) or commit SHA, and how the build was
  made (Xcode from source, re-signed side-loaded build, Simulator).
- iOS version and device model.
- The affected area: portal, Moodle, room booking, sports centre, shuttle,
  downloads/PDF preview, app lock, settings/appearance, or network diagnostics.
- Steps to reproduce, the observed impact, and what an attacker could gain.
- Whether credentials, personal data, or files outside the app container are at
  risk.
- Redacted logs, screenshots, or a proof of concept. Never include real
  passwords, cookies, student IDs, or other personal data.

## What to expect

- We aim to acknowledge a report within **7 days** and give an initial assessment
  within **14 days**.
- This is best-effort work by one student maintainer, not a commercial support
  contract. There is no bug bounty.
- We will confirm the issue, work on a fix, and coordinate disclosure. We are happy
  to credit you in the advisory if you want.
- If you do not get a reply, a polite follow-up on the advisory is welcome. Please
  do not disclose the issue publicly while we are working on it.

## Scope

In scope:

- **Credentials and privacy**: reading, logging, storing, or transmitting passwords,
  one-time codes, cookies, session tokens, page contents, or personal data; any
  unintended network request or data collection; data written outside the app
  container.
- **Web injection**: the appearance script (Dark Reader) escaping the isolated
  content world, running on non-campus hosts, reading page globals or form values,
  patching page JavaScript prototypes, or being influenceable by page content.
- **Navigation and links**: unexpected cross-site tab switching, malicious URL
  schemes or universal links, popup/window handling, external-browser handoff,
  redirect handling that drops or leaks authentication context.
- **Local data and files**: download path traversal or overwriting files outside the
  container, retention cleanup that deletes the wrong files, data-store cleanup
  that reports success while data remains.
- **App lock and local authorization**: bypassing the lock screen, the background
  privacy shield, or the system-authentication check, including via UI state.
- **Supply chain**: the vendored Dark Reader build, its license/notice files, and
  assets bundled into the app.
- **Platform configuration**: weakening App Transport Security, privacy
  declarations, or entitlements.

Out of scope:

- Vulnerabilities in GTIIT servers, the student portal, Moodle, room booking, the
  sports booking site, or any other third-party service. Report those to the
  university's IT or the service operator.
- Compromised school accounts, password resets, MFA enrollment, or phishing that
  happens outside the app.
- Issues that require a jailbroken device, a modified build, or an attacker who
  already has full physical access to an unlocked device.
- Social engineering, spam, or reports that depend on tricking the maintainer.
- Automated scanner output without a demonstrated, app-specific impact.
- The 7-day expiry of free personal-team signatures; that is an Apple provisioning
  limitation, not a vulnerability.

## Safe testing expectations

- Test only with your own account and data. Do not access other people's data.
- Do not submit real bookings, leave requests, evaluations, or other actions that
  change school records while testing.
- Do not degrade or overload school systems.
- Report the issue privately and give us a reasonable chance to fix it before any
  public disclosure.
