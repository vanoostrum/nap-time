import Core
import SwiftUI
import UIKit

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
    // Test mode turns off animations: UIKit ones (sheets, pickers, the keyboard) here,
    // and SwiftUI ones with the transaction below. Normal mode keeps them.
    if !mode.areAnimationsEnabled {
      UIView.setAnimationsEnabled(false)
    }
  }

  var body: some Scene {
    WindowGroup {
      let animationsEnabled = mode.areAnimationsEnabled
      RootView(mode: mode)
        .transaction { transaction in
          if !animationsEnabled {
            transaction.disablesAnimations = true
            transaction.animation = nil
          }
        }
    }
  }
}
