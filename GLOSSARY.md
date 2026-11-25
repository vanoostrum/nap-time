# Nap Time

An iOS app for parents to track their child's sleep. This file holds the project's own terms. The v1 plan adds the product terms.

## Language

**Core**:
The local Swift package `Packages/Core`, which holds all pure logic and imports Foundation only.
_Avoid_: domain module, model layer

**Test mode**:
The app mode that CI starts with launch arguments: in-memory storage with the data of a named seed and a fixed clock. It turns off what a CI run cannot use or must keep still, such as CloudKit, notifications, and animations. The `…Enabled` flags of `AppMode` list each one.
_Avoid_: demo mode, mock mode, UI test mode

**Screenshot evidence**:
The PNG files that the `Screenshots` CI job saves, one per entry point. The job pushes them to the branch `screenshots/<branch>`, in the folder `<head sha>/`, and uploads them as the `screenshots` artifact. Cloud agents read them from the branch, because they cannot reach the artifact host. They are how an agent proves a screen.
_Avoid_: snapshots, golden images

**Family store**:
The on-device store in the App Group container, which the app, the widget, and the App Intents share, and which syncs to iCloud.
_Avoid_: database, cache

**Entry point**:
A screen or view that `drive-app` expects a screenshot of, such as `home` or `add-child`. Each entry point gives one PNG named after it, in `screenshots/<branch>/<head sha>/`.
_Avoid_: screen ID, route

### Children and sleep

**Child**:
A child in the family, from 0 to 6 years old, with a name, a birthdate, and an optional photo.
_Avoid_: kid, baby, profile, user

**Family**:
The children and sleeps that both parents see and log. One parent owns the family and invites the other.
_Avoid_: household, account, group

**Partner**:
The second parent, who joins the family through an invite from the owner.
_Avoid_: member, guest, co-parent

**Sleep**:
One period in which a child sleeps, from the time the child fell asleep to the time the child woke up. A sleep is a night or a nap.
_Avoid_: session, entry, record, event

**Night**:
A sleep that runs from bedtime to the morning, as one sleep. Wake-ups inside a night are not logged.
_Avoid_: night sleep, overnight

**Nap**:
A sleep that is not a night.
_Avoid_: day sleep, rest

**Running sleep**:
A sleep that has started and has not ended yet.
_Avoid_: active sleep, open sleep, timer

**Main button**:
The big button on Home. While the child is awake, it says "Nap time" from 06:00 to 17:59 and "Sleep time" from 18:00 to 05:59, and a tap starts that kind of sleep now. While a sleep runs, it says "Wake up".
_Avoid_: start button, sleep button

### The week

**Sleep day**:
The time from 18:00 on one date to 18:00 on the next, which is 23 or 25 hours on the day the clock changes. It carries the name of the second date, so a night that starts after 18:00 counts for the morning it ends in. A sleep belongs to the sleep day it starts in, and counts whole there.
_Avoid_: calendar day, 24-hour period

**Week**:
Seven sleep days, from Monday to Sunday.
_Avoid_: 7 days, rolling week

**Counted day**:
A sleep day that has ended, holds no running sleep, and has at least one sleep. The average and "In range" use only counted days.
_Avoid_: logged day, full day

**Recommended range**:
The total hours of sleep per sleep day, naps included, that the guidelines recommend for the child's age.
_Avoid_: target, norm, goal, age range

**In range**:
A sleep day whose total sleep lies inside the child's recommended range. Otherwise it has too little or too much sleep.
_Avoid_: on target, OK day

**Usual bedtime**:
The middle start time of a set of the child's nights: the nights of the shown week on the charts, or of the last 7 days for a nudge.
_Avoid_: average bedtime, typical bedtime

**Usual wake-up time**:
The middle end time of the child's ended nights in the shown week.
_Avoid_: average wake time

**Bedtime window**:
A 30-minute span of bedtimes that the app suggests: the usual wake-up time minus the night the child needs, which is the middle of the recommended range minus the child's naps.
_Avoid_: ideal bedtime, bedtime target

**What to try**:
The card on the charts screen with one tip from the child's shown week, a few general tips, and a note to ask a doctor. It needs 4 counted days in the week; before that, it asks the parent to keep logging.
_Avoid_: advice, insight, recommendation

**Nudge**:
A notification that asks a parent to check one child's log: no sleep logged by the usual bedtime plus one hour, or a sleep that has run for 14 hours. Each phone plans its own nudges.
_Avoid_: alert, reminder, push

### Screens

**Sky**:
The background of the home screen. It shows day, sunset, night, or sunrise from the sun times of Utrecht, also while a sleep runs.
_Avoid_: theme, mode, background

**Timeline**:
The chart "When <name> slept": one row per sleep day of the week, from 18:00 to 18:00, with a bar for each sleep.
_Avoid_: actogram, sleep graph

**Day sheet**:
The sheet that slides up when a parent taps a sleep day on the charts, as a bar or a timeline row. It lists the sleeps that start in that day, with an edit button for each, and "Add a sleep to this day".
_Avoid_: day details, popup, modal

**Sleep timer**:
The Live Activity that counts a running sleep from its start, on the Lock Screen and in the Dynamic Island, with an "Awake" button. Only the phone that tapped "Sleep time" or "Nap time" shows it. A night's timer shows from 04:00.
_Avoid_: Live Activity view, widget, stopwatch, countdown

### Release

**Staging**:
A Debug build that Theo installs from Xcode on his own iPhone. It uses the CloudKit development database. The agents do not reach it.
_Avoid_: dev build, beta

**Production**:
The Release build in TestFlight internal testing, on the phones of Theo and Theo's wife. It uses the CloudKit production database and holds the family's real sleep log.
_Avoid_: live, App Store

**Release**:
One run of the `Release` workflow: it archives `main`, signs it, uploads it to App Store Connect, and tags the commit. Theo starts it by hand and approves it in the GitHub environment `testflight`. A merge to `main` is not a release.
_Avoid_: deploy, ship, publish

**Build number**:
The `CFBundleVersion` of a release: the run number of its `Release` workflow run.
_Avoid_: version, build ID

**Release tag**:
The git tag `release/<build number>` on the commit of each release that uploaded. A run that had the schema check pushes it as an annotated tag whose message holds the line `schema-check: yes`. The schema check of the next release compares the Core Data model with the marked tag that has the highest build number.
_Avoid_: version tag

**Schema deploy**:
Theo's step in the CloudKit Console that copies the development schema to production. It comes before each release that changes the Core Data model.
_Avoid_: migration, schema push
