import Core
import CoreData
import Foundation
import Observation

/// The family store could not be set up, or could not take a change.
public enum FamilyStoreError: Error, Equatable, CustomStringConvertible {
  /// The app found no container for the App Group, for example in an unsigned build.
  case noAppGroupContainer(groupIdentifier: String)
  /// The Core Data model is missing from the `NapTimeStore` bundle.
  case modelNotFound
  /// The photo data is not an image that the store can read.
  case unreadablePhoto
  /// No child has this id.
  case childNotFound

  public var description: String {
    switch self {
    case .noAppGroupContainer(let groupIdentifier):
      "No App Group container for \(groupIdentifier)"
    case .modelNotFound:
      "The NapTime Core Data model is missing from the NapTimeStore bundle"
    case .unreadablePhoto:
      "The photo is not an image that Nap Time can read"
    case .childNotFound:
      "The child is not in the family store"
    }
  }
}

/// The family store: Core Data with `NSPersistentCloudKitContainer`, in the App Group container.
///
/// The app looks up the App Group container URL and passes it in, so this type needs no entitlements.
@MainActor @Observable
public final class FamilyStore {
  public nonisolated static let appGroupIdentifier = "group.nl.clearblocks.naptime"
  public nonisolated static let cloudKitContainerIdentifier = "iCloud.nl.clearblocks.naptime"
  public nonisolated static let modelName = "NapTime"
  public nonisolated static let storeFileName = "NapTime.sqlite"

  /// The children, in the order they were added.
  public private(set) var children: [Child] = []

  /// The sleeps of all children, newest first.
  public private(set) var sleeps: [Sleep] = []

  public let container: NSPersistentCloudKitContainer

  private init(container: NSPersistentCloudKitContainer) {
    self.container = container
    reload()
  }

  /// The store description for a mode.
  ///
  /// - Test mode: an in-memory store with no CloudKit options.
  /// - The normal mode: a SQLite file under `appGroupContainerURL`, synced to the CloudKit container.
  ///   Throws `FamilyStoreError.noAppGroupContainer` when the URL is `nil`.
  public nonisolated static func storeDescription(
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
  public static func load(_ description: NSPersistentStoreDescription) async throws -> FamilyStore {
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
    return FamilyStore(container: container)
  }

  /// Adds a child at the end of `children`. The photo follows `ChildPhoto`.
  @discardableResult
  public func add(name: String, birthDate: BirthDate, photo: Data?) async throws -> Child {
    let stored = try await Self.prepared(photo)
    let object = NSManagedObject(entity: try childEntity(), insertInto: context)
    let id = UUID()
    object.setValue(id, forKey: Key.identifier)
    object.setValue(Date(), forKey: Key.addedAt)
    write(name: name, birthDate: birthDate, to: object)
    if let stored { object.setValue(stored, forKey: Key.photo) }
    try save()
    return Child(id: id, name: name, birthDate: birthDate, photo: stored)
  }

  /// Changes a child's name and birthdate. A new photo replaces the old one; `nil` keeps the old one.
  public func update(_ id: Child.ID, name: String, birthDate: BirthDate, newPhoto: Data?) async throws {
    let stored = try await Self.prepared(newPhoto)
    let object = try childObject(id)
    write(name: name, birthDate: birthDate, to: object)
    if let stored { object.setValue(stored, forKey: Key.photo) }
    try save()
  }

  /// Deletes a child and all of the child's sleeps.
  public func delete(_ id: Child.ID) throws {
    context.delete(try childObject(id))
    try save()
  }

  // MARK: Sleeps

  /// The sleeps of the child with this id, newest first.
  public func sleeps(of childID: Child.ID) -> [Sleep] {
    sleeps.filter { $0.childID == childID }
  }

  /// Starts a running sleep for a child. Does nothing when that child already has a running sleep,
  /// so a double tap makes one sleep.
  public func startSleep(childID: Child.ID, at start: Date, kind: SleepKind) throws {
    let child = try childObject(childID)
    guard try runningSleepObject(of: childID) == nil else { return }
    let object = NSManagedObject(entity: try entity(SleepKey.entity), insertInto: context)
    object.setValue(UUID(), forKey: Key.identifier)
    object.setValue(start, forKey: SleepKey.start)
    object.setValue(kind.rawValue, forKey: SleepKey.kind)
    object.setValue(child, forKey: SleepKey.child)
    try save()
  }

  /// Ends a child's running sleep. A sleep shorter than `Sleep.shortest` is deleted instead.
  /// Does nothing when no sleep runs.
  public func endSleep(childID: Child.ID, at end: Date) throws {
    guard let object = try runningSleepObject(of: childID) else { return }
    let start = object.value(forKey: SleepKey.start) as? Date ?? end
    if end.timeIntervalSince(start) < Sleep.shortest {
      context.delete(object)
    } else {
      object.setValue(end, forKey: SleepKey.end)
    }
    try save()
  }

  // MARK: Private

  private enum Key {
    static let entity = "Child"
    static let identifier = "identifier"
    static let name = "name"
    static let birthYear = "birthYear"
    static let birthMonth = "birthMonth"
    static let birthDay = "birthDay"
    static let photo = "photo"
    static let addedAt = "addedAt"
  }

  private enum SleepKey {
    static let entity = "Sleep"
    static let start = "start"
    static let end = "end"
    static let kind = "kind"
    static let child = "child"
  }

  private var context: NSManagedObjectContext { container.viewContext }

  private static func prepared(_ photo: Data?) async throws -> Data? {
    guard let photo else { return nil }
    return try await ChildPhoto.prepared(photo)
  }

  private func childEntity() throws -> NSEntityDescription {
    try entity(Key.entity)
  }

  private func entity(_ name: String) throws -> NSEntityDescription {
    guard let entity = container.managedObjectModel.entitiesByName[name] else {
      throw FamilyStoreError.modelNotFound
    }
    return entity
  }

  private func runningSleepObject(of childID: Child.ID) throws -> NSManagedObject? {
    let request = NSFetchRequest<NSManagedObject>(entityName: SleepKey.entity)
    request.predicate = NSPredicate(
      format: "%K.%K == %@ AND %K == nil", SleepKey.child, Key.identifier, childID as NSUUID, SleepKey.end)
    request.fetchLimit = 1
    return try context.fetch(request).first
  }

  private func write(name: String, birthDate: BirthDate, to object: NSManagedObject) {
    object.setValue(name, forKey: Key.name)
    object.setValue(Int32(birthDate.year), forKey: Key.birthYear)
    object.setValue(Int16(birthDate.month), forKey: Key.birthMonth)
    object.setValue(Int16(birthDate.day), forKey: Key.birthDay)
  }

  private func childObject(_ id: Child.ID) throws -> NSManagedObject {
    let request = NSFetchRequest<NSManagedObject>(entityName: Key.entity)
    request.predicate = NSPredicate(format: "%K == %@", Key.identifier, id as NSUUID)
    request.fetchLimit = 1
    guard let object = try context.fetch(request).first else { throw FamilyStoreError.childNotFound }
    return object
  }

  private func save() throws {
    if context.hasChanges { try context.save() }
    reload()
  }

  private func reload() {
    let request = NSFetchRequest<NSManagedObject>(entityName: Key.entity)
    request.sortDescriptors = [NSSortDescriptor(key: Key.addedAt, ascending: true)]
    let objects = (try? context.fetch(request)) ?? []
    children = objects.compactMap { object in
      guard let id = object.value(forKey: Key.identifier) as? UUID,
        let year = object.value(forKey: Key.birthYear) as? Int,
        let month = object.value(forKey: Key.birthMonth) as? Int,
        let day = object.value(forKey: Key.birthDay) as? Int,
        let birthDate = BirthDate(year: year, month: month, day: day)
      else { return nil }
      return Child(
        id: id, name: object.value(forKey: Key.name) as? String ?? "", birthDate: birthDate,
        photo: object.value(forKey: Key.photo) as? Data)
    }

    let sleepRequest = NSFetchRequest<NSManagedObject>(entityName: SleepKey.entity)
    sleepRequest.sortDescriptors = [NSSortDescriptor(key: SleepKey.start, ascending: false)]
    let sleepObjects = (try? context.fetch(sleepRequest)) ?? []
    sleeps = sleepObjects.compactMap { object in
      guard let id = object.value(forKey: Key.identifier) as? UUID,
        let childID = (object.value(forKey: SleepKey.child) as? NSManagedObject)?.value(forKey: Key.identifier)
          as? UUID,
        let start = object.value(forKey: SleepKey.start) as? Date
      else { return nil }
      let kind = (object.value(forKey: SleepKey.kind) as? String).flatMap(SleepKind.init(rawValue:)) ?? .nap
      return Sleep(
        id: id, childID: childID, start: start, end: object.value(forKey: SleepKey.end) as? Date, kind: kind)
    }
  }

  /// The compiled model, loaded once from this framework's bundle.
  private static let managedObjectModel: NSManagedObjectModel? = {
    let bundle = Bundle(for: FamilyStore.self)
    guard let url = bundle.url(forResource: modelName, withExtension: "momd") else { return nil }
    return NSManagedObjectModel(contentsOf: url)
  }()
}
