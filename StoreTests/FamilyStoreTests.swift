import Core
import CoreData
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import NapTimeStore

@Suite struct FamilyStoreTests {
  private let testMode = AppMode.test(.standard)

  @Test @MainActor func testModeStoreLoadsTwoInMemoryStoresWithoutCloudKit() async throws {
    let descriptions = try FamilyStore.storeDescriptions(for: testMode, appGroupContainerURL: nil)
    #expect(descriptions.count == 2)
    #expect(descriptions.allSatisfy { $0.cloudKitContainerOptions == nil })

    let store = try await FamilyStore.load(testMode)

    let stores = store.container.persistentStoreCoordinator.persistentStores
    #expect(stores.count == 2)
    #expect(stores.allSatisfy { $0.type == NSInMemoryStoreType })
    #expect(store.container.persistentStoreDescriptions.allSatisfy { $0.cloudKitContainerOptions == nil })
    #expect(store.children.isEmpty)
    #expect(store.sharing == .notShared)
  }

  @Test func normalModeHasAPrivateAndASharedStoreUnderTheAppGroupContainer() throws {
    let groupURL = URL(filePath: "/tmp/group.nl.clearblocks.naptime-test", directoryHint: .isDirectory)

    let descriptions = try FamilyStore.storeDescriptions(for: .normal, appGroupContainerURL: groupURL)

    #expect(descriptions.count == 2)
    #expect(descriptions.map { $0.url?.lastPathComponent } == ["NapTime.sqlite", "NapTime-shared.sqlite"])
    #expect(descriptions.map { $0.cloudKitContainerOptions?.databaseScope } == [.private, .shared])
    for description in descriptions {
      let storeURL = try #require(description.url)
      #expect(storeURL.standardizedFileURL.path().hasPrefix(groupURL.standardizedFileURL.path()))
      #expect(description.type == NSSQLiteStoreType)
      #expect(description.cloudKitContainerOptions?.containerIdentifier == "iCloud.nl.clearblocks.naptime")
      #expect(description.options[NSPersistentHistoryTrackingKey] as? NSNumber == true)
      #expect(description.options[NSPersistentStoreRemoteChangeNotificationPostOptionKey] as? NSNumber == true)
    }
  }

  @Test func normalModeWithoutAppGroupContainerNamesTheGroup() {
    #expect(throws: FamilyStoreError.noAppGroupContainer(groupIdentifier: "group.nl.clearblocks.naptime")) {
      try FamilyStore.storeDescriptions(for: .normal, appGroupContainerURL: nil)
    }
    let error = FamilyStoreError.noAppGroupContainer(groupIdentifier: FamilyStore.appGroupIdentifier)
    #expect(error.description.contains("group.nl.clearblocks.naptime"))
  }

  // MARK: Children

  @Test @MainActor func addUpdateAndDeleteKeepTheOrderTheyWereAddedIn() async throws {
    let store = try await inMemoryStore()
    let photo = try image(width: 1024, height: 768, type: .png)

    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    let noah = try await store.add(name: "Noah", birthDate: day(2022, 2, 10), photo: photo)
    let lou = try await store.add(name: "Lou", birthDate: day(2026, 1, 5), photo: nil)
    #expect(store.children.map(\.name) == ["Mila", "Noah", "Lou"])
    #expect(store.children.map(\.id) == [mila.id, noah.id, lou.id])
    #expect(store.children.map(\.birthDate) == [day(2025, 3, 12), day(2022, 2, 10), day(2026, 1, 5)])
    #expect(store.children[0].photo == nil)
    #expect(store.children[1].photo == photo)

    try await store.update(mila.id, name: "Mia", birthDate: day(2025, 3, 13), newPhoto: nil)
    #expect(store.children.map(\.name) == ["Mia", "Noah", "Lou"])
    #expect(store.children[0].birthDate == day(2025, 3, 13))

    try await store.update(noah.id, name: "Noah", birthDate: day(2022, 2, 10), newPhoto: nil)
    #expect(store.children[1].photo == photo)

    try store.delete(noah.id)
    #expect(store.children.map(\.name) == ["Mia", "Lou"])

    try store.delete(mila.id)
    try store.delete(lou.id)
    #expect(store.children.isEmpty)
  }

  @Test @MainActor func aPhotoOf1024PixelsOrSmallerKeepsItsBytes() async throws {
    let store = try await inMemoryStore()
    let photo = try image(width: 1024, height: 768, type: .png)

    let child = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: photo)

    #expect(child.photo == photo)
    #expect(store.children.first?.photo == photo)
  }

  @Test @MainActor func aLargerPhotoIsScaledTo1024PixelsAsJPEG() async throws {
    let store = try await inMemoryStore()
    let photo = try image(width: 8000, height: 6000, type: .png)

    try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: photo)

    let stored = try #require(store.children.first?.photo)
    #expect(Array(stored.prefix(2)) == [0xFF, 0xD8])
    let size = try pixelSize(of: stored)
    #expect(size.width == 1024)
    #expect(size.height == 768)
  }

  @Test @MainActor func updateWithANewPhotoScalesItToo() async throws {
    let store = try await inMemoryStore()
    let child = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)

    try await store.update(
      child.id, name: "Mila", birthDate: day(2025, 3, 12), newPhoto: try image(width: 3000, height: 4000, type: .png))

    let size = try pixelSize(of: try #require(store.children.first?.photo))
    #expect(size.width == 768)
    #expect(size.height == 1024)
  }

  @Test @MainActor func updateKeepsABirthdateOlderThanSevenYears() async throws {
    let store = try await inMemoryStore()
    let birthDate = day(2019, 6, 20)  // 7 years and 1 day before 21 June 2026
    let child = try await store.add(name: "Mila", birthDate: birthDate, photo: nil)

    try await store.update(child.id, name: "Mia", birthDate: birthDate, newPhoto: nil)

    #expect(store.children.first?.name == "Mia")
    #expect(store.children.first?.birthDate == birthDate)
  }

  @Test @MainActor func dataThatIsNotAnImageIsRefused() async throws {
    let store = try await inMemoryStore()
    await #expect(throws: FamilyStoreError.unreadablePhoto) {
      try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: Data("not an image".utf8))
    }
    #expect(store.children.isEmpty)
  }

  // MARK: Sleeps

  @Test @MainActor func startThenEndKeepsTheSleepWithAllItsFields() async throws {
    let store = try await inMemoryStore()
    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    let start = date("2026-06-20T19:45:00+02:00")
    let end = date("2026-06-21T06:55:00+02:00")

    try store.startSleep(childID: mila.id, at: start, kind: .night)
    let running = try #require(store.sleeps(of: mila.id).first)
    #expect(running.isRunning)
    #expect(running.end == nil)

    try store.endSleep(childID: mila.id, at: end)

    let sleeps = store.sleeps(of: mila.id)
    #expect(sleeps.count == 1)
    #expect(sleeps[0].id == running.id)
    #expect(sleeps[0].childID == mila.id)
    #expect(sleeps[0].start == start)
    #expect(sleeps[0].end == end)
    #expect(sleeps[0].kind == .night)
  }

  @Test @MainActor func sleepsAreListedNewestFirst() async throws {
    let store = try await inMemoryStore()
    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    try store.startSleep(childID: mila.id, at: date("2026-06-20T19:45:00+02:00"), kind: .night)
    try store.endSleep(childID: mila.id, at: date("2026-06-21T06:55:00+02:00"))
    try store.startSleep(childID: mila.id, at: date("2026-06-21T13:05:00+02:00"), kind: .nap)

    let starts = store.sleeps(of: mila.id).map(\.start)
    #expect(starts == [date("2026-06-21T13:05:00+02:00"), date("2026-06-20T19:45:00+02:00")])
  }

  @Test @MainActor func anEnd25HoursAfterTheStartKeepsTheSleep() async throws {
    let store = try await inMemoryStore()
    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    let start = date("2026-06-20T19:45:00+02:00")

    try store.startSleep(childID: mila.id, at: start, kind: .night)
    try store.endSleep(childID: mila.id, at: start.addingTimeInterval(25 * 3600))

    #expect(store.sleeps(of: mila.id).map(\.end) == [start.addingTimeInterval(25 * 3600)])
  }

  @Test @MainActor func aSecondStartWhileASleepRunsAddsNoSleep() async throws {
    let store = try await inMemoryStore()
    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    let start = date("2026-06-21T13:05:00+02:00")

    try store.startSleep(childID: mila.id, at: start, kind: .nap)
    try store.startSleep(childID: mila.id, at: start.addingTimeInterval(1), kind: .nap)

    #expect(store.sleeps(of: mila.id).map(\.start) == [start])
  }

  @Test @MainActor func anEndUnderOneMinuteDeletesTheSleep() async throws {
    let store = try await inMemoryStore()
    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    let start = date("2026-06-21T10:00:00+02:00")

    try store.startSleep(childID: mila.id, at: start, kind: .nap)
    try store.endSleep(childID: mila.id, at: start.addingTimeInterval(59))
    #expect(store.sleeps(of: mila.id).isEmpty)

    try store.startSleep(childID: mila.id, at: start, kind: .nap)
    try store.endSleep(childID: mila.id, at: start.addingTimeInterval(60))
    #expect(store.sleeps(of: mila.id).count == 1)
  }

  @Test @MainActor func anEndWithNoRunningSleepDoesNothing() async throws {
    let store = try await inMemoryStore()
    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)

    try store.endSleep(childID: mila.id, at: date("2026-06-21T10:00:00+02:00"))
    #expect(store.sleeps(of: mila.id).isEmpty)

    try store.startSleep(childID: mila.id, at: date("2026-06-20T19:45:00+02:00"), kind: .night)
    try store.endSleep(childID: mila.id, at: date("2026-06-21T06:55:00+02:00"))
    try store.endSleep(childID: mila.id, at: date("2026-06-21T10:00:00+02:00"))
    #expect(store.sleeps(of: mila.id).map(\.end) == [date("2026-06-21T06:55:00+02:00")])
  }

  @Test @MainActor func twoChildrenEachHaveTheirOwnRunningSleep() async throws {
    let store = try await inMemoryStore()
    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    let noah = try await store.add(name: "Noah", birthDate: day(2022, 2, 10), photo: nil)

    try store.startSleep(childID: mila.id, at: date("2026-06-21T13:05:00+02:00"), kind: .nap)
    try store.startSleep(childID: noah.id, at: date("2026-06-21T13:20:00+02:00"), kind: .nap)
    #expect(store.sleeps(of: mila.id).map(\.isRunning) == [true])
    #expect(store.sleeps(of: noah.id).map(\.isRunning) == [true])

    try store.endSleep(childID: noah.id, at: date("2026-06-21T14:00:00+02:00"))
    #expect(store.sleeps(of: mila.id).map(\.isRunning) == [true])
    #expect(store.sleeps(of: noah.id).map(\.isRunning) == [false])
  }

  @Test @MainActor func deletingAChildDeletesItsSleeps() async throws {
    let store = try await inMemoryStore()
    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    let noah = try await store.add(name: "Noah", birthDate: day(2022, 2, 10), photo: nil)
    try store.startSleep(childID: mila.id, at: date("2026-06-20T19:45:00+02:00"), kind: .night)
    try store.endSleep(childID: mila.id, at: date("2026-06-21T06:55:00+02:00"))
    try store.startSleep(childID: mila.id, at: date("2026-06-21T13:05:00+02:00"), kind: .nap)
    try store.startSleep(childID: noah.id, at: date("2026-06-21T13:20:00+02:00"), kind: .nap)

    try store.delete(mila.id)

    #expect(store.sleeps(of: mila.id).isEmpty)
    #expect(store.sleeps.map(\.childID) == [noah.id])
    let request = NSFetchRequest<NSManagedObject>(entityName: "Sleep")
    #expect(try store.container.viewContext.count(for: request) == 1)
  }

  @Test @MainActor func startForAChildThatIsNotThereThrows() async throws {
    let store = try await inMemoryStore()
    #expect(throws: FamilyStoreError.childNotFound) {
      try store.startSleep(childID: UUID(), at: date("2026-06-21T10:00:00+02:00"), kind: .nap)
    }
  }

  // MARK: Edit sleeps

  @Test @MainActor func saveSleepAddsANewSleep() async throws {
    let store = try await inMemoryStore(now: date("2026-06-21T10:00:00+02:00"))
    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    let nap = Sleep(
      id: UUID(), childID: mila.id, start: date("2026-06-21T09:00:00+02:00"), end: date("2026-06-21T10:00:00+02:00"),
      kind: .nap)

    try store.saveSleep(nap)

    #expect(store.sleeps(of: mila.id) == [nap])
  }

  @Test @MainActor func saveSleepReplacesTheSleepWithTheSameID() async throws {
    let store = try await inMemoryStore(now: date("2026-06-21T10:00:00+02:00"))
    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    try store.startSleep(childID: mila.id, at: date("2026-06-20T19:45:00+02:00"), kind: .night)
    try store.endSleep(childID: mila.id, at: date("2026-06-21T06:55:00+02:00"))
    var night = try #require(store.sleeps(of: mila.id).first)

    night.start = date("2026-06-20T20:10:00+02:00")
    night.end = date("2026-06-21T06:30:00+02:00")
    night.kind = .nap
    try store.saveSleep(night)

    #expect(store.sleeps(of: mila.id) == [night])
  }

  @Test @MainActor func saveSleepThrowsAndSavesNothingForARefusedSleep() async throws {
    let store = try await inMemoryStore(now: date("2026-06-21T07:30:00+02:00"))
    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    try store.startSleep(childID: mila.id, at: date("2026-06-20T19:45:00+02:00"), kind: .night)
    try store.endSleep(childID: mila.id, at: date("2026-06-21T06:55:00+02:00"))
    let night = try #require(store.sleeps(of: mila.id).first)
    let overlapping = Sleep(
      id: UUID(), childID: mila.id, start: date("2026-06-21T06:30:00+02:00"), end: date("2026-06-21T07:30:00+02:00"),
      kind: .nap)

    #expect(throws: FamilyStoreError.sleepRefused(.overlaps(night))) { try store.saveSleep(overlapping) }
    // The store's clock is 07:30, so 07:35 is in the future.
    let future = Sleep(
      id: UUID(), childID: mila.id, start: date("2026-06-21T07:00:00+02:00"), end: date("2026-06-21T07:35:00+02:00"),
      kind: .nap)
    #expect(throws: FamilyStoreError.sleepRefused(.inTheFuture)) { try store.saveSleep(future) }

    #expect(store.sleeps(of: mila.id) == [night])
  }

  /// Review focus 2: "Woke earlier?" with a wake-up before the start leaves the sleep running.
  @Test @MainActor func aRunningSleepSavedWithAnEndBeforeItsStartKeepsRunning() async throws {
    let store = try await inMemoryStore(now: date("2026-06-21T21:56:00+02:00"))
    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    try store.startSleep(childID: mila.id, at: date("2026-06-21T19:42:00+02:00"), kind: .night)
    let running = try #require(store.sleeps(of: mila.id).first)
    var woke = running
    woke.end = date("2026-06-21T19:30:00+02:00")

    #expect(throws: FamilyStoreError.sleepRefused(.tooShort)) { try store.saveSleep(woke) }

    #expect(store.sleeps(of: mila.id) == [running])
    #expect(store.sleeps(of: mila.id).first?.isRunning == true)
  }

  @Test @MainActor func aRunningSleepSavedWithAnEarlierStartKeepsRunning() async throws {
    let store = try await inMemoryStore(now: date("2026-06-21T21:56:00+02:00"))
    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    try store.startSleep(childID: mila.id, at: date("2026-06-21T19:42:00+02:00"), kind: .night)
    var running = try #require(store.sleeps(of: mila.id).first)

    running.start = date("2026-06-21T19:20:00+02:00")
    try store.saveSleep(running)

    let saved = try #require(store.sleeps(of: mila.id).first)
    #expect(store.sleeps(of: mila.id).count == 1)
    #expect(saved.isRunning)
    #expect(saved.start == date("2026-06-21T19:20:00+02:00"))
  }

  @Test @MainActor func aRunningSleepSavedWithAnEndKeepsTheNewStartAndKind() async throws {
    let store = try await inMemoryStore(now: date("2026-06-21T21:56:00+02:00"))
    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    try store.startSleep(childID: mila.id, at: date("2026-06-21T19:42:00+02:00"), kind: .night)
    var woke = try #require(store.sleeps(of: mila.id).first)

    woke.start = date("2026-06-21T19:20:00+02:00")
    woke.end = date("2026-06-21T21:30:00+02:00")
    woke.kind = .nap
    try store.saveSleep(woke)

    #expect(store.sleeps(of: mila.id) == [woke])
  }

  @Test @MainActor func deleteSleepDeletesItAndAnUnknownIDDoesNothing() async throws {
    let store = try await inMemoryStore(now: date("2026-06-21T10:00:00+02:00"))
    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    try store.startSleep(childID: mila.id, at: date("2026-06-20T19:45:00+02:00"), kind: .night)
    try store.endSleep(childID: mila.id, at: date("2026-06-21T06:55:00+02:00"))
    try store.startSleep(childID: mila.id, at: date("2026-06-21T08:00:00+02:00"), kind: .nap)
    try store.endSleep(childID: mila.id, at: date("2026-06-21T09:00:00+02:00"))
    let sleeps = store.sleeps(of: mila.id)

    try store.deleteSleep(id: UUID())
    #expect(store.sleeps(of: mila.id) == sleeps)

    try store.deleteSleep(id: sleeps[0].id)
    #expect(store.sleeps(of: mila.id) == [sleeps[1]])
    let request = NSFetchRequest<NSManagedObject>(entityName: "Sleep")
    #expect(try store.container.viewContext.count(for: request) == 1)
  }

  // MARK: onSave

  /// Criterion 25 of CRAFT-51: each save of a sleep or a child calls `onSave` once.
  @Test @MainActor func eachSaveOfASleepOrAChildCallsOnSaveOnce() async throws {
    let store = try await inMemoryStore(now: date("2026-06-21T21:56:00+02:00"))
    var calls = 0
    store.onSave = { calls += 1 }

    let mila = try await store.add(name: "Mila", birthDate: day(2025, 3, 12), photo: nil)
    await store.processStoreChange()
    #expect(calls == 1, "add")

    try await store.update(mila.id, name: "Mila", birthDate: day(2025, 3, 13), newPhoto: nil)
    await store.processStoreChange()
    #expect(calls == 2, "update")

    try store.startSleep(childID: mila.id, at: date("2026-06-21T19:42:00+02:00"), kind: .night)
    await store.processStoreChange()
    #expect(calls == 3, "startSleep")

    try store.startSleep(childID: mila.id, at: date("2026-06-21T19:45:00+02:00"), kind: .night)
    await store.processStoreChange()
    #expect(calls == 3, "a second startSleep saves nothing")

    try store.endSleep(childID: mila.id, at: date("2026-06-21T21:00:00+02:00"))
    await store.processStoreChange()
    #expect(calls == 4, "endSleep")

    var sleep = try #require(store.sleeps(of: mila.id).first)
    sleep.start = date("2026-06-21T19:30:00+02:00")
    try store.saveSleep(sleep)
    await store.processStoreChange()
    #expect(calls == 5, "saveSleep")

    try store.deleteSleep(id: sleep.id)
    await store.processStoreChange()
    #expect(calls == 6, "deleteSleep")

    try store.delete(mila.id)
    await store.processStoreChange()
    #expect(calls == 7, "delete")
  }

  /// Criterion 24 of CRAFT-50: the merge save calls `onSave` once.
  @Test @MainActor func mergeSaveCallsOnSaveOnce() async throws {
    let store = try await load(.family, now: "2026-06-22T07:30:00+02:00")
    var calls = 0
    store.onSave = { calls += 1 }
    let mila = try #require(store.children.first { $0.name == "Mila" })
    try store.insertAsIfSynced(
      Sleep(
        id: UUID(), childID: mila.id, start: date("2026-06-21T13:00:00+02:00"),
        end: date("2026-06-21T14:00:00+02:00"), kind: .nap))
    try store.insertAsIfSynced(
      Sleep(
        id: UUID(), childID: mila.id, start: date("2026-06-21T13:30:00+02:00"),
        end: date("2026-06-21T15:00:00+02:00"), kind: .nap))

    await store.processStoreChange()
    await store.processStoreChange()

    let naps = store.sleeps(of: mila.id).filter { $0.kind == .nap }
    #expect(naps.map(\.start) == [date("2026-06-21T13:00:00+02:00")])
    #expect(naps.map(\.end) == [date("2026-06-21T15:00:00+02:00")])
    #expect(calls == 1)
  }

  /// Criterion 24 of CRAFT-50: a placement save and a successful move into the share each call `onSave` once. A
  /// failed move does not.
  @Test @MainActor func moveIntoShareCallsOnSaveOnce() async throws {
    let seam = RecordingShareMoving(failures: 1)
    let store = try await load(.shared, shareMoving: seam)
    var calls = 0
    store.onSave = { calls += 1 }
    let mila = try #require(store.children.first { $0.name == "Mila" })

    try store.startSleep(childID: mila.id, at: date("2026-06-21T09:00:00+02:00"), kind: .nap)
    #expect(calls == 1, "the placement save")
    let sleep = try #require(store.sleeps(of: mila.id).first(where: \.isRunning))

    await store.processStoreChange()

    #expect(seam.attempts == 2, "The first move failed, the second moved the sleep")
    #expect(seam.moved == [sleep.id])
    #expect(calls == 2)
  }

  // MARK: Helpers

  private func date(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: iso)!
  }

  @MainActor private func inMemoryStore(now: Date? = nil) async throws -> FamilyStore {
    let standard = TestEnvironment.standard
    return try await FamilyStore.load(.test(TestEnvironment(now: now ?? standard.now, timeZone: standard.timeZone)))
  }

  private func day(_ year: Int, _ month: Int, _ day: Int) -> BirthDate {
    BirthDate(year: year, month: month, day: day)!
  }

  @MainActor private func load(
    _ seed: Seed, now: String? = nil, shareMoving: (any ShareMoving)? = nil
  ) async throws -> FamilyStore {
    let standard = TestEnvironment.standard
    let environment = TestEnvironment(
      now: now.map(date) ?? standard.now, timeZone: standard.timeZone, seed: seed)
    return try await FamilyStore.load(
      .test(environment), appGroupContainerURL: nil, seedPhoto: { _ in nil }, shareMoving: shareMoving)
  }

  /// A generated image with two colours, encoded as `type`.
  private func image(width: Int, height: Int, type: UTType) throws -> Data {
    let context = try #require(
      CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    context.setFillColor(red: 0.44, green: 0.75, blue: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(red: 1, green: 0.82, blue: 0.25, alpha: 1)
    context.fillEllipse(in: CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
    let cgImage = try #require(context.makeImage())
    let output = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, cgImage, nil)
    #expect(CGImageDestinationFinalize(destination))
    return output as Data
  }

  private func pixelSize(of data: Data) throws -> (width: Int, height: Int) {
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    return (
      try #require(properties[kCGImagePropertyPixelWidth] as? Int),
      try #require(properties[kCGImagePropertyPixelHeight] as? Int)
    )
  }
}
