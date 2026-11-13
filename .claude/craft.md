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
