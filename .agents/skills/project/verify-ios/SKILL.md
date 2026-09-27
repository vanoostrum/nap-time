---
name: verify-ios
description: How to build, test and lint the Nap Time iOS app (XcodeGen + xcodebuild + Swift Testing + SwiftLint), what works on Linux cloud agents vs. macOS CI only, and how to read CI results. Use whenever a factory stage needs to verify changes.
---

# verify-ios

## Where you are matters
- **Linux cloud agent (default):** no Xcode, no simulator. You **can** run `swift test` in `Packages/Core` if a Swift toolchain is installed (`swift --version`). You **can't** build the app target, run the app tests, or run the simulator. SwiftLint may be installable (`swiftlint` binary for Linux).
  → Put logic in `Packages/Core` so it's testable here. Push **small, frequent commits** and treat **CI as the source of truth** for everything else.
- **macOS with Xcode:** everything below runs locally.

## Commands (fast → slow)
```bash
# 1. Pure logic (macOS or Linux)
swift test --package-path Packages/Core
swift test --package-path Packages/Core --filter NapDurationTests      # single suite

# 2. Lint (must be clean with --strict)
swiftlint --strict

# 3. App build + all tests (macOS only)
xcodegen generate                          # .xcodeproj is generated, never committed
SIM=$(xcrun simctl list devices available -j | jq -r '[.devices[][]|select(.name|startswith("iPhone"))][0].udid')
xcodebuild test -project NapTime.xcodeproj -scheme NapTime \
  -destination "id=$SIM" -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO
# single test: add  -only-testing:NapTimeTests/NapTimeTests/contentViewBuilds
```

## CI (source of truth)
- Workflow `CI` (`.github/workflows/ci.yml`), job **`Build & Test`**. This is the required check on `main`.
- It runs on the `macos-26` runner with the latest stable Xcode: xcodegen → SwiftLint → `swift test` (Core) → `xcodebuild test`.
- Read the results:
  ```bash
  gh pr checks <pr>
  gh run list --branch <branch> --workflow CI -L 3
  gh run view <run-id> --log-failed
  ```
- The test result bundle is uploaded as the artifact `test-results` when tests fail.

## Conventions the checks enforce
- Swift 6 language mode, strict concurrency. SwiftUI views are `@MainActor`, so tests touching views need `@MainActor`.
- Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest, for new tests.
- New source files go under `NapTime/Sources/**` or `Packages/Core/Sources/Core/**`. XcodeGen picks them up automatically, so don't edit project files.
- Bundle ID `nl.clearblocks.naptime`; minimum iOS 18.

## Common failures
| Symptom | Fix |
|---|---|
| `Could not find test host` | The app's `PRODUCT_NAME` must stay `NapTime` (display name is set separately). |
| `main actor-isolated … from a nonisolated context` in tests | Mark the test struct or function `@MainActor`. |
| New file not compiled | Run `xcodegen generate`; check the file is under a `sources` path in `project.yml`. |
| SwiftLint `trailing_comma` / `line_length` | Fix the code; don't disable rules. |
