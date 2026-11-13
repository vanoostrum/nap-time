# Core Data with NSPersistentCloudKitContainer, not SwiftData

Both parents must see and edit one family's data from two Apple IDs, with no server. That needs a CloudKit share (`CKShare`) on the shared database. Core Data with `NSPersistentCloudKitContainer` supports the private and shared databases and `CKShare`. SwiftData's CloudKit sync supports only the private database, and we found no Apple source that says iOS 27 changes this (checked 2026-11-13). So the family store is Core Data with `NSPersistentCloudKitContainer`, in the App Group container.

## Consequences

- The store code imports Core Data, so it cannot live in Core. It lives in a framework target, `NapTimeStore`, defined in `project.yml`. The app `NapTime` and the widget extension `NapTimeWidget` both link it, so the widget and the "awake" App Intent open the same family store in the App Group. `NapTimeStore` depends on Core. Core gets plain value types, and `NapTimeStore` maps them to and from managed objects.
- Sharing between two Apple IDs cannot be tested on the simulator. The first real test is on TestFlight, after v1.
