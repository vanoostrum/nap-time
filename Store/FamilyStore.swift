import Core
import CoreData
import Foundation

/// The family store could not be set up.
public enum FamilyStoreError: Error, Equatable, CustomStringConvertible {
  /// The app found no container for the App Group, for example in an unsigned build.
  case noAppGroupContainer(groupIdentifier: String)
  /// The Core Data model is missing from the `NapTimeStore` bundle.
  case modelNotFound

  public var description: String {
    switch self {
    case .noAppGroupContainer(let groupIdentifier):
      "No App Group container for \(groupIdentifier)"
    case .modelNotFound:
      "The NapTime Core Data model is missing from the NapTimeStore bundle"
    }
  }
}

/// The family store: Core Data with `NSPersistentCloudKitContainer`, in the App Group container.
///
/// The app looks up the App Group container URL and passes it in, so this type needs no entitlements.
public enum FamilyStore {
  public static let appGroupIdentifier = "group.nl.clearblocks.naptime"
  public static let cloudKitContainerIdentifier = "iCloud.nl.clearblocks.naptime"
  public static let modelName = "NapTime"
  public static let storeFileName = "NapTime.sqlite"

  /// The store description for a mode.
  ///
  /// - Test mode: an in-memory store with no CloudKit options.
  /// - The normal mode: a SQLite file under `appGroupContainerURL`, synced to the CloudKit container.
  ///   Throws `FamilyStoreError.noAppGroupContainer` when the URL is `nil`.
  public static func storeDescription(
    for mode: AppMode,
    appGroupContainerURL: URL?
  ) throws(FamilyStoreError) -> NSPersistentStoreDescription {
    if mode.usesInMemoryStore {
      let description = NSPersistentStoreDescription()
      description.type = NSInMemoryStoreType
      description.cloudKitContainerOptions = nil
      return description
    }
    guard let appGroupContainerURL else {
      throw .noAppGroupContainer(groupIdentifier: appGroupIdentifier)
    }
    let url =
      appGroupContainerURL
      .appending(path: "Library/Application Support", directoryHint: .isDirectory)
      .appending(path: storeFileName, directoryHint: .notDirectory)
    let description = NSPersistentStoreDescription(url: url)
    description.type = NSSQLiteStoreType
    description.shouldAddStoreAsynchronously = true
    description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
    description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    if mode.isCloudKitEnabled {
      description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
        containerIdentifier: cloudKitContainerIdentifier)
    }
    return description
  }

  /// Loads the family store with the given description.
  @MainActor
  public static func load(_ description: NSPersistentStoreDescription) async throws -> NSPersistentCloudKitContainer {
    guard let model = managedObjectModel else { throw FamilyStoreError.modelNotFound }
    let container = NSPersistentCloudKitContainer(name: modelName, managedObjectModel: model)
    container.persistentStoreDescriptions = [description]
    if let directory = description.url?.deletingLastPathComponent(), description.type == NSSQLiteStoreType {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      container.loadPersistentStores { _, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
    container.viewContext.automaticallyMergesChangesFromParent = true
    return container
  }

  /// The compiled model, loaded once from this framework's bundle.
  @MainActor private static let managedObjectModel: NSManagedObjectModel? = {
    let bundle = Bundle(for: BundleToken.self)
    guard let url = bundle.url(forResource: modelName, withExtension: "momd") else { return nil }
    return NSManagedObjectModel(contentsOf: url)
  }()
}

private final class BundleToken {}
