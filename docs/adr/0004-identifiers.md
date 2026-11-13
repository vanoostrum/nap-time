# Identifiers and the shared App Group

The app uses bundle ID `nl.clearblocks.naptime`, iCloud container `iCloud.nl.clearblocks.naptime`, and App Group `group.nl.clearblocks.naptime`, all on Theo's individual team `2SUL28U5Y7`. The app, the widget, and the "awake" App Intent share the family store through the App Group. Changing these after the first TestFlight build loses the iCloud data, so they are fixed now. The team ID is in `project.yml` as `DEVELOPMENT_TEAM`; it is not a secret.
