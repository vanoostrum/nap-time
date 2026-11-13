# XcodeGen generates the Xcode project

The cloud agents run on Linux and cannot open Xcode, so they cannot safely edit `.pbxproj` files. `project.yml` is the source of the Xcode project, and `xcodegen generate` creates `NapTime.xcodeproj`, which is not committed. An agent adds a file or a target by editing `project.yml`.
