import Foundation

/// How the app runs: for real, or in test mode for CI.
public enum AppMode: Equatable, Sendable {
  /// The normal mode: the family store on disk, synced with CloudKit, with notifications.
  case normal
  /// Test mode: an in-memory store, a fixed clock, no CloudKit, no notifications, no animations.
  case test(TestEnvironment)

  public var usesInMemoryStore: Bool {
    if case .test = self { true } else { false }
  }

  public var isCloudKitEnabled: Bool { !usesInMemoryStore }

  public var areNotificationsEnabled: Bool { !usesInMemoryStore }

  /// False in test mode, so UI tests do not wait for animations and screenshots show the end state.
  public var areAnimationsEnabled: Bool { !usesInMemoryStore }

  /// False in test mode: it requests no sleep timer. The UI tests render the timer's views instead (ADR 0003).
  public var areLiveActivitiesEnabled: Bool { !usesInMemoryStore }
}

/// The fixed clock, time zone, and seed of test mode.
public struct TestEnvironment: Equatable, Sendable {
  public var now: Date
  public var timeZone: TimeZone
  public var seed: Seed

  public init(now: Date, timeZone: TimeZone, seed: Seed = .none) {
    self.now = now
    self.timeZone = timeZone
    self.seed = seed
  }

  /// 2026-06-21T10:00:00+02:00, in Amsterdam, with no children.
  public static let standard = TestEnvironment(
    now: Date(timeIntervalSince1970: 1_782_028_800),
    timeZone: TimeZone(identifier: "Europe/Amsterdam")!
  )
}
