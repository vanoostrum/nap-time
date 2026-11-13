---
name: drive-app
description: Drive Nap Time through CI and collect the screenshot evidence. Finds the Screenshots run for the PR's head commit, downloads the PNG of every entry point, and fails for each missing one. Use to prove a screen or view in a craft build, or when asked to run or screenshot the app.
---

# drive-app

The cloud agents have no simulator. The `Screenshots` CI job runs the UI tests in `NapTimeUITests` in test mode, and saves one PNG per entry point. This skill collects those PNG files as evidence.

## Entry points

An entry point is a screen or view that this skill expects a screenshot of. This list is the only source: `scripts/drive_app.py` reads it. Each ticket that adds an entry point adds a line here, and a UI test that saves `<entry point>.png`.

- `home`: the placeholder home screen. Test: `EntryPointTests.testHome`, in test mode.
- `live-activity`: the Lock Screen view of the placeholder Live Activity, rendered with `ImageRenderer` (ADR 0003). Test: `EntryPointTests.testLiveActivity`.

## Add an entry point

1. In `NapTimeUITests`, add a test that launches the app with `--test-mode` (and `--now` or `--location` if the screen needs them), opens the screen, and calls `attach(png:entryPoint:)` with the entry point name. For a view that a UI test cannot open, render it with `ImageRenderer`, and add its source file to the `NapTimeUITests` sources in `project.yml`.
2. Add the entry point to the list above.

## Run

Push the commit, then run:

```bash
python3 scripts/drive_app.py
```

It uses the head commit of the open PR of the current branch (or `--pr N`, or `--sha SHA`). It:

1. Waits for the `Screenshots` run of that commit to exist and finish. It checks every 30 seconds, for at most 30 minutes (`--timeout`). After that it fails with `no Screenshots run finished for commit <sha>`.
2. Gets the PNG files. It tries the `screenshots` artifact first, with `gh api`. In the cloud sessions, the artifact host (`*.blob.core.windows.net`) is not reachable, so it reads the branch `screenshots/<PR branch>` instead. The `Screenshots` job pushes the files to `<head sha>/` on that branch on every run. **The branch is the path that works in the cloud sessions.** The output line `Source:` names the path that it used.
3. Saves every file to `build/evidence/<sha>/` (or `--out DIR`).
4. Fails for each entry point in the list with no PNG, and for a `Screenshots` run that did not succeed, with the names of the failed tests from `test-summary.json`.

It ends with `PASS: <n> entry points from <source>`, or with one `FAIL:` line per problem, and exits 0 or 1.

## Look at the screenshots

Open each PNG in `build/evidence/<sha>/` with the Read tool, and check that it shows what the ticket says. A PNG that exists but shows the wrong screen is a fail.

## Result

Return pass or fail, the output of the script, and the paths of the PNG files.
