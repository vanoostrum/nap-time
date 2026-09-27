# Architecture

> Placeholder. Agents and humans fill this in as the app grows. Keep it short and current.

## Overview
_What the app does, and its main user flows._

## Modules
- **NapTime (app target)**: SwiftUI views and app entry point.
- **Core (Swift package, `Packages/Core`)**: pure, platform-independent logic (formatting, models, rules). It's testable with `swift test`.

## Data & persistence
_Storage choice (e.g. SwiftData), schema, migrations._

## State management
_How views get and mutate state._

## Platform integrations
_Notifications, background tasks, HealthKit, widgets, Live Activities, …_

## Testing strategy
- Logic lives in `Core`, which has unit tests (Swift Testing).
- The app target has thin view/integration tests.
- CI runs build, tests and SwiftLint on every PR.

## Release
fastlane `beta` lane → TestFlight on every push to `main`. See `.agents/skills/project/release-testflight`.
