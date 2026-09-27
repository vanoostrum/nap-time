---
name: release-testflight
description: How Nap Time ships to TestFlight (fastlane beta lane via the Release GitHub workflow on push to main), where to find build numbers and status, and how to attach "What to test" notes. Use for release and release-notes stages.
---

# release-testflight

## Trigger
- Every push to `main`, i.e. every merged PR, runs the **`Release`** workflow (`.github/workflows/release.yml`) on `macos-26`.
- It can also be run manually: `gh workflow run Release --ref main`.

## What the lane does (`bundle exec fastlane beta`)
1. `setup_ci`, then authenticates with an **App Store Connect API key**. Secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT` (base64 .p8).
2. `match(type: "appstore", readonly: true)` fetches the signing assets from the private repo `vanoostrum/nap-time-certificates`. Secrets: `MATCH_PASSWORD`, `MATCH_DEPLOY_KEY`.
3. Sets the build number to the latest TestFlight build + 1. The marketing version comes from `MARKETING_VERSION` in `project.yml`.
4. `xcodegen generate` and `build_app` (app-store export, manual signing with the match profile, team `APPLE_TEAM_ID`).
5. `upload_to_testflight`, without waiting for processing. The changelog defaults to recent commit subjects.

## Where to see status
- The workflow run: `gh run list --workflow Release -L 5` and `gh run view <id>`. The run summary lists **version and build number**.
- App Store Connect → Apps → Nap Time → TestFlight. Processing usually takes 5–30 minutes.

## Attaching "What to test" notes (for write-release-notes)
Cloud agents don't hold App Store Connect credentials. They attach notes through a workflow:
```bash
gh workflow run "TestFlight Notes" --ref main -f build_number=<build> -f notes="<what to test, ≤4000 chars>"
```
That runs `bundle exec fastlane notes` on CI, which sets the notes on that build via the ASC API. If the build is still processing, the lane waits for up to 30 minutes.

## Re-run / rollback
- Re-run a failed release: `gh run rerun <id>`. The build number is recomputed, so re-runs are safe.
- TestFlight has no rollback. Expire a bad build in App Store Connect, or ship a fix.
