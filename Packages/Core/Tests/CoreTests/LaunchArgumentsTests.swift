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

  @Test func nowAndLocationWithoutTestModeAreIgnoredEvenWhenBad() throws {
    let mode = try LaunchArguments.parse([executable, "--now", "yesterday", "--location", "north"])
    #expect(mode == .normal)
  }

  @Test func testModeGivesTheFixedClockAndLocation() throws {
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
    #expect(environment.location == Coordinate(latitude: 52.3676, longitude: 4.9041))
  }

  @Test func nowAndLocationReplaceTheFixedValuesInTestMode() throws {
    let mode = try LaunchArguments.parse([
      executable, "--test-mode", "--now", "2026-12-24T21:30:00-05:00", "--location", "-33.8688,151.2093",
    ])
    guard case .test(let environment) = mode else {
      Issue.record("Expected test mode, got \(mode)")
      return
    }
    #expect(environment.now == date("2026-12-25T02:30:00Z"))
    #expect(environment.location == Coordinate(latitude: -33.8688, longitude: 151.2093))
    #expect(environment.timeZone.identifier == "Europe/Amsterdam")
  }

  @Test func argumentOrderDoesNotMatter() throws {
    let mode = try LaunchArguments.parse([executable, "--now", "2026-01-01T07:00:00Z", "--test-mode"])
    #expect(
      mode
        == .test(
          TestEnvironment(
            now: date("2026-01-01T07:00:00Z"),
            timeZone: TimeZone(identifier: "Europe/Amsterdam")!,
            location: .amsterdam
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

  @Test(arguments: [
    "52.3676",
    "52.3676,4.9041,0",
    "north,east",
    "91,0",
    "0,181",
    "",
  ])
  func badLocationNamesTheArgument(value: String) {
    #expect(throws: LaunchArgumentError(argument: "--location", value: value)) {
      try LaunchArguments.parse([executable, "--test-mode", "--location", value])
    }
  }

  @Test func missingValueNamesTheArgument() {
    #expect(throws: LaunchArgumentError(argument: "--now", value: nil)) {
      try LaunchArguments.parse([executable, "--test-mode", "--now"])
    }
    #expect(throws: LaunchArgumentError(argument: "--location", value: nil)) {
      try LaunchArguments.parse([executable, "--test-mode", "--location", "--now", "2026-01-01T07:00:00Z"])
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
