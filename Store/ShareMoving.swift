import CloudKit
import CoreData
import Foundation

/// The sharing seam of `FamilyStore`: whether the family share exists, whether an object is in it, and moving
/// objects into it. The store tests use their own seam through `@testable import NapTimeStore`.
@MainActor
protocol ShareMoving: AnyObject {
  /// This phone owns a family share.
  var hasShare: Bool { get }
  func isInShare(_ object: NSManagedObject) -> Bool
  func moveIntoShare(_ objects: [NSManagedObject]) async throws
  /// Test mode only: the children and sleeps of a seed with a share start in the share.
  func seedInShare(_ ids: [UUID])
}

/// The normal mode: the family share of `NSPersistentCloudKitContainer` in the private store.
@MainActor
final class CloudKitShareMoving: ShareMoving {
  private let container: NSPersistentCloudKitContainer
  private let privateStore: NSPersistentStore

  init(container: NSPersistentCloudKitContainer, privateStore: NSPersistentStore) {
    self.container = container
    self.privateStore = privateStore
  }

  var hasShare: Bool { (try? container.fetchShares(in: privateStore))?.isEmpty == false }

  func isInShare(_ object: NSManagedObject) -> Bool {
    (try? container.fetchShares(matching: [object.objectID]))?.isEmpty == false
  }

  func moveIntoShare(_ objects: [NSManagedObject]) async throws {
    guard let share = try container.fetchShares(in: privateStore).first else { return }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      container.share(objects, to: share) { _, _, _, error in
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
      }
    }
  }

  func seedInShare(_ ids: [UUID]) {}
}

/// Test mode in the app: every object counts as in the share, so the app never calls `share(_:to:)`.
@MainActor
final class EverythingInShare: ShareMoving {
  var hasShare: Bool { true }
  func isInShare(_ object: NSManagedObject) -> Bool { true }
  func moveIntoShare(_ objects: [NSManagedObject]) async throws {}
  func seedInShare(_ ids: [UUID]) {}
}
