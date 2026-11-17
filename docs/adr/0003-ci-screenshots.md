# Agents prove screens with CI simulator screenshots in test mode

The agents have no simulator, and in one-shot mode no merge gate shows the screens to the owner. So the UI test target `NapTimeUITests` drives the app in test mode on CI and saves one screenshot per entry point to the `screenshots` artifact. Test mode makes every run the same: an in-memory store with seeded data, a fixed clock, and a fixed location, with CloudKit and notifications off. Views that a UI test cannot open, such as the Live Activity and the Dynamic Island, are rendered to PNG with `ImageRenderer` in the same artifact.

The `Screenshots` job pushes the PNG files to the branch `screenshots/<branch>`, in the folder `<head sha>/`, and also uploads the `screenshots` artifact. The cloud agents cannot reach the artifact host, so they read the screenshots from the branch. Each run replaces the branch.
