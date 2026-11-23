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
- `home`: `--seed family`, with Mila selected. The day sky, the child switcher with "+" and the gear, "Mila is awake", "since 06:55 · 11 h 10 m slept today", "Nap time", and "Add a sleep from earlier". Page `home/day.html`, with the gear. Test: `EntryPointTests.testHome`.
- `home-sleeping`: `--seed sleeping --now 2026-06-21T23:30:00+02:00`. The night sky, "Mila is sleeping", "3 h 48 m · since 19:42", "Wake up", and "Woke earlier? Set the time". Page `home/night.html`, with the gear. Test: `EntryPointTests.testHomeSleeping`.
- `home-napping`: `--seed napping --now 2026-06-21T13:50:00+02:00`. The day sky, "Mila is sleeping", "45 m · since 13:05", "Wake up", and "Woke earlier? Set the time". Page `home/nap.html`, with the gear. Test: `EntryPointTests.testHomeNapping`.
- `home-sunset`: `--seed evening --now 2026-06-21T22:05:00+02:00`. The sunset sky (value "sunset"), "Mila is awake", "since 15:10 · 12 h 05 m slept today", "Sleep time", and "Add a sleep from earlier". Page `home/sunset.html`, with the gear. Test: `EntryPointTests.testHomeSunset`.
- `home-night-awake`: `--seed evening --now 2026-06-21T23:30:00+02:00`. The night sky (value "night"), "Mila is awake", "since 15:10 · 12 h 05 m slept today", "Sleep time", and "Add a sleep from earlier". Page `home/night-awake.html`, with the gear. Test: `EntryPointTests.testHomeNightAwake`.
- `home-sunrise`: `--seed winter-morning --now 2026-11-15T08:00:00+01:00`. The sunrise sky (value "sunrise"), "Mila is awake", "since 06:40 · 10 h 52 m slept today", "Nap time", and "Add a sleep from earlier". Page `home/sunrise.html`, with the gear. Test: `EntryPointTests.testHomeSunrise`.
- `add-another-child`: `--seed family`. Taps "+", types "Noah", sets the birthdate wheel to 10 February 2022, and closes the birthdate sheet. Page `child/add-another.html`. Test: `EntryPointTests.testAddAnotherChild`.
- `edit-child`: `--seed family`. Touches and holds Mila's avatar. Page `child/edit.html`. Test: `EntryPointTests.testEditChild`.
- `delete-child`: `--seed family`. Opens Edit child for Mila and taps "Delete Mila". Page `child/delete.html`. Test: `EntryPointTests.testDeleteChild`.
- `new-sleep`: `--seed family`. Taps "Add a sleep from earlier". Add a sleep with Nap, "Sun 21 Jun · 09:00", "Sun 21 Jun · 10:00", "1 h 00 m of sleep", and "Add sleep". Page `sleep/new.html`, with the values of the seed. Test: `EntryPointTests.testNewSleep`.
- `edit-sleep`: `--seed family`. Taps the status line "since 06:55 · 11 h 10 m slept today". Edit sleep for Mila's night "Sat 20 Jun · 19:45" to "Sun 21 Jun · 06:55", "11 h 10 m of sleep", Save, and "Delete this sleep". Page `sleep/edit.html`, with the values of the seed. Test: `EntryPointTests.testEditSleep`.
- `woke-earlier`: `--seed sleeping --now 2026-06-21T21:56:00+02:00`. Taps "Woke earlier? Set the time". "Woke up" at "Sun 21 Jun · 21:56" and "2 h 14 m of sleep. Mila is awake after you save." Page `sleep/running.html`, with the values of the seed. Test: `EntryPointTests.testWokeEarlier`.
- `edit-running-sleep`: `--seed sleeping --now 2026-06-21T21:56:00+02:00`. Taps the status line "2 h 14 m · since 19:42". Edit sleep with "Still asleep", "2 h 14 m so far", and no Delete button. Page `sleep/running-start.html`, with the values of the seed. Test: `EntryPointTests.testEditRunningSleep`.
- `sleep-overlap`: `--seed family --now 2026-06-21T07:30:00+02:00`. Taps "Add a sleep from earlier". The red line "This overlaps Mila's night from 19:45 to 06:55." and a grey "Add sleep". Page `sleep/overlap.html`, with the values of the seed. Test: `EntryPointTests.testSleepOverlap`.
- `delete-sleep`: `--seed family`. Taps the status line, then "Delete this sleep". "Delete this sleep?" and "This deletes Mila's night from 19:45 to 06:55, on both phones. You cannot undo this." Page `sleep/delete.html`, with the values of the seed. Test: `EntryPointTests.testDeleteSleep`.
- `home-long-name`: `--seed long-name`. The home screen with "Maximiliana Rosalind Pepperpot is awake" and the gear. No gallery page: check that the whole name shows, with no ellipsis. Test: `EntryPointTests.testHomeLongName`.
- `delete-child-long-name`: `--seed long-name`. Opens Edit child and taps "Delete Maximiliana Rosalind Pepperpot". No gallery page: check that the title, the body, and the button show the whole name, with no ellipsis. Test: `EntryPointTests.testDeleteChildLongName`.
- `charts`: `--seed week --now 2026-11-08T19:30:00+01:00`. Taps "Charts". "Mila's week", "Mon 2 – Sun 8 Nov", "12 h 09 m", "range 11–14 h", "4 of 7 days", "bed ~19:45 · up ~06:30", and seven bars over the band: in range, too little, in range, in range, too little, in range, too much. The timeline "When Mila slept" with seven rows. Page `charts/week.html`. Test: `EntryPointTests.testCharts`.
- `charts-today`: `--seed week-today --now 2026-11-11T10:00:00+01:00`. Taps "Charts". "Mon 9 – Sun 15 Nov", "11 h 27 m", "1 of 2 days", "bed ~19:50 · up ~06:30", a green bar, a red bar, a striped "so far" bar for Wednesday, "so far" in the legend, and a grey next arrow. The timeline "When Mila slept" with rows for Monday to Wednesday. Page `charts/week-today.html`. Test: `EntryPointTests.testChartsToday`.
- `charts-empty`: `--seed week --now 2026-11-11T10:00:00+01:00`. Taps Noah, then "Charts". "Noah's week", "Mon 9 – Sun 15 Nov", "–" in both cards, "range 10–13 h", "no sleeps yet", "No sleeps this week", "Add a sleep", and a grey next arrow. Page `charts/empty.html`. Test: `EntryPointTests.testChartsEmpty`.
- `day-sheet`: `--seed week --now 2026-11-08T19:30:00+01:00`. Taps "Charts", then Tuesday's bar. The day sheet "Tuesday 3 Nov", "10 h 12 m slept in total", "Too little", the night "20:54 → 06:12" with "9 h 18 m", the nap "13:30 → 14:24" with "54 m", and "+ Add a sleep to this day". Page `charts/day-sheet.html`. Test: `EntryPointTests.testDaySheet`.
- `day-sheet-today`: `--seed week-today --now 2026-11-11T10:00:00+01:00`. Taps "Charts", then Wednesday's striped bar. "Wednesday 11 Nov", "10 h 50 m slept so far", the pale "So far" pill, the night "19:50 → 06:40", and "+ Add a sleep to this day". Page `charts/day-sheet-today.html`. Test: `EntryPointTests.testDaySheetToday`.
- `day-sheet-empty`: `--seed week --now 2026-11-08T19:30:00+01:00`. Taps Noah, "Charts", then Monday's empty row. "Monday 2 Nov", "No sleeps logged", no pill, and "+ Add a sleep to this day", over Noah's week with a grey previous arrow and "0 of 1 day". Page `charts/day-sheet-empty.html`. Test: `EntryPointTests.testDaySheetEmpty`.
- `what-to-try`: `--seed week --now 2026-11-08T19:30:00+01:00`. Taps "Charts" and scrolls to the end. The card "What to try" with "Mila's bedtime moved around by about 40 minutes this week." and, in bold, "Try a fixed bedtime between 19:10 and 19:40.", the three general tips, and the doctor line. Page `charts/what-to-try.html`. Test: `EntryPointTests.testWhatToTry`.
- `what-to-try-keep-logging`: `--seed week-today --now 2026-11-11T10:00:00+01:00`. Taps "Charts" and scrolls to the end. The card "What to try" with "Keep logging. With sleeps on 4 days of the week, Nap Time shows what to try for Mila." and, in bold, "2 of 4 days so far.", the three general tips, the doctor line, and "Add a sleep from earlier". Page `charts/keep-logging.html`. Test: `EntryPointTests.testWhatToTryKeepLogging`.
- `settings`: `--seed family`. Taps the gear. Settings with Mila "1 year · 11–14 h", Noah "4 years · 10–13 h", "Add a child", "Not shared yet", "Your partner sees and logs the same children and sleeps.", and "Invite your partner". Page `settings/default.html`. Test: `EntryPointTests.testSettings`.
- `settings-shared`: `--seed shared`. Taps the gear. "Shared with Sam", "You both see and log the same children and sleeps.", and "Manage sharing", with no join date. Page `settings/shared.html`. Test: `EntryPointTests.testSettingsShared`.
- `settings-invited`: `--seed invited`. Taps the gear. "Invite sent", "Waiting for your partner to open the link.", and "Manage sharing". Page `settings/invited.html`. Test: `EntryPointTests.testSettingsInvited`.
- `settings-partner`: `--seed partner`. Taps the gear. "Shared with you by Alex", the rows Mila, Noah, and Lou, Lou with "2 years · 11–14 h" and "Only on this phone", and "Manage sharing". Lou's avatar has the colour of position 3, as Mila's. Page `settings/partner.html`. Test: `EntryPointTests.testSettingsPartner`.
- `settings-no-icloud`: `--seed no-icloud`. Taps the gear. "Not shared yet", "Sign in to iCloud in the iPhone Settings to share with your partner.", and no button below the card. Page `settings/no-icloud.html`. Test: `EntryPointTests.testSettingsNoICloud`.
- `joining`: `--seed joining`. The app opens on "Joining the family…" with "This takes a few seconds." and a still spinner on the day sky. Page `family/joining.html`. Test: `EntryPointTests.testJoining`.
- `joined`: `--seed joined`. The app opens on "You joined the family" with Mila's avatar, "You now see and log Mila and Noah, together with your partner.", and "Start". Page `family/joined.html`. Test: `EntryPointTests.testJoined`.
- `live-activity`: no launch. The night card of the sleep timer for the running sleep of the seed `sleeping`, rendered with `ImageRenderer` (ADR 0003) and paused at `2026-06-22T04:10:14+02:00`: Mila's avatar "M", "Mila is sleeping", "8:28:14", "since 19:42", and "Awake", in the night colours. Page `live-activity/lock-screen.html` (the card only). Test: `EntryPointTests.testLiveActivity`.
- `live-activity-nap`: no launch. The nap card of the sleep timer for the running sleep of the seed `napping`, rendered with `ImageRenderer` and paused at `2026-06-21T13:50:12+02:00`: "Mila is sleeping", "45:12", "since 13:05", and "Awake", in the day colours. Page `live-activity/nap.html` (the card only). Test: `EntryPointTests.testLiveActivityNap`.
- `dynamic-island`: no launch. The compact, the minimal, and the expanded Dynamic Island for the seed `sleeping`, rendered with `ImageRenderer` and paused at `2026-06-22T04:10:14+02:00`: compact with the moon and "8:28:14", minimal with the moon, expanded with the avatar, "Mila is sleeping", "8:28:14", "since 19:42", and "Awake". Page `live-activity/dynamic-island.html`. Test: `EntryPointTests.testDynamicIsland`.

## Add an entry point

1. In `NapTimeUITests`, add a test that launches the app with `AppDriver.launch(seed:)` (and `--now` or `--seed` if the screen needs them), opens the screen, and calls `attachScreenshot(_:to:)` with the entry point name. The seeds are the raw values of Core's `Seed`, such as `none`, `family`, `long-name`, `sleeping`, `week`, `shared`, `partner`, and `joined`. For a view that a UI test cannot open, render it with `ImageRenderer`, and add its source file to the `NapTimeUITests` sources in `project.yml`.
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

When the `Changes` job skipped the `Screenshots` run, because the PR changes only skip-list paths (ADR 0003), it prints `SKIPPED: Screenshots did not run for <sha>, because the PR changes no app code` and exits 0. There are no screenshots then. A ticket with the `ui` label changes app code, so for it, treat `SKIPPED` as a fail.

## Look at the screenshots

Open each PNG in `build/evidence/<sha>/` with the Read tool, and check that it shows what the ticket says. A PNG that exists but shows the wrong screen is a fail.

## Result

Return pass or fail, the output of the script, and the paths of the PNG files.
