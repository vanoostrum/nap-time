# Nap Time

An iOS app to track a young child's sleep. Swift 6 with strict concurrency, SwiftUI, minimum iOS 26.0. GitHub's macOS runners have no Xcode 27 yet, so CI builds with the Xcode in `.xcode-version`; raise both to 27 when they do.

@.claude/craft.md

If a skill is unknown, read `.claude/skills/<name>/SKILL.md` and follow it.

Every code change goes through craft. Start with `craft:spec` for a single ticket, or `craft:plan` for bigger work. Never edit code outside a craft step.

## Engineering rules

- `project.yml` is the source of the Xcode project. Run `xcodegen generate`. Do not commit `NapTime.xcodeproj`. See `docs/adr/0001-xcodegen.md`.
- All pure logic lives in `Packages/Core`, which imports Foundation only. The app and widget targets stay thin. See `docs/adr/0002-core-package.md`.
- The family store lives in the framework target `NapTimeStore`, which the app and the widget both link. See `docs/adr/0005-core-data-cloudkit.md`.
- **Test seam:** unit tests call the public API of `Packages/Core`, or of `NapTimeStore` in the unit test target `NapTimeStoreTests` with an in-memory store. App behavior is tested through the UI test target `NapTimeUITests` in test mode. Do not test SwiftUI view internals.
- `swift format lint --strict` is the linter.
- No third-party Swift packages without a ticket that says why.
- `.xcode-version` and `.swift-version` change together, in one ticket.
- The code holds no personal data. The repo is public.


## Build and test

On Linux (the cloud agents) and on macOS:

```bash
bash scripts/cloud-setup.sh          # from the folder that holds the nap-time checkout; installs Swift from .swift-version
scripts/verify.sh                    # lint, then build and test Core
swift format lint --strict --recursive .
swift format -i --recursive <paths>  # fix the format
swift build --package-path Packages/Core
swift test --package-path Packages/Core
```

On a Mac with the Xcode in `.xcode-version`:

```bash
brew install xcodegen
xcodegen generate                    # makes NapTime.xcodeproj from project.yml
open NapTime.xcodeproj               # run the NapTime scheme in an iPhone simulator
xcodebuild test -project NapTime.xcodeproj -scheme NapTime \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:NapTimeStoreTests
xcodebuild test -project NapTime.xcodeproj -scheme NapTime \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:NapTimeUITests
```

In CI, the workflow `CI` (`.github/workflows/ci.yml`) runs the checks `Core (Linux)`, `App (iOS)`, and `Screenshots`. A cloud agent proves CI with the `verify` skill and screens with the `drive-app` skill.

Test mode: launch the app with `--test-mode`, and optionally `--now <ISO 8601 date with a UTC offset>` and `--location <lat>,<lon>`. Core's `LaunchArguments` parses them.
