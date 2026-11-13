---
name: verify
description: Verify Nap Time as the required checks do. Lints, builds, and tests Core in this session, then waits for the CI checks Core (Linux) and App (iOS) on the PR. Use before every commit of a craft build, and when asked to verify.
---

# verify

The cloud agents run on Linux, with no Xcode. So this skill checks what Linux can check, and CI checks the rest.

## 1. In this session

Run:

```bash
scripts/verify.sh
```

It runs, in order, and stops at the first failed step:

1. `swift --version`. It must print the version in `.swift-version`. If `swift` is missing, run `bash scripts/cloud-setup.sh` from the folder that holds the `nap-time` checkout, then `. ~/.local/share/swiftly/env.sh`.
2. The lint: `swift format lint --strict --recursive .`. To fix the format, run `swift format -i --recursive <paths>`.
3. `swift build --package-path Packages/Core`.
4. `swift test --package-path Packages/Core`.

It ends with `verify: PASS`, or with `verify: FAIL at step '<step>'` after that step's output.

## 2. On a pull request

The code in `App`, `Widget`, `Store`, `StoreTests`, and `UITests` builds only on macOS. After you push to a branch with an open PR, run:

```bash
python3 scripts/ci_checks.py "Core (Linux)" "App (iOS)"
```

It finds the head commit of the PR of the current branch (or use `--pr N` or `--sha SHA`). It checks every 30 seconds until both checks are done, for at most 45 minutes (`--timeout`). It prints `PASS`, or `FAIL` with the check, the URL, the first failed step, and the error lines of its job log. If the job log is not reachable, it prints the check's annotations.

## Result

Return pass or fail. For a fail, return the step and the error lines, and the file if the error names one.
