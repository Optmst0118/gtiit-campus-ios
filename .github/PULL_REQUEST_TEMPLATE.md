## Summary

<!-- What does this pull request change, and why? -->

## Related issue

<!-- Link the issue or discussion, e.g. "Fixes #123". Write "N/A" if there is none. -->

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Refactor (no user-visible behavior change)
- [ ] Documentation
- [ ] Tests / tooling / CI
- [ ] Web appearance (Dark Reader injection)

## How was this verified?

<!--
Be specific and honest. Paste the commands you ran and the environment.
Example:
- python3 Tools/check_project.py
- xcodebuild -project GTIIT.xcodeproj -scheme GTIIT -configuration Debug \
    -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
- python3 Tools/run_regression.py <disposable-simulator-UDID>
- Manual check on iPhone 15 / iOS 17.5
-->

## Privacy and web-injection review

- [ ] No new data collection, analytics, telemetry, or third-party network calls were added.
- [ ] No credentials, cookies, page contents, student IDs, or personal data are read, logged, stored, or uploaded by app code.
- [ ] No captcha/MFA/authorization bypass, scraping, or automated submission of school forms was added.
- [ ] Web injection is limited to the appearance script on official campus hosts, runs in the isolated content world, and does not read page globals or form values.
- [ ] Vendored third-party code (Dark Reader) and its license/notice files were kept up to date.
- [ ] No hardcoded credentials, tokens, personal signing team IDs, bundle identifiers, absolute home paths, or device UDIDs were committed.
- [ ] Changes to `Info.plist`, App Transport Security, or permissions are explained above.

## Checklist

- [ ] I have read `CONTRIBUTING.md`.
- [ ] `python3 Tools/check_project.py` passes.
- [ ] I ran `python3 Tools/gen_project.py` if Swift files or resources were added or removed.
- [ ] The iOS Simulator build succeeds.
- [ ] Relevant regression/UI checks were run and the results are reported above (if behavior changed).
- [ ] User-visible changes are reflected in README/docs.
- [ ] Commits are signed off (`git commit -s`).
- [ ] This pull request is focused; unrelated formatting or refactoring is kept separate.
