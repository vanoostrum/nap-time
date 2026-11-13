# All pure logic lives in a Foundation-only Core package

The cloud agents cannot compile code that imports SwiftUI, UIKit, Core Data, CloudKit, ActivityKit, or WidgetKit. So all pure logic, such as age ranges, week stats, the night or nap guess, the bedtime window, the sun times, and the nudge rules, lives in `Packages/Core`, which imports Foundation only and builds and tests on Linux. The app and widget targets stay thin and call Core.
