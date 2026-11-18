---
name: verify
description: Verify Nap Time as the required checks do. Lints, builds, and tests Core, and tests the CI change script, in this session, then waits for the CI checks Core (Linux) and App (iOS) on the PR. Use before every commit of a craft build, and when asked to verify.
---

# verify

The cloud agents run on Linux, with no Xcode. So this skill checks what Linux can check, and CI checks the rest.

## 1. In this session

Run:

```bash
scripts/verify.sh
```

It runs from any folder. It runs, in order, and stops at the first failed step:

0. On Linux only: `Install Swift`. When `swift` is missing or is not the version in `.swift-version`, it runs `bash scripts/cloud-setup.sh`, which installs that version. The first verify in a new cloud session does this and takes a few minutes longer. When Swift is right, the step does not run.
1. `Swift version`: `swift --version`. On Linux, it must print the version in `.swift-version`. On macOS, Swift comes with Xcode, and the step only prints it.
2. The lint: `swift format lint --strict --recursive .`. To fix the format, run `swift format -i --recursive <paths>`.
3. `swift build --package-path Packages/Core`.
4. `swift test --package-path Packages/Core`.
5. `Test the change script`: `python3 -m unittest discover -s scripts -p 'test_*.py'`. These tests check `scripts/ci_changes.py`, which decides if the `Screenshots` job runs on a PR. `Core (Linux)` runs the same step.

It ends with `verify: PASS`, or with `verify: FAIL at step '<step>'` after that step's output.

## 2. On a pull request

The code in `App`, `Widget`, `Store`, `StoreTests`, and `UITests` builds only on macOS. After you push to a branch with an open PR, run:

```bash
python3 scripts/ci_checks.py "Core (Linux)" "App (iOS)"
```

It finds the head commit of the PR of the current branch (or use `--pr N` or `--sha SHA`). It checks every 30 seconds until both checks are done, for at most 45 minutes (`--timeout`). It prints `PASS`, or `FAIL` with the check, the URL, the first failed step, and the error lines of its job log. If the job log is not reachable, it prints the check's annotations.

## Result

Return pass or fail. For a fail, return the step and the error lines, and the file if the error names one.
