import CloudKit
import NapTimeStore
import OSLog
import UIKit

/// Shows the iCloud sharing sheet (`UICloudSharingController`) for the family share, to invite the partner or to
/// manage sharing. It is system UI, so it is presented from UIKit over the screen on top.
@MainActor
final class CloudSharing: NSObject {
  static let shared = CloudSharing()

  /// The store of the open sheet. The sheet is modal, so there is one at a time.
  private var store: FamilyStore?
  private static let logger = Logger(subsystem: "nl.clearblocks.naptime", category: "CloudSharing")

  /// Opens the sheet for a private, read-write share titled "Nap Time family".
  func present(_ share: CKShare, store: FamilyStore) {
    self.store = store
    let controller = UICloudSharingController(
      share: share, container: CKContainer(identifier: FamilyStore.cloudKitContainerIdentifier))
    controller.availablePermissions = [.allowPrivate, .allowReadWrite]
    controller.delegate = self
    controller.presentationController?.delegate = self
    topViewController()?.present(controller, animated: true)
  }

  private func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    var top = scene?.keyWindow?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  /// The sheet closed: Settings shows the new sharing state.
  private func refresh() {
    guard let store else { return }
    Task { await store.refresh() }
  }
}

extension CloudSharing: @preconcurrency UICloudSharingControllerDelegate {
  func itemTitle(for csc: UICloudSharingController) -> String? {
    FamilyStore.shareTitle
  }

  func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: any Error) {
    Self.logger.error("The sharing sheet failed: \(String(describing: error), privacy: .public)")
    refresh()
  }

  func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
    guard let store, let share = csc.share else { return refresh() }
    Task { await store.persistUpdatedShare(share) }
  }

  func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
    guard let store else { return }
    Task { await store.didStopSharing() }
  }
}

extension CloudSharing: @preconcurrency UIAdaptivePresentationControllerDelegate {
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    refresh()
  }
}
