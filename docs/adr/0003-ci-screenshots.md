# Agents prove screens with CI simulator screenshots in test mode

The agents have no simulator, and in one-shot mode no merge gate shows the screens to the owner. So the UI test target `NapTimeUITests` drives the app in test mode on CI and saves one screenshot per entry point to the `screenshots` artifact. Test mode makes every run the same: in-memory storage with seeded data and a fixed clock, and with CloudKit, notifications, animations, and the other `…Enabled` flags of `AppMode` false. Views that a UI test cannot open, such as the Live Activity and the Dynamic Island, are rendered to PNG with `ImageRenderer` in the same artifact.

The `Screenshots` job pushes the PNG files to the branch `screenshots/<branch>`, in the folder `<head sha>/`, and also uploads the `screenshots` artifact. The cloud agents cannot reach the artifact host, so they read the screenshots from the branch. Each run replaces the branch.

To keep the job short, it builds for testing while the simulator boots, and runs a failed UI test once more in the same run. A test that passes only on the retry passes the job with a warning. A Linux job first checks the changed paths of a PR. When the PR changes only docs, the design gallery, craft files, Markdown, or scripts that the job does not run, the `Screenshots` job is skipped, and GitHub counts it as passed. A push to `main` always runs it.

<!-- TEMPORARY CRAFT-64 proof: a docs-only change. Never merged. -->
