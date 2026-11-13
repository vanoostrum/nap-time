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

  private func date(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: iso)!
  }
}
