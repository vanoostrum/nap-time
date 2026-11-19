import Core
import SwiftUI
import UIKit

@main
struct NapTimeApp: App {
  /// Gives the scenes the scene delegate that receives opened invites.
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  private let mode: AppMode

  init() {
    let arguments = ProcessInfo.processInfo.arguments
    do {
      mode = try LaunchArguments.parse(arguments)
    } catch {
      // A bad launch argument would give wrong screenshots, so stop with the reason.
      fatalError(error.description)
    }
    // Test mode turns off animations: UIKit ones (sheets, pickers, the keyboard) here,
    // and SwiftUI ones with the transaction below. Normal mode keeps them.
    if !mode.areAnimationsEnabled {
      UIView.setAnimationsEnabled(false)
    }
    // The store, the sleep timers, and "Awake" start here, outside a view, so a background launch has them too.
    AppModel.shared.launch(mode, initializesCloudKitSchema: LaunchArguments.initializesCloudKitSchema(arguments))
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
