---
name: drive-app
description: Drive Nap Time through CI and collect the screenshot evidence. Finds the Screenshots run for the PR's head commit, downloads the PNG of every entry point, and fails for each missing one. Use to prove a screen or view in a craft build, or when asked to run or screenshot the app.
---

# drive-app

The cloud agents have no simulator. The `Screenshots` CI job runs the UI tests in `NapTimeUITests` in test mode, and saves one PNG per entry point. This skill collects those PNG files as evidence.

## Entry points

An entry point is a screen or view that this skill expects a screenshot of. This list is the only source: `scripts/drive_app.py` reads it. Each ticket that adds an entry point adds a line here, and a UI test that saves `<entry point>.png`.

Each one starts the app with `--test-mode`, its seed, and the default test time (21 June 2026 10:00 +02:00).

- `add-child`: `--seed none`. "Add your child" as the app opens, empty. Page `child/add-empty.html`. Test: `EntryPointTests.testAddChild`.
- `add-child-filled`: `--seed none`. Types "Mila", sets the birthdate wheel to 12 March 2025, and closes the birthdate sheet. Page `child/add.html`. Test: `EntryPointTests.testAddChildFilled`.
- `home`: `--seed family`, with Mila selected. The day sky, the child switcher with "+", "Mila is awake", "since 06:55 · 11 h 10 m slept today", "Sleep time", and "Add a sleep from earlier". Page `home/day.html`, without the gear and the Charts tab. Test: `EntryPointTests.testHome`.
- `home-sleeping`: `--seed sleeping --now 2026-06-21T21:56:00+02:00`. The night sky, "Mila is sleeping", "2 h 14 m · since 19:42", "Wake up", and "Woke earlier? Set the time". Page `home/night.html`, without the gear and the Charts tab. Test: `EntryPointTests.testHomeSleeping`.
- `home-napping`: `--seed napping --now 2026-06-21T13:50:00+02:00`. The day sky, "Mila is sleeping", "45 m · since 13:05", "Wake up", and "Woke earlier? Set the time". Page `home/nap.html`, without the gear and the Charts tab. Test: `EntryPointTests.testHomeNapping`.
- `home-sunset`: `--seed evening --now 2026-06-21T22:05:00+02:00`. The sunset sky (value "sunset"), "Mila is awake", "since 15:10 · 12 h 05 m slept today", "Sleep time", and "Add a sleep from earlier". Page `home/sunset.html`, without the gear and the Charts tab. Test: `EntryPointTests.testHomeSunset`.
- `home-night-awake`: `--seed evening --now 2026-06-21T23:30:00+02:00`. The night sky (value "night"), "Mila is awake", "since 15:10 · 12 h 05 m slept today", "Sleep time", and "Add a sleep from earlier". Page `home/night-awake.html`, without the gear and the Charts tab. Test: `EntryPointTests.testHomeNightAwake`.
- `home-sunrise`: `--seed winter-morning --now 2026-11-15T08:00:00+01:00`. The sunrise sky (value "sunrise"), "Mila is awake", "since 06:40 · 10 h 52 m slept today", "Sleep time", and "Add a sleep from earlier". Page `home/sunrise.html`, without the gear and the Charts tab. Test: `EntryPointTests.testHomeSunrise`.
- `add-another-child`: `--seed family`. Taps "+", types "Noah", sets the birthdate wheel to 10 February 2022, and closes the birthdate sheet. Page `child/add-another.html`. Test: `EntryPointTests.testAddAnotherChild`.
- `edit-child`: `--seed family`. Touches and holds Mila's avatar. Page `child/edit.html`. Test: `EntryPointTests.testEditChild`.
- `delete-child`: `--seed family`. Opens Edit child for Mila and taps "Delete Mila". Page `child/delete.html`. Test: `EntryPointTests.testDeleteChild`.
- `new-sleep`: `--seed family`. Taps "Add a sleep from earlier". Add a sleep with Nap, "Sun 21 Jun · 09:00", "Sun 21 Jun · 10:00", "1 h 00 m of sleep", and "Add sleep". Page `sleep/new.html`, with the values of the seed. Test: `EntryPointTests.testNewSleep`.
- `edit-sleep`: `--seed family`. Taps the status line "since 06:55 · 11 h 10 m slept today". Edit sleep for Mila's night "Sat 20 Jun · 19:45" to "Sun 21 Jun · 06:55", "11 h 10 m of sleep", Save, and "Delete this sleep". Page `sleep/edit.html`, with the values of the seed. Test: `EntryPointTests.testEditSleep`.
- `woke-earlier`: `--seed sleeping --now 2026-06-21T21:56:00+02:00`. Taps "Woke earlier? Set the time". "Woke up" at "Sun 21 Jun · 21:56" and "2 h 14 m of sleep. Mila is awake after you save." Page `sleep/running.html`, with the values of the seed. Test: `EntryPointTests.testWokeEarlier`.
- `edit-running-sleep`: `--seed sleeping --now 2026-06-21T21:56:00+02:00`. Taps the status line "2 h 14 m · since 19:42". Edit sleep with "Still asleep", "2 h 14 m so far", and no Delete button. Page `sleep/running-start.html`, with the values of the seed. Test: `EntryPointTests.testEditRunningSleep`.
- `sleep-overlap`: `--seed family --now 2026-06-21T07:30:00+02:00`. Taps "Add a sleep from earlier". The red line "This overlaps Mila's night from 19:45 to 06:55." and a grey "Add sleep". Page `sleep/overlap.html`, with the values of the seed. Test: `EntryPointTests.testSleepOverlap`.
- `delete-sleep`: `--seed family`. Taps the status line, then "Delete this sleep". "Delete this sleep?" and "This deletes Mila's night from 19:45 to 06:55, on both phones. You cannot undo this." Page `sleep/delete.html`, with the values of the seed. Test: `EntryPointTests.testDeleteSleep`.
- `home-long-name`: `--seed long-name`. The home screen with "Maximiliana Rosalind Pepperpot is awake". No gallery page: check that the whole name shows, with no ellipsis. Test: `EntryPointTests.testHomeLongName`.
- `delete-child-long-name`: `--seed long-name`. Opens Edit child and taps "Delete Maximiliana Rosalind Pepperpot". No gallery page: check that the title, the body, and the button show the whole name, with no ellipsis. Test: `EntryPointTests.testDeleteChildLongName`.
- `live-activity`: the Lock Screen view of the placeholder Live Activity, rendered with `ImageRenderer` (ADR 0003). Test: `EntryPointTests.testLiveActivity`.

## Add an entry point

1. In `NapTimeUITests`, add a test that launches the app with `AppDriver.launch(seed:)` (and `--now` or `--seed` if the screen needs them), opens the screen, and calls `attachScreenshot(_:to:)` with the entry point name. The seeds are `none`, `family`, `long-name`, `sleeping`, `napping`, `evening`, and `winter-morning`, in Core's `Seed`. For a view that a UI test cannot open, render it with `ImageRenderer`, and add its source file to the `NapTimeUITests` sources in `project.yml`.
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
