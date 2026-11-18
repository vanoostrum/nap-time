import Core
import Foundation
import Testing

@Suite struct LaunchArgumentsTests {
  private let executable = "/path/to/NapTime"

  @Test func noArgumentsGiveTheNormalMode() throws {
    let mode = try LaunchArguments.parse([executable])
    #expect(mode == .normal)
    #expect(!mode.usesInMemoryStore)
    #expect(mode.isCloudKitEnabled)
    #expect(mode.areNotificationsEnabled)
  }

  @Test func nowWithoutTestModeIsIgnoredEvenWhenBad() throws {
    let mode = try LaunchArguments.parse([executable, "--now", "yesterday"])
    #expect(mode == .normal)
  }

  @Test func testModeGivesTheFixedClock() throws {
    let mode = try LaunchArguments.parse([executable, "--test-mode"])
    guard case .test(let environment) = mode else {
      Issue.record("Expected test mode, got \(mode)")
      return
    }
    #expect(mode.usesInMemoryStore)
    #expect(!mode.isCloudKitEnabled)
    #expect(!mode.areNotificationsEnabled)
    #expect(environment.now == date("2026-06-21T10:00:00+02:00"))
    #expect(environment.timeZone.identifier == "Europe/Amsterdam")
  }

  @Test func nowReplacesTheFixedClockInTestMode() throws {
    let mode = try LaunchArguments.parse([executable, "--test-mode", "--now", "2026-12-24T21:30:00-05:00"])
    guard case .test(let environment) = mode else {
      Issue.record("Expected test mode, got \(mode)")
      return
    }
    #expect(environment.now == date("2026-12-25T02:30:00Z"))
    #expect(environment.timeZone.identifier == "Europe/Amsterdam")
  }

  @Test func argumentOrderDoesNotMatter() throws {
    let mode = try LaunchArguments.parse([executable, "--now", "2026-01-01T07:00:00Z", "--test-mode"])
    #expect(
      mode
        == .test(
          TestEnvironment(
            now: date("2026-01-01T07:00:00Z"),
            timeZone: TimeZone(identifier: "Europe/Amsterdam")!
          )))
  }

  @Test(arguments: [
    "2026-06-21T10:00:00",  // no UTC offset
    "2026-06-21",
    "tomorrow",
    "",
  ])
  func badNowNamesTheArgument(value: String) {
    #expect(throws: LaunchArgumentError(argument: "--now", value: value)) {
      try LaunchArguments.parse([executable, "--test-mode", "--now", value])
    }
  }

  /// The app has no location (ADR 0007), so `--location` is an unknown argument, and test mode ignores it.
  @Test(arguments: [["--location", "1,2"], ["--location", "north"], ["--location"]])
  func locationIsIgnoredInTestMode(location: [String]) throws {
    #expect(try LaunchArguments.parse([executable, "--test-mode"] + location) == .test(.standard))
    #expect(
      try LaunchArguments.parse([executable, "--test-mode", "--seed", "family"] + location)
        == .test(
          TestEnvironment(now: TestEnvironment.standard.now, timeZone: TestEnvironment.standard.timeZone, seed: .family)
        ))
  }

  @Test func missingValueNamesTheArgument() {
    #expect(throws: LaunchArgumentError(argument: "--now", value: nil)) {
      try LaunchArguments.parse([executable, "--test-mode", "--now"])
    }
  }

  @Test func errorDescriptionNamesTheArgumentAndValue() {
    let error = LaunchArgumentError(argument: "--now", value: "tomorrow")
    #expect(error.description.contains("--now"))
    #expect(error.description.contains("tomorrow"))
  }

  @Test func seedIsNoneByDefault() throws {
    let mode = try LaunchArguments.parse([executable, "--test-mode"])
    #expect(mode == .test(.standard))
    #expect(TestEnvironment.standard.seed == .none)
    #expect(Seed.none.children.isEmpty)
    #expect(Seed.none.selectedIndex == nil)
  }

  @Test func familySeedHasMilaSelectedAndNoahWithADrawnPhoto() throws {
    let mode = try LaunchArguments.parse([executable, "--test-mode", "--seed", "family"])
    guard case .test(let environment) = mode else {
      Issue.record("Expected test mode, got \(mode)")
      return
    }
    #expect(environment.seed == .family)
    let children = Seed.family.children
    #expect(children.map(\.name) == ["Mila", "Noah"])
    #expect(children.map(\.birthDate) == [day(2025, 3, 12), day(2022, 2, 10)])
    #expect(children.map(\.drawsPhoto) == [false, true])
    #expect(Seed.family.selectedIndex == 0)
  }

  @Test func theSharingSeedsParseWithTheirStateAndPendingJoin() throws {
    let expected: [(String, Seed, FamilySharing, Bool)] = [
      ("shared", .shared, .shared(partner: "Sam"), false),
      ("invited", .invited, .invited, false),
      ("partner", .partner, .joined(owner: "Alex"), false),
      ("no-icloud", .noICloud, .noICloud, false),
      ("joining", .joining, .joined(owner: "Alex"), true),
      ("joined", .joined, .joined(owner: "Alex"), true),
      ("duplicate-running", .duplicateRunning, .notShared, false),
      ("overlapping", .overlapping, .notShared, false),
    ]
    for (name, seed, sharing, pendingJoin) in expected {
      let mode = try LaunchArguments.parse([executable, "--test-mode", "--seed", name])
      guard case .test(let environment) = mode else {
        Issue.record("Expected test mode, got \(mode)")
        return
      }
      #expect(environment.seed == seed)
      #expect(seed.sharing == sharing)
      #expect(seed.startsWithPendingJoin == pendingJoin)
    }
    #expect(Seed.family.sharing == .notShared)
    #expect(!Seed.family.startsWithPendingJoin)
  }

  @Test func longNameSeedHasOneChildWith30Characters() throws {
    let mode = try LaunchArguments.parse([executable, "--test-mode", "--seed", "long-name"])
    guard case .test(let environment) = mode else {
      Issue.record("Expected test mode, got \(mode)")
      return
    }
    #expect(environment.seed == .longName)
    let children = Seed.longName.children
    #expect(children.map(\.name) == ["Maximiliana Rosalind Pepperpot"])
    #expect(children.first?.name.count == 30)
    #expect(children.first?.birthDate == day(2025, 3, 12))
    #expect(children.first?.drawsPhoto == false)
    #expect(Seed.longName.selectedIndex == 0)
  }

  @Test func seedWithoutTestModeIsIgnored() throws {
    #expect(try LaunchArguments.parse([executable, "--seed", "nonsense"]) == .normal)
  }

  @Test func unknownOrMissingSeedNamesTheArgument() {
    #expect(throws: LaunchArgumentError(argument: "--seed", value: "families")) {
      try LaunchArguments.parse([executable, "--test-mode", "--seed", "families"])
    }
    #expect(throws: LaunchArgumentError(argument: "--seed", value: nil)) {
      try LaunchArguments.parse([executable, "--test-mode", "--seed"])
    }
    #expect(
      LaunchArgumentError(argument: "--seed", value: "x").description.hasPrefix("Bad value for launch argument --seed"))
  }

  private func date(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: iso)!
  }
}
