# Craft config

| Key | Value |
|---|---|
| Linear team | `CRAFT` |
| Linear project | `NapTime` |
| GitHub repo | `vanoostrum/nap-time` |
| Base branch | `main` |
| Required CI checks | `Core (Linux)`, `App (iOS)`, `Screenshots` |
| Verify skill | `verify` |
| App driver skill | `drive-app` |

## Standing notes

Notes that apply to every ticket.

- The cloud agents run on Linux, with no Xcode and no simulator. They prove app code through CI, and screens through the `Screenshots` artifact.
- A `skipped` `Screenshots` check counts as green on a PR that changes only skip-list paths (ADR 0003).
- A ticket that changes the Core Data model only adds entities or optional attributes. Its PR body says that Theo must deploy the CloudKit schema before the next release.
