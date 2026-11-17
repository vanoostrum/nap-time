import Core
import Foundation
import Testing

@Suite struct SeedTests {
  private let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!

  @Test func familyHasMilasLastNight() {
    #expect(
      Seed.family.sleeps == [
        SeedSleep(
          childIndex: 0, start: date("2026-06-20T19:45:00+02:00"), end: date("2026-06-21T06:55:00+02:00"), kind: .night)
      ])
  }

  @Test func sleepingIsTheFamilyWithARunningNightForMila() {
    #expect(Seed.sleeping.children == Seed.family.children)
    #expect(Seed.sleeping.selectedIndex == 0)
    #expect(
      Seed.sleeping.sleeps
        == Seed.family.sleeps + [
          SeedSleep(childIndex: 0, start: date("2026-06-21T19:42:00+02:00"), end: nil, kind: .night)
        ])
  }

  @Test func nappingIsTheFamilyWithARunningNapForMila() {
    #expect(Seed.napping.children == Seed.family.children)
    #expect(
      Seed.napping.sleeps
        == Seed.family.sleeps + [
          SeedSleep(childIndex: 0, start: date("2026-06-21T13:05:00+02:00"), end: nil, kind: .nap)
        ])
  }

  @Test func theSeedKindsMatchTheGuess() {
    for seed in Seed.allCases {
      for sleep in seed.sleeps {
        #expect(SleepKind.guess(start: sleep.start, in: amsterdam) == sleep.kind)
      }
    }
  }

  @Test func theOtherSeedsHaveNoSleeps() {
    #expect(Seed.none.sleeps.isEmpty)
    #expect(Seed.longName.sleeps.isEmpty)
  }

  @Test(arguments: ["sleeping", "napping"])
  func theNewSeedsParse(name: String) throws {
    let mode = try LaunchArguments.parse(["/path/to/NapTime", "--test-mode", "--seed", name])
    guard case .test(let environment) = mode else {
      Issue.record("Expected test mode, got \(mode)")
      return
    }
    #expect(environment.seed.rawValue == name)
    #expect(environment.timeZone.identifier == "Europe/Amsterdam")
  }

  /// What the home screen shows for Mila with each seed at the time its UI test passes.
  @Test(arguments: [
    (Seed.family, "2026-06-21T10:00:00+02:00", "Mila is awake", "since 06:55 · 11 h 10 m slept today", Sky.day),
    (.sleeping, "2026-06-21T21:56:00+02:00", "Mila is sleeping", "2 h 14 m · since 19:42", .night),
    (.napping, "2026-06-21T13:50:00+02:00", "Mila is sleeping", "45 m · since 13:05", .day),
  ])
  func milasStatusForEachSeed(seed: Seed, now: String, heading: String, line: String, sky: Sky) {
    let childID = UUID()
    let sleeps = seed.sleeps.filter { $0.childIndex == 0 }.map {
      Sleep(id: UUID(), childID: childID, start: $0.start, end: $0.end, kind: $0.kind)
    }
    let status = ChildStatus(sleeps: sleeps, now: date(now), in: amsterdam)
    #expect(status.heading(name: "Mila") == heading)
    #expect(status.line == line)
    #expect(status.sky == sky)
  }
}
