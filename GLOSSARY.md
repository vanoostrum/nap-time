# Nap Time

An iOS app for parents to track their child's sleep. This file holds the project's own terms. The v1 plan adds the product terms.

## Language

**Core**:
The local Swift package `Packages/Core`, which holds all pure logic and imports Foundation only.
_Avoid_: domain module, model layer

**Test mode**:
The app mode that CI starts with launch arguments: an in-memory store with the data of a named seed and a fixed clock, with CloudKit and notifications off.
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

### The week

**Sleep day**:
The time from 18:00 on one date to 18:00 on the next, which is 23 or 25 hours on the day the clock changes. It carries the name of the second date, so a night counts for the morning it ends in.
_Avoid_: calendar day, 24-hour period

**Week**:
Seven sleep days, from Monday to Sunday.
_Avoid_: 7 days, rolling week

**Counted day**:
A sleep day that has ended and has at least one sleep. The average and "In range" use only counted days.
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
A 30-minute span of bedtimes that the app suggests, from the usual wake-up time, the naps, and the recommended range.
_Avoid_: ideal bedtime, bedtime target

**What to try**:
The card on the charts screen with one tip from the child's own week, a few general tips, and a note to ask a doctor.
_Avoid_: advice, insight, recommendation

**Nudge**:
A notification that reminds a parent to log: no sleep by the usual bedtime plus one hour, or a sleep that runs longer than 14 hours.
_Avoid_: alert, reminder, push

### Screens

**Sky**:
The background of the home screen. It shows day, sunset, night, or sunrise from the sun times of Utrecht, and night while the selected child's night runs.
_Avoid_: theme, mode, background

**Timeline**:
The chart "When <name> slept": one row per sleep day of the week, from 18:00 to 18:00, with a bar for each sleep.
_Avoid_: actogram, sleep graph

**Day sheet**:
The sheet that slides up when a parent taps a sleep day on the charts, as a bar or a timeline row. It lists the sleeps that cross into that day, with an edit button for each, and "Add a sleep to this day".
_Avoid_: day details, popup, modal

**Sleep timer**:
The Lock Screen and Dynamic Island view of a running sleep, with an "Awake" button.
_Avoid_: Live Activity view, widget
