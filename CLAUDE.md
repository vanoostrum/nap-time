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
scripts/verify.sh                    # on Linux, installs Swift from .swift-version if needed; then lint, build and test Core, and test the CI change script
bash scripts/cloud-setup.sh          # installs Swift from .swift-version on Ubuntu 24.04 and checks its signature; runs from any folder; verify.sh runs it for you
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

Test mode: launch the app with `--test-mode`, and optionally `--now <ISO 8601 date with a UTC offset>` and `--seed <name>`. Core's `LaunchArguments` parses them.

## Release

A merge deploys nothing. The workflow `Release` (`.github/workflows/release.yml`) uploads `main` to TestFlight (ADR 0009, 0010).

1. On GitHub, open Actions, then `Release`, then "Run workflow" on `main`. A run from another branch does nothing.
2. The job `release` waits for approval in the environment `testflight`. Open the run and click "Review deployments", then "Approve and deploy".
3. The run archives, exports, checks the signed entitlements, uploads, and then the job `tag` pushes the annotated tag `release/<build number>`. The build number is the run number, and the version is `MARKETING_VERSION` in `project.yml`.

- **The upload failed:** click "Re-run all jobs". A re-run keeps the build number, so it uploads the same build again.
- **The upload succeeded:** App Store Connect rejects the same build number again, so start a new run.
- **Only the tag push failed:** click "Re-run failed jobs". It runs only `tag`, with no upload and no approval. If the tag is already on GitHub, the re-run fails, and nothing more is needed.
- TestFlight builds expire after 90 days. Start a release at least every 90 days.

**The CloudKit schema.** The Core Data model only grows: a change only adds entities or optional attributes (ADR 0011). No check in `Release` guards this. Before a release that changes the model, deploy the schema by hand:

1. Run a Debug build from Xcode on your phone with the launch argument `--init-cloudkit-schema`. The Xcode console shows "The CloudKit schema is initialized". The run also saves and deletes a throwaway share, so the record type `cloudkit.share` is in the development schema. Then delete Nap Time from the phone and install it again from TestFlight, because the Debug run replaced the TestFlight app.
2. In the CloudKit Console, open `iCloud.nl.clearblocks.naptime`. Check that the development schema has the record types `CD_Child` and `CD_Sleep` with all fields, and `cloudkit.share`. Click "Deploy Schema Changes".
3. Start `Release`.
