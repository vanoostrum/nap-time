import CloudKit
import Observation
import UIKit

/// Gives each window scene the scene delegate, so the app gets the invites that the partner opens.
final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    configuration.delegateClass = SceneDelegate.self
    return configuration
  }
}

/// Hands each opened invite to `OpenedInvites`: while the app runs, and on a cold launch from the link.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let metadata = connectionOptions.cloudKitShareMetadata {
      OpenedInvites.shared.metadata = metadata
    }
  }

  func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
    OpenedInvites.shared.metadata = metadata
  }
}

/// The invite that the partner opened, held until the family store has loaded and the app handles it.
@MainActor @Observable
final class OpenedInvites {
  static let shared = OpenedInvites()

  var metadata: CKShare.Metadata?
}
