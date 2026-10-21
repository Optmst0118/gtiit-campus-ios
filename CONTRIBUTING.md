# Contributing to GTIIT Campus Assistant

Thanks for your interest in improving this project.

GTIIT Campus Assistant is an **unofficial, student-built** iOS client: it wraps the
official GTIIT student portal, Moodle, room booking, and sports booking websites in
WKWebView, and adds a native shuttle timetable. It is not affiliated with, endorsed
by, or supported by GTIIT. Please keep that boundary in mind when proposing changes.

By participating in this project you agree to follow our
[Code of Conduct](CODE_OF_CONDUCT.md).

## Ways to contribute

- **Report a bug** that you can reproduce, using the bug report form.
- **Share ideas and ask questions** in
  [Discussions](https://github.com/Optmst0118/gtiit-campus-ios/discussions).
- **Test on real devices** and iOS versions, especially login flows, downloads, and
  Dynamic Type.
- **Improve documentation**, screenshots, and accessibility.
- **Send code** for fixes, tests, or focused improvements.

## Before you start

- Search the existing issues and discussions first.
- For anything larger than a small fix, open an issue or discussion before writing
  code, so we can agree on the approach and the privacy boundaries.
- Never include real passwords, one-time codes, session cookies, student IDs, or
  other personal data in an issue, a pull request, a screenshot, or a test fixture.
- Report security problems privately as described in [SECURITY.md](SECURITY.md);
  never open a public issue for them.

## Requirements

- macOS with Xcode 26 or newer (the project uses the iOS 26 SDK and targets
  iOS 17; CI uses the `macos-26` runner, see
  [.github/workflows/ci.yml](.github/workflows/ci.yml)).
- Python 3.9 or newer for the project and test scripts. They use the standard
  library only.
- There are no Swift Package Manager or CocoaPods dependencies to install.
- Building for a physical device requires your own Apple signing team. Do not
  commit that team identifier or any signing profile.

## Getting started

```sh
git clone https://github.com/Optmst0118/gtiit-campus-ios.git
cd gtiit-campus-ios

# Only needed after adding or removing Swift sources or resources:
python3 Tools/gen_project.py

python3 Tools/check_project.py

xcodebuild -project GTIIT.xcodeproj -scheme GTIIT -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Notes:

- `GTIIT.xcodeproj/project.pbxproj` is **generated** by `Tools/gen_project.py`.
  Do not hand-edit it: change the generator and regenerate, so the next run does
  not silently revert your edit.
- `Tools/signing.env` is a local, git-ignored file. The generator also reads
  `DEVELOPMENT_TEAM` from the environment, which is handy for local device builds.
- A physical device needs a development team selected in Xcode. Simulator builds
  do not need signing.

## Verification

Before opening a pull request, run the checks that match your change:

| Command | What it covers |
| --- | --- |
| `python3 Tools/check_project.py` | Offline validation of the Xcode project, file references, scheme, assets, and Info.plist keys |
| `python3 Tools/gen_project.py` | Regenerates the project after Swift files/resources change |
| `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` | Compiles the app for the iOS Simulator |
| `python3 Tools/run_regression.py <SIMULATOR_UDID>` | WebKit, navigation, download, storage, and lock regression suite |
| `python3 Tools/verify_builds.py` | Re-checks the recorded build evidence |
| `python3 Tools/build_ui_review.py` | Renders the UI review harness for visual checks |

The regression harness runs in a separate test app (`local.gtiit.regression`) and
needs a disposable Simulator whose name contains `Review` or `Test`. It uses a
local fixture server and synthetic data only. Never point it at your real account,
and never test changes by submitting real bookings, leave requests, or evaluations.

CI (the **Build** workflow) runs the project checks, a Swift type check, and an
unsigned simulator build. It does not run the regression suite because that needs a
booted Simulator; run it locally when you touch WebKit, navigation, downloads,
storage, or lock behavior.

Report what you actually ran, including the Simulator or device and any failures.
Do not fabricate test evidence.

## Code style

- Swift 5, SwiftUI, minimum iOS 17. Match the existing file layout:
  `GTIIT/App`, `Core`, `Models`, `Services`, `Views`, `Components`,
  plus resources under `GTIIT/Resources`.
- Four-space indentation, one type per file where practical, and no unrelated
  formatting churn in a focused pull request.
- Mark UI- and WebKit-owning state `@MainActor`. Bridge KVO and WebKit callbacks to
  the main thread; never block the main thread with file or network I/O.
- Keep existing Chinese user-facing copy on Chinese screens and match the existing
  comment style. Chinese explanatory comments are welcome; comments should explain
  *why* a non-obvious decision was made.
- Prefer `let`, avoid force unwraps, and surface failures (for example, do not
  report a failed cleanup as success).
- Do not create long-lived models inside SwiftUI view bodies, and keep WebView hosts
  stable when the view hierarchy updates.
- Do not add third-party Swift dependencies without discussing it first. Vendored
  JavaScript (Dark Reader) must keep its license and notice files accurate.

## Privacy and safety rules

These are hard requirements, not preferences. A change that breaks one will be
rejected:

- No analytics, telemetry, tracking, or advertising SDKs, and no third-party network
  requests. The app talks to the four official campus sites the user opens, plus
  downloads the user requests.
- Never read, log, store, or upload passwords, one-time codes, cookies, session
  tokens, page contents, student IDs, or other personal data from app code.
- No scraping or crawling of school systems, no automated submission of forms, and
  no bypassing of captchas, MFA, certificates, or authorization. No fake or
  fabricated data presented as real school data.
- No hardcoded credentials, tokens, API keys, personal signing team IDs, device
  UDIDs, or absolute home-directory paths.
- Local storage stays limited to app preferences, WebKit data containers, and
  user-requested downloads. Do not weaken App Transport Security or privacy
  declarations to make a feature work.
- Web appearance injection may only run on the official campus hosts, inside the
  isolated content world. It must not read page globals or form values, patch page
  JavaScript prototypes, or fetch arbitrary URLs. Update
  `GTIIT/Resources/WebAppearance/DARKREADER-LICENSE.txt` and `NOTICE.txt` when the
  vendored Dark Reader changes.

If a feature genuinely needs to cross one of these lines, open a discussion first
and explain the user benefit, the data involved, and the safeguards. Expect a
conservative answer.

## Branches and commit messages

- Branch from `main` and use a descriptive prefix:
  `fix/...`, `feat/...`, `docs/...`, `test/...`, `refactor/...`, `chore/...`.
- Write commit subjects in the imperative mood, at most 72 characters, for example
  `fix(navigation): keep POST redirects in the original tab`.
- Explain the problem and the approach in the body, wrapped at 72 characters, and
  reference the related issue with `Fixes #123`.
- Keep one logical change per commit, and keep the history reviewable.
- Conventional Commits prefixes are appreciated but not mandatory.

## Developer Certificate of Origin (DCO)

This project uses the [Developer Certificate of Origin 1.1](https://developercertificate.org/)
instead of a Contributor License Agreement. No CLA is required.

Sign off every commit:

```sh
git commit -s -m "fix(navigation): keep POST redirects in the original tab"
```

The sign-off adds a trailer like:

```text
Signed-off-by: Your Name <the-email-you-use-for-commits>
```

By signing off you certify that you wrote the change, or that you have the right to
submit it under the project's license.

## Pull requests

- Keep the pull request focused on one topic and fill in the template.
- Link the related issue or discussion, and describe how you verified the change.
- Complete the privacy and web-injection checklist honestly.
- Make sure the **Build** workflow passes, and run local regression tests when the
  behavior you touched is covered by them.
- Draft pull requests are welcome for early feedback.
- Review is best-effort by a student maintainer. If a review takes a while, a
  polite ping on the pull request is fine.

## Documentation

Update the README or the relevant file under `docs/` when user-visible behavior
changes. Chinese is the primary language for user-facing documentation; keep new
English text consistent with the existing bilingual style.

## Licensing of contributions

Contributions are accepted under the MIT License, the same license as the rest of
the repository; see [LICENSE](LICENSE). By contributing you agree that your
contribution may be distributed under that license. No separate CLA is required.

## Getting help

See [SUPPORT.md](SUPPORT.md) for setup, diagnostics, and common questions, or start
a [discussion](https://github.com/Optmst0118/gtiit-campus-ios/discussions).
