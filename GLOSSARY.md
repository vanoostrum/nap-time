# Nap Time

An iOS app for parents to track their child's sleep. This file holds the project's own terms. The v1 plan adds the product terms.

## Language

**Core**:
The local Swift package `Packages/Core`, which holds all pure logic and imports Foundation only.
_Avoid_: domain module, model layer

**Test mode**:
The app mode that CI starts with launch arguments: an in-memory store with seeded data, a fixed clock, and a fixed location, with CloudKit and notifications off.
_Avoid_: demo mode, mock mode, UI test mode

**Screenshot evidence**:
The PNG files in the `screenshots` artifact of the `Screenshots` CI job, one per entry point. They are how an agent proves a screen.
_Avoid_: snapshots, golden images

**Family store**:
The on-device store in the App Group container, which the app, the widget, and the App Intents share, and which syncs to iCloud.
_Avoid_: database, cache
