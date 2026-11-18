import Core
import SwiftUI

@main
struct NapTimeApp: App {
  /// Gives the scenes the scene delegate that receives opened invites.
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
