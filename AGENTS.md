# AGENTS.md

**Nap Time** is a native iOS baby-sleep app (SwiftUI, iOS 18+). It's built by a *software factory*: AI agents take work items from Slack through Linear to TestFlight, with two human gates.

## Where things live

| Path | What |
|---|---|
| `NapTime/` | App target (SwiftUI views, app entry). Keep it thin. |
| `NapTimeTests/` | App-level unit tests (Swift Testing). |
| `Packages/Core/` | Local Swift package for pure logic, testable with `swift test` (also on Linux). Put new logic here. |
| `project.yml` | XcodeGen spec. **The `.xcodeproj` is generated and gitignored**: run `xcodegen generate`. |
| `fastlane/`, `Gemfile` | Release to TestFlight (`bundle exec fastlane beta`). |
| `.github/workflows/` | `ci.yml` (build, test, lint), `release.yml` (TestFlight on push to `main`). |
| `docs/specs/` | One spec per work item: `NAP-<num>-<slug>.md`. |
| `docs/adr/` | Architecture decision records. |
| `factory/` | Harness-neutral factory definition (`stages.yaml`, Linear IDs, automation specs). |
| `.agents/skills/factory/` | Generic stage skills (the contracts). |
| `.agents/skills/project/` | Project-specific skills: `verify-ios`, `release-testflight`. |

## Conventions

- Swift 6, strict concurrency. SwiftUI only. SwiftLint must pass with `--strict` (`.swiftlint.yml`).
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`). Write tests first.
- Prefer small, pure types in `Core`; views stay declarative.
- How to build, test and lint: see `.agents/skills/project/verify-ios/SKILL.md`.

## Factory conventions

The Linear team key is **`NAP`**; the full config is in `factory/linear.yaml`. Stage definitions are in `factory/stages.yaml`.

- **Branch:** `nap-<num>/<slug>` (e.g. `nap-12/about-screen`). **PR title:** `[NAP-<num>] <title>`.
- **Commit trailers** (on every factory commit):
  ```
  Factory-Issue: NAP-<num>
  Factory-Stage: <stage>        # spec | build | ci-fix | review | comment-fix | release-notes
  ```
- **Run record:** every stage agent appends one Linear comment to the issue:
  ```
  Run record: stage | model | started | finished | outcome | notes
  build | <model id> | 2026-01-01T10:00Z | 2026-01-01T10:20Z | success | opened PR #7
  ```
  `outcome` is one of `success`, `failed`, `escalated` or `noop`.
- **Slack:** the item's thread permalink is stored in the Linear issue description as a line `Slack-Thread: <permalink>`. Human-facing updates go to that thread in `#factory`; noisy detail goes to `#factory-log`, prefixed `[NAP-<num>]`.
- **Loop cap:** at most **3** automatic fix attempts per stage (counted via `Factory-Stage` trailers or run records). At the cap, move the issue to **Needs human**, then ping in the thread with what you tried and what's blocking.
- Never merge without the human gate (✅ in the Slack thread). Never push to `main` directly.
- Never commit secrets. CI secrets live in GitHub Actions secrets.
