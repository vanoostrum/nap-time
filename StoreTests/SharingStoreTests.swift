import Core
import CoreData
import Foundation
import Testing

@testable import NapTimeStore

/// The family store with two in-memory stores: the seeds of sharing, where children and sleeps go, the order of
/// the children, the merge of overlapping sleeps, and the moves into the share.
@Suite struct SharingStoreTests {
  @Test @MainActor func eachSeedSetsItsSharingState() async throws {
    for seed in [
      Seed.family, .shared, .invited, .partner, .noICloud, .joining, .joined, .duplicateRunning, .overlapping,
    ] {
      let store = try await load(seed)
      #expect(store.sharing == seed.sharing, "\(seed)")
    }
  }

  @Test @MainActor func onThePartnerPhoneLouIsOnlyOnThisPhoneAndListedLast() async throws {
    let store = try await load(.partner)

    #expect(store.children.map(\.name) == ["Mila", "Noah", "Lou"])
    let lou = try named("Lou", in: store)
    #expect(store.onlyOnThisPhone == [lou.id])
    #expect(store.sharedStoreChildren.map(\.name) == ["Mila", "Noah"])
  }

  @Test @MainActor func onThePartnerPhoneANewChildGoesIntoTheSharedStore() async throws {
    let store = try await load(.partner)

    let kai = try await store.add(name: "Kai", birthDate: day(2025, 1, 2), photo: nil)

    #expect(!store.onlyOnThisPhone.contains(kai.id))
    #expect(store.children.map(\.name) == ["Mila", "Noah", "Kai", "Lou"])
    #expect(store.sharedStoreChildren.map(\.name) == ["Mila", "Noah", "Kai"])
  }

  @Test @MainActor func onThePartnerPhoneASleepGoesIntoTheStoreOfItsChild() async throws {
    let store = try await load(.partner)
    let mila = try named("Mila", in: store)
    let lou = try named("Lou", in: store)

    try store.startSleep(childID: mila.id, at: date("2026-06-21T09:00:00+02:00"), kind: .nap)
    try store.startSleep(childID: lou.id, at: date("2026-06-21T09:00:00+02:00"), kind: .nap)

    let milas = try #require(running(of: mila, in: store))
    let lous = try #require(running(of: lou, in: store))
    #expect(!store.isOnlyOnThisPhone(sleepID: milas.id))
    #expect(store.isOnlyOnThisPhone(sleepID: lous.id))
  }

  @Test @MainActor func onThePartnerPhoneSaveSleepKeepsEachSleepInTheStoreOfItsChild() async throws {
    let store = try await load(.partner)
    for (name, onlyHere) in [("Mila", false), ("Lou", true)] {
      let child = try named(name, in: store)
      let new = Sleep(
        id: UUID(), childID: child.id, start: date("2026-06-21T08:00:00+02:00"),
        end: date("2026-06-21T09:00:00+02:00"), kind: .nap)

      try store.saveSleep(new)
      #expect(store.isOnlyOnThisPhone(sleepID: new.id) == onlyHere, "new sleep of \(name)")

      var edited = new
      edited.end = date("2026-06-21T09:30:00+02:00")
      try store.saveSleep(edited)
      #expect(store.isOnlyOnThisPhone(sleepID: new.id) == onlyHere, "edited sleep of \(name)")
      #expect(store.sleeps(of: child.id).filter { $0.id == new.id }.map(\.end) == [edited.end])

      try store.deleteSleep(id: new.id)
      #expect(!store.sleeps(of: child.id).contains { $0.id == new.id })
    }
  }

  @Test @MainActor func onTheOwnerPhoneNothingIsOnlyOnThisPhone() async throws {
    let store = try await load(.family)
    let mila = try named("Mila", in: store)

    try store.startSleep(childID: mila.id, at: date("2026-06-21T09:00:00+02:00"), kind: .nap)

    #expect(store.onlyOnThisPhone.isEmpty)
    let running = try #require(running(of: mila, in: store))
    #expect(!store.isOnlyOnThisPhone(sleepID: running.id))
    #expect(store.children.map(\.name) == ["Mila", "Noah"])
  }

  @Test @MainActor func twoRunningSleepsFromTwoPhonesMergeIntoTheEarlierOne() async throws {
    let store = try await load(.duplicateRunning, now: "2026-06-22T07:30:00+02:00")
    let mila = try named("Mila", in: store)

    let running = store.sleeps(of: mila.id).filter(\.isRunning)
    #expect(running.map(\.start) == [date("2026-06-21T19:42:00+02:00")])
    #expect(store.sleeps(of: mila.id).count == 2)
  }

  @Test @MainActor func overlappingSleepsMergeAndAMergedSleepCanPass24Hours() async throws {
    let store = try await load(.overlapping, now: "2026-06-22T07:30:00+02:00")
    let mila = try named("Mila", in: store)
    let noah = try named("Noah", in: store)

    let milas = store.sleeps(of: mila.id)
    #expect(milas.filter(\.isRunning).isEmpty)
    #expect(milas.first?.start == date("2026-06-21T19:42:00+02:00"))
    #expect(milas.first?.end == date("2026-06-22T06:50:00+02:00"))
    #expect(milas.count == 2)

    let noahs = store.sleeps(of: noah.id)
    #expect(noahs.count == 1)
    #expect(noahs.first?.kind == .night)
    #expect(noahs.first?.start == date("2026-06-20T19:00:00+02:00"))
    #expect(noahs.first?.end == date("2026-06-21T20:30:00+02:00"))
  }

  @Test @MainActor func aSyncedOverlappingNapMergesOnTheNextStoreChange() async throws {
    let store = try await load(.family, now: "2026-06-22T07:30:00+02:00")
    let mila = try named("Mila", in: store)

    try store.insertAsIfSynced(
      Sleep(
        id: UUID(), childID: mila.id, start: date("2026-06-21T13:00:00+02:00"), end: date("2026-06-21T14:00:00+02:00"),
        kind: .nap))
    try store.insertAsIfSynced(
      Sleep(
        id: UUID(), childID: mila.id, start: date("2026-06-21T13:30:00+02:00"), end: date("2026-06-21T15:00:00+02:00"),
        kind: .nap))
    await store.processStoreChange()

    let naps = store.sleeps(of: mila.id).filter { $0.kind == .nap }
    #expect(naps.map(\.start) == [date("2026-06-21T13:00:00+02:00")])
    #expect(naps.map(\.end) == [date("2026-06-21T15:00:00+02:00")])
  }

  @Test @MainActor func aSleepThatFailedToMoveIntoTheShareMovesOnTheNextStoreChange() async throws {
    let seam = RecordingShareMoving(failures: 1)
    let store = try await load(.shared, shareMoving: seam)
    #expect(seam.attempts == 0, "The seed starts in the share")
    let mila = try named("Mila", in: store)

    try store.startSleep(childID: mila.id, at: date("2026-06-21T09:00:00+02:00"), kind: .nap)
    let sleep = try #require(running(of: mila, in: store))
    await store.processStoreChange()

    #expect(seam.attempts == 2)
    #expect(seam.moved == [sleep.id])
    await store.processStoreChange()
    #expect(seam.attempts == 2, "Nothing is left to move")
  }

  @Test @MainActor func onTheOwnerPhoneANewChildMovesIntoTheShare() async throws {
    let seam = RecordingShareMoving(failures: 0)
    let store = try await load(.shared, shareMoving: seam)

    let kai = try await store.add(name: "Kai", birthDate: day(2025, 1, 2), photo: nil)
    await store.processStoreChange()

    #expect(seam.moved == [kai.id])
  }

  @Test @MainActor func withNoShareNothingMoves() async throws {
    let seam = RecordingShareMoving(failures: 0)
    seam.hasShare = false
    let store = try await load(.family, shareMoving: seam)
    let mila = try named("Mila", in: store)

    try store.startSleep(childID: mila.id, at: date("2026-06-21T09:00:00+02:00"), kind: .nap)
    await store.processStoreChange()

    #expect(seam.attempts == 0)
  }

  // MARK: Helpers

  @MainActor private func load(
    _ seed: Seed, now: String? = nil, shareMoving: (any ShareMoving)? = nil
  ) async throws -> FamilyStore {
    let standard = TestEnvironment.standard
    let environment = TestEnvironment(
      now: now.map(date) ?? standard.now, timeZone: standard.timeZone, seed: seed)
    return try await FamilyStore.load(
      .test(environment), appGroupContainerURL: nil, seedPhoto: { _ in nil }, shareMoving: shareMoving)
  }

  @MainActor private func running(of child: Child, in store: FamilyStore) -> Sleep? {
    store.sleeps(of: child.id).first(where: \.isRunning)
  }

  @MainActor private func named(_ name: String, in store: FamilyStore) throws -> Child {
    let child = store.children.first { $0.name == name }
    return try #require(child)
  }

  private func date(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: iso)!
  }

  private func day(_ year: Int, _ month: Int, _ day: Int) -> BirthDate {
    BirthDate(year: year, month: month, day: day)!
  }
}

/// A sharing seam that records the moved ids and can fail.
@MainActor
final class RecordingShareMoving: ShareMoving {
  var hasShare = true
  private(set) var attempts = 0
  private(set) var moved: [UUID] = []
  private var inShare: Set<UUID> = []
  private var failures: Int

  init(failures: Int) {
    self.failures = failures
  }

  struct NoConnection: Error {}

  func isInShare(_ object: NSManagedObject) -> Bool {
    guard let id = object.value(forKey: "identifier") as? UUID else { return true }
    return inShare.contains(id)
  }

  func moveIntoShare(_ objects: [NSManagedObject]) async throws {
    attempts += 1
    if failures > 0 {
      failures -= 1
      throw NoConnection()
    }
    let ids = objects.compactMap { $0.value(forKey: "identifier") as? UUID }
    moved += ids
    inShare.formUnion(ids)
  }

  func seedInShare(_ ids: [UUID]) {
    inShare.formUnion(ids)
  }
}
