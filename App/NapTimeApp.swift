import Core
import SwiftUI

@main
struct NapTimeApp: App {
  private let mode: AppMode

  init() {
    do {
      mode = try LaunchArguments.parse(ProcessInfo.processInfo.arguments)
    } catch {
      // A bad launch argument would give wrong screenshots, so stop with the reason.
      fatalError(error.description)
    }
  }

  var body: some Scene {
    WindowGroup {
      RootView(mode: mode)
    }
  }
}
