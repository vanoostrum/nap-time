# Nap Time

An iOS app to track a young child's sleep. Swift 6 with strict concurrency, SwiftUI, minimum iOS 27.0.

@.claude/craft.md

If a skill is unknown, read `.claude/skills/<name>/SKILL.md` and follow it.

## Engineering rules

- `project.yml` is the source of the Xcode project. Run `xcodegen generate`. Do not commit `NapTime.xcodeproj`. See `docs/adr/0001-xcodegen.md`.
- All pure logic lives in `Packages/Core`, which imports Foundation only. The app and widget targets stay thin. See `docs/adr/0002-core-package.md`.
- **Test seam:** unit tests call the public API of `Packages/Core`. App behavior is tested through the UI test target `NapTimeUITests` in test mode. Do not test SwiftUI view internals.
- `swift format lint --strict` is the linter.
- No third-party Swift packages without a ticket that says why.
- `.xcode-version` and `.swift-version` change together, in one ticket.
- The code holds no personal data. The repo is public.

The walking skeleton completes these rules with the build and test commands.
