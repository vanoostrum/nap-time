import CloudKit
import Core
import CoreData
import Foundation
import OSLog
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
  /// The Core save rule refuses the sleep for this reason.
  case sleepRefused(SleepProblem)
  /// A store of the container did not load.
  case storeNotLoaded
  /// Sharing needs CloudKit, which test mode does not use.
  case sharingNeedsCloudKit
  /// The family has no share, and this phone cannot make one.
  case noShare

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
    case .sleepRefused(let problem):
      "The sleep cannot be saved: \(problem)"
    case .storeNotLoaded:
      "A store of the family store did not load"
    case .sharingNeedsCloudKit:
      "Sharing needs iCloud, which test mode does not use"
    case .noShare:
      "The family has no share"
    }
  }
}

/// The family store: Core Data with `NSPersistentCloudKitContainer`, in the App Group container.
///
/// It loads two stores (ADR 0005): the private store, and the shared store that holds the family of someone else
/// after this phone joined it. A new child goes into the family: on the owner's phone into the family share, on the
/// partner's phone into the shared store. A sleep goes into the store of its child. The children that the partner
/// added before joining stay in the private store, only on this phone.
///
/// The app looks up the App Group container URL and passes it in, so this type needs no entitlements.
@MainActor @Observable
public final class FamilyStore {
  public nonisolated static let appGroupIdentifier = "group.nl.clearblocks.naptime"
  public nonisolated static let cloudKitContainerIdentifier = "iCloud.nl.clearblocks.naptime"
  public nonisolated static let modelName = "NapTime"
  public nonisolated static let storeFileName = "NapTime.sqlite"
  public nonisolated static let sharedStoreFileName = "NapTime-shared.sqlite"
  /// The title of the family share in the iCloud sharing sheet.
  public nonisolated static let shareTitle = "Nap Time family"

  /// The children: the family children first, in the order they were added, then the children only on this phone,
  /// in the order they were added.
  public private(set) var children: [Child] = []

  /// The sleeps of all children, newest first.
  public private(set) var sleeps: [Sleep] = []

  /// How this phone shares the family. In test mode, the seed sets it.
  public private(set) var sharing = FamilySharing.notShared

  /// The ids of the children in the private store while the phone is `joined`: they are only on this phone.
  /// On any other phone it is empty.
  public private(set) var onlyOnThisPhone: Set<Child.ID> = []

  /// The children in the shared store, in the order they were added: the family that this phone joined.
  public private(set) var sharedStoreChildren: [Child] = []

  /// Runs after each change that this phone writes: each save of a child or a sleep (also the merge save), each
  /// move into the share, the writes after `acceptShare(_:)`, and each change of `sharing`. The app sets it once,
  /// to reconcile the sleep timers and to plan the nudges.
  @ObservationIgnored public var onSave: (() -> Void)?

  public let container: NSPersistentCloudKitContainer
  private let privateStore: NSPersistentStore
  private let sharedStore: NSPersistentStore
  private let mode: AppMode

  /// The app clock: the real time in the normal mode, `TestEnvironment.now` in test mode.
  @ObservationIgnored private let now: () -> Date
  @ObservationIgnored private let shareMoving: any ShareMoving
  /// The latest run of `processStoreChange`. Each run waits for the run before it.
  @ObservationIgnored private var run: Task<Void, Never>?
  @ObservationIgnored private var observers: [any NSObjectProtocol] = []

  private init(
    container: NSPersistentCloudKitContainer, privateStore: NSPersistentStore, sharedStore: NSPersistentStore,
    mode: AppMode, shareMoving: any ShareMoving
  ) {
    self.container = container
    self.privateStore = privateStore
    self.sharedStore = sharedStore
    self.mode = mode
    self.shareMoving = shareMoving
    if case .test(let environment) = mode {
      let now = environment.now
      self.now = { now }
    } else {
      self.now = { Date() }
    }
  }

  /// The store descriptions for a mode: the private store first, then the shared store.
  ///
  /// - Test mode: two in-memory stores with no CloudKit options.
  /// - The normal mode: `NapTime.sqlite` and `NapTime-shared.sqlite` under `appGroupContainerURL`, synced to the
  ///   CloudKit container, the second with `databaseScope = .shared`. Both track history and post remote changes.
  ///   Throws `FamilyStoreError.noAppGroupContainer` when the URL is `nil`.
  public nonisolated static func storeDescriptions(
    for mode: AppMode,
    appGroupContainerURL: URL?
  ) throws(FamilyStoreError) -> [NSPersistentStoreDescription] {
    if mode.usesInMemoryStore {
      return [storeFileName, sharedStoreFileName].map { name in
        // In-memory stores never touch the file, but each store needs its own URL.
        let description = NSPersistentStoreDescription(url: URL(filePath: "/dev/null").appending(path: name))
        description.type = NSInMemoryStoreType
        description.cloudKitContainerOptions = nil
        return description
      }
    }
    guard let appGroupContainerURL else {
      throw .noAppGroupContainer(groupIdentifier: appGroupIdentifier)
    }
    let directory = appGroupContainerURL.appending(path: "Library/Application Support", directoryHint: .isDirectory)
    return [(storeFileName, CKDatabase.Scope.private), (sharedStoreFileName, .shared)].map { name, scope in
      let description = NSPersistentStoreDescription(url: directory.appending(path: name, directoryHint: .notDirectory))
      description.type = NSSQLiteStoreType
      description.shouldAddStoreAsynchronously = true
      description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
      description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
      if mode.isCloudKitEnabled {
        let options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerIdentifier)
        options.databaseScope = scope
        description.cloudKitContainerOptions = options
      }
      return description
    }
  }

  /// Loads the family store for a mode. In test mode it adds the children and sleeps of the seed, with the photo
  /// that `seedPhoto` gives, and takes `FamilySharing` from the seed. It then merges overlapping sleeps and moves
  /// the family into the share, as on every store change.
  public static func load(
    _ mode: AppMode, appGroupContainerURL: URL? = nil, seedPhoto: (SeedChild) -> Data? = { _ in nil }
  ) async throws -> FamilyStore {
    try await load(mode, appGroupContainerURL: appGroupContainerURL, seedPhoto: seedPhoto, shareMoving: nil)
  }

  /// `load`, with a sharing seam for the store tests. `nil` uses the seam of the mode.
  static func load(
    _ mode: AppMode, appGroupContainerURL: URL?, seedPhoto: (SeedChild) -> Data?, shareMoving: (any ShareMoving)?
  ) async throws -> FamilyStore {
    guard let model = managedObjectModel else { throw FamilyStoreError.modelNotFound }
    let descriptions = try storeDescriptions(for: mode, appGroupContainerURL: appGroupContainerURL)
    let container = NSPersistentCloudKitContainer(name: modelName, managedObjectModel: model)
    container.persistentStoreDescriptions = descriptions
    for description in descriptions where description.type == NSSQLiteStoreType {
      if let directory = description.url?.deletingLastPathComponent() {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      }
    }
    try await loadStores(of: container, count: descriptions.count)
    let coordinator = container.persistentStoreCoordinator
    guard let privateURL = descriptions[0].url, let sharedURL = descriptions[1].url,
      let privateStore = coordinator.persistentStore(for: privateURL),
      let sharedStore = coordinator.persistentStore(for: sharedURL)
    else { throw FamilyStoreError.storeNotLoaded }
    container.viewContext.automaticallyMergesChangesFromParent = true
    container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

    let seam: any ShareMoving =
      shareMoving
      ?? (mode.isCloudKitEnabled
        ? CloudKitShareMoving(container: container, privateStore: privateStore) : EverythingInShare())
    let store = FamilyStore(
      container: container, privateStore: privateStore, sharedStore: sharedStore, mode: mode, shareMoving: seam)
    if case .test(let environment) = mode {
      store.sharing = environment.seed.sharing
      try await store.add(environment.seed, photo: seedPhoto)
    } else {
      store.observeChanges()
    }
    await store.processStoreChange()
    return store
  }

  /// Loads every store of the container. `loadPersistentStores` calls back once per store.
  private static func loadStores(of container: NSPersistentCloudKitContainer, count: Int) async throws {
    let calls = LoadCalls(count: count)
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      container.loadPersistentStores { _, error in
        switch calls.record(error) {
        case .wait: break
        case .done(nil): continuation.resume()
        case .done(let error?): continuation.resume(throwing: error)
        }
      }
    }
  }

  /// Adds a child at the end of the family children. The photo follows `ChildPhoto`.
  ///
  /// On a phone that joined a family, the child goes into the shared store. Else it goes into the private store,
  /// and on the owner's phone the next store change moves it into the family share.
  @discardableResult
  public func add(name: String, birthDate: BirthDate, photo: Data?) async throws -> Child {
    let stored = try await Self.prepared(photo)
    let id = UUID()
    try insertChild(
      id: id, name: name, birthDate: birthDate, photo: stored, addedAt: Date(),
      into: sharing.isJoined ? sharedStore : privateStore)
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

  /// Starts a running sleep for a child, in the store of the child. Does nothing when that child already has a
  /// running sleep, so a double tap makes one sleep.
  public func startSleep(childID: Child.ID, at start: Date, kind: SleepKind) throws {
    let child = try childObject(childID)
    guard try runningSleepObject(of: childID) == nil else { return }
    try insertSleep(id: UUID(), child: child, start: start, end: nil, kind: kind)
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

  /// Adds a new sleep in the store of its child, or replaces the sleep with the same id in the store that holds it.
  /// Throws `FamilyStoreError.sleepRefused`, and saves nothing, when the Core save rule finds a problem at the app
  /// clock's now.
  public func saveSleep(_ sleep: Sleep) throws {
    if let problem = SleepSaveRule.problem(of: sleep, among: sleeps(of: sleep.childID), now: now()) {
      throw FamilyStoreError.sleepRefused(problem)
    }
    if let saved = try sleepObject(sleep.id) {
      saved.setValue(sleep.start, forKey: SleepKey.start)
      saved.setValue(sleep.end, forKey: SleepKey.end)
      saved.setValue(sleep.kind.rawValue, forKey: SleepKey.kind)
    } else {
      try insertSleep(
        id: sleep.id, child: try childObject(sleep.childID), start: sleep.start, end: sleep.end, kind: sleep.kind)
    }
    try save()
  }

  /// Deletes the sleep with this id from the store that holds it. Does nothing for an unknown id.
  public func deleteSleep(id: Sleep.ID) throws {
    guard let object = try sleepObject(id) else { return }
    context.delete(object)
    try save()
  }

  /// The sleep is in the private store while the phone is `joined`, so it is only on this phone.
  public func isOnlyOnThisPhone(sleepID: Sleep.ID) -> Bool {
    guard sharing.isJoined, let object = try? sleepObject(sleepID) else { return false }
    return object.objectID.persistentStore == privateStore
  }

  // MARK: Sharing

  /// The family share: the share that this phone joined, the share that this phone owns, or a new share of every
  /// child. On a phone that joined a family it never makes one. Test mode has no CloudKit, so it always throws.
  public func share() async throws -> CKShare {
    guard mode.isCloudKitEnabled else { throw FamilyStoreError.sharingNeedsCloudKit }
    if let joined = try container.fetchShares(in: sharedStore).first { return joined }
    if let owned = try container.fetchShares(in: privateStore).first { return owned }
    guard !sharing.isJoined else { throw FamilyStoreError.noShare }
    let objects = try fetchObjects(Key.entity, in: privateStore)
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      container.share(objects, to: nil) { _, _, _, error in
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
      }
    }
    guard let made = try container.fetchShares(in: privateStore).first else { throw FamilyStoreError.noShare }
    made[CKShare.SystemFieldKey.title] = Self.shareTitle
    made.publicPermission = .none
    return made
  }

  /// Joins the family of an opened invite: accepts the share into the shared store, then updates `sharing`.
  public func acceptShare(_ metadata: CKShare.Metadata) async throws {
    guard mode.isCloudKitEnabled else { throw FamilyStoreError.sharingNeedsCloudKit }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
      }
    }
    await processStoreChange()
    onSave?()
  }

  /// Saves a change that the iCloud sharing sheet made to the share, such as a new participant.
  public func persistUpdatedShare(_ share: CKShare) async {
    let store = sharing.isJoined ? sharedStore : privateStore
    do {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
        container.persistUpdatedShare(share, in: store) { _, error in
          if let error { continuation.resume(throwing: error) } else { continuation.resume() }
        }
      }
    } catch {
      Self.logger.error("Saving the share failed: \(String(describing: error), privacy: .public)")
    }
    await processStoreChange()
  }

  /// After the iCloud sharing sheet stopped sharing. On a phone that joined a family, the partner left it: the
  /// family's children and sleeps leave this phone. On the owner's phone, the children stay.
  public func didStopSharing() async {
    if sharing.isJoined, let share = try? container.fetchShares(in: sharedStore).first {
      do {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
          container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: sharedStore) { _, error in
            if let error { continuation.resume(throwing: error) } else { continuation.resume() }
          }
        }
      } catch {
        Self.logger.error("Leaving the family failed: \(String(describing: error), privacy: .public)")
      }
    }
    await processStoreChange()
  }

  /// Updates `sharing`, the merge of overlapping sleeps, and the moves into the share, as on a store change.
  /// The app calls it when the iCloud sharing sheet closes.
  public func refresh() async {
    await processStoreChange()
  }

  // MARK: Store changes

  /// Runs the work of a store change and waits for it: `sharing` in the normal mode, the merge of overlapping
  /// sleeps, then the moves into the share. A store change is each save of the view context, and each
  /// `NSPersistentStoreRemoteChange` in the normal mode. In-memory stores post no remote change, so the store
  /// tests call this to stand in for one.
  func processStoreChange() async {
    storeChanged()
    await run?.value
  }

  /// Starts the work of a store change after the run before it.
  private func storeChanged() {
    let previous = run
    run = Task { [weak self] in
      await previous?.value
      await self?.runStoreChange()
    }
  }

  private func runStoreChange() async {
    if mode.isCloudKitEnabled {
      await refreshSharing()
    }
    reload()
    mergeOverlappingSleeps()
    await moveIntoShare()
  }

  /// Merges the overlapping sleeps of each child with the Core rule, in one context save. The merge does not use
  /// `saveSleep` or its save rule, so a merged sleep can be longer than 24 hours.
  private func mergeOverlappingSleeps() {
    let merges = SleepMerge.merges(of: sleeps)
    guard !merges.isEmpty else { return }
    do {
      for merge in merges {
        guard let kept = try sleepObject(merge.kept.id) else { continue }
        kept.setValue(merge.kept.start, forKey: SleepKey.start)
        kept.setValue(merge.kept.end, forKey: SleepKey.end)
        for id in merge.deleted {
          if let object = try sleepObject(id) { context.delete(object) }
        }
      }
      try save()
    } catch {
      context.rollback()
      Self.logger.error("Merging sleeps failed: \(String(describing: error), privacy: .public)")
    }
  }

  /// While this phone owns a share, moves every child and sleep that is not in the share yet into it. A move that
  /// fails waits for the next store change.
  private func moveIntoShare() async {
    guard !sharing.isJoined, shareMoving.hasShare else { return }
    do {
      let objects = (try fetchObjects(Key.entity, in: privateStore) + fetchObjects(SleepKey.entity, in: privateStore))
        .filter { !shareMoving.isInShare($0) }
      guard !objects.isEmpty else { return }
      try await shareMoving.moveIntoShare(objects)
      reload()
      onSave?()
    } catch {
      Self.logger.error("Moving into the share failed: \(String(describing: error), privacy: .public)")
    }
  }

  /// `sharing` from the shares in both stores and the iCloud account.
  private func refreshSharing() async {
    let hasAccount = await Self.hasICloudAccount()
    let share =
      (try? container.fetchShares(in: sharedStore).first) ?? (try? container.fetchShares(in: privateStore).first)
    let facts = ShareFacts(hasICloudAccount: hasAccount, share: share.map(Self.facts(of:)))
    let new = FamilySharing(facts)
    if new != sharing {
      sharing = new
      onSave?()
    }
  }

  private static func facts(of share: CKShare) -> ShareFacts.Share {
    let isOwnedByMe = share.currentUserParticipant?.role == .owner
    let participants = share.participants.filter { $0.role != .owner }.map { participant in
      ShareFacts.Participant(
        accepted: participant.acceptanceStatus == .accepted,
        givenName: participant.userIdentity.nameComponents?.givenName)
    }
    return ShareFacts.Share(
      isOwnedByMe: isOwnedByMe, ownerGivenName: share.owner.userIdentity.nameComponents?.givenName,
      participants: participants)
  }

  private static func hasICloudAccount() async -> Bool {
    await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
      CKContainer(identifier: cloudKitContainerIdentifier).accountStatus { status, _ in
        continuation.resume(returning: status == .available)
      }
    }
  }

  /// In the normal mode, a remote change and an iCloud account change are store changes too.
  private func observeChanges() {
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(
        forName: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.storeChanged() }
      })
    observers.append(
      center.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.storeChanged() }
      })
  }

  // MARK: Test seams

  /// Writes a sleep as a CloudKit import does: on a background context, into the store of its child. It is not a
  /// store change: it skips the save rule of `saveSleep`.
  func insertAsIfSynced(_ sleep: Sleep) throws {
    let childID = try childObject(sleep.childID).objectID
    let background = container.newBackgroundContext()
    try background.performAndWait {
      let child = try background.existingObject(with: childID)
      let object = NSEntityDescription.insertNewObject(forEntityName: SleepKey.entity, into: background)
      if let store = childID.persistentStore { background.assign(object, to: store) }
      object.setValue(sleep.id, forKey: Key.identifier)
      object.setValue(sleep.start, forKey: SleepKey.start)
      object.setValue(sleep.end, forKey: SleepKey.end)
      object.setValue(sleep.kind.rawValue, forKey: SleepKey.kind)
      object.setValue(child, forKey: SleepKey.child)
      try background.save()
    }
  }

  /// Adds the children and sleeps of a seed with no rules, so a seed can hold overlapping sleeps. On a `joined`
  /// phone the family children go into the shared store. With a share, they start in the share.
  private func add(_ seed: Seed, photo: (SeedChild) -> Data?) async throws {
    let start = Date(timeIntervalSince1970: 0)
    var objects: [NSManagedObject] = []
    var stores: [NSPersistentStore] = []
    for (index, child) in seed.children.enumerated() {
      let stored = try await Self.prepared(photo(child))
      let store = sharing.isJoined && !child.onlyOnThisPhone ? sharedStore : privateStore
      stores.append(store)
      objects.append(
        try insertChild(
          id: UUID(), name: child.name, birthDate: child.birthDate, photo: stored,
          addedAt: start.addingTimeInterval(TimeInterval(index)), into: store))
    }
    var ids = objects.compactMap { $0.value(forKey: Key.identifier) as? UUID }
    for sleep in seed.sleeps {
      let id = UUID()
      try insertSleep(
        id: id, child: objects[sleep.childIndex], in: stores[sleep.childIndex], start: sleep.start, end: sleep.end,
        kind: sleep.kind)
      ids.append(id)
    }
    if context.hasChanges { try context.save() }
    switch seed.sharing {
    case .shared, .invited: shareMoving.seedInShare(ids)
    case .notShared, .joined, .noICloud: break
    }
    reload()
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

  private static let logger = Logger(subsystem: "nl.clearblocks.naptime", category: "FamilyStore")

  private var context: NSManagedObjectContext { container.viewContext }

  private static func prepared(_ photo: Data?) async throws -> Data? {
    guard let photo else { return nil }
    return try await ChildPhoto.prepared(photo)
  }

  private func entity(_ name: String) throws -> NSEntityDescription {
    guard let entity = container.managedObjectModel.entitiesByName[name] else {
      throw FamilyStoreError.modelNotFound
    }
    return entity
  }

  @discardableResult
  private func insertChild(
    id: UUID, name: String, birthDate: BirthDate, photo: Data?, addedAt: Date, into store: NSPersistentStore
  ) throws -> NSManagedObject {
    let object = NSManagedObject(entity: try entity(Key.entity), insertInto: context)
    context.assign(object, to: store)
    object.setValue(id, forKey: Key.identifier)
    object.setValue(addedAt, forKey: Key.addedAt)
    write(name: name, birthDate: birthDate, to: object)
    if let photo { object.setValue(photo, forKey: Key.photo) }
    return object
  }

  /// Inserts a sleep into the store of its child: a relationship cannot cross stores. `store` is the store of an
  /// unsaved child; a saved child gives its own store.
  private func insertSleep(
    id: UUID, child: NSManagedObject, in store: NSPersistentStore? = nil, start: Date, end: Date?, kind: SleepKind
  ) throws {
    let object = NSManagedObject(entity: try entity(SleepKey.entity), insertInto: context)
    context.assign(object, to: store ?? child.objectID.persistentStore ?? privateStore)
    object.setValue(id, forKey: Key.identifier)
    object.setValue(start, forKey: SleepKey.start)
    object.setValue(end, forKey: SleepKey.end)
    object.setValue(kind.rawValue, forKey: SleepKey.kind)
    object.setValue(child, forKey: SleepKey.child)
  }

  private func fetchObjects(_ entity: String, in store: NSPersistentStore) throws -> [NSManagedObject] {
    let request = NSFetchRequest<NSManagedObject>(entityName: entity)
    request.affectedStores = [store]
    return try context.fetch(request)
  }

  private func runningSleepObject(of childID: Child.ID) throws -> NSManagedObject? {
    let request = NSFetchRequest<NSManagedObject>(entityName: SleepKey.entity)
    request.predicate = NSPredicate(
      format: "%K.%K == %@ AND %K == nil", SleepKey.child, Key.identifier, childID as NSUUID, SleepKey.end)
    request.fetchLimit = 1
    return try context.fetch(request).first
  }

  private func sleepObject(_ id: Sleep.ID) throws -> NSManagedObject? {
    let request = NSFetchRequest<NSManagedObject>(entityName: SleepKey.entity)
    request.predicate = NSPredicate(format: "%K == %@", Key.identifier, id as NSUUID)
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

  /// Saves the view context. A save is a store change, and calls `onSave`.
  private func save() throws {
    if context.hasChanges { try context.save() }
    reload()
    storeChanged()
    onSave?()
  }

  private func reload() {
    let request = NSFetchRequest<NSManagedObject>(entityName: Key.entity)
    request.sortDescriptors = [NSSortDescriptor(key: Key.addedAt, ascending: true)]
    let objects = (try? context.fetch(request)) ?? []
    var family: [Child] = []
    var onlyHere: [Child] = []
    var inSharedStore: [Child] = []
    for object in objects {
      guard let id = object.value(forKey: Key.identifier) as? UUID,
        let year = object.value(forKey: Key.birthYear) as? Int,
        let month = object.value(forKey: Key.birthMonth) as? Int,
        let day = object.value(forKey: Key.birthDay) as? Int,
        let birthDate = BirthDate(year: year, month: month, day: day)
      else { continue }
      let child = Child(
        id: id, name: object.value(forKey: Key.name) as? String ?? "", birthDate: birthDate,
        photo: object.value(forKey: Key.photo) as? Data)
      let store = object.objectID.persistentStore
      if store == sharedStore { inSharedStore.append(child) }
      if sharing.isJoined && store == privateStore {
        onlyHere.append(child)
      } else {
        family.append(child)
      }
    }
    children = family + onlyHere
    onlyOnThisPhone = Set(onlyHere.map(\.id))
    sharedStoreChildren = inSharedStore

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

/// Counts the calls of `loadPersistentStores`, which calls back once per store, maybe on another thread.
private final class LoadCalls: @unchecked Sendable {
  enum Result {
    case wait
    case done((any Error)?)
  }

  private let lock = NSLock()
  private let count: Int
  private var calls = 0
  private var error: (any Error)?

  init(count: Int) {
    self.count = count
  }

  func record(_ error: (any Error)?) -> Result {
    lock.withLock {
      calls += 1
      if self.error == nil { self.error = error }
      return calls == count ? .done(self.error) : .wait
    }
  }
}
