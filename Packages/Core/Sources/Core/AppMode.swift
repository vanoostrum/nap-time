import Foundation

/// How the app runs: for real, or in test mode for CI.
public enum AppMode: Equatable, Sendable {
  /// The normal mode: the family store on disk, synced with CloudKit, with notifications.
  case normal
  /// Test mode: an in-memory store, a fixed clock and location, no CloudKit, no notifications.
  case test(TestEnvironment)

  public var usesInMemoryStore: Bool {
    if case .test = self { true } else { false }
  }

  public var isCloudKitEnabled: Bool { !usesInMemoryStore }

  public var areNotificationsEnabled: Bool { !usesInMemoryStore }
}

/// The fixed clock, time zone, location, and seed of test mode.
public struct TestEnvironment: Equatable, Sendable {
  public var now: Date
  public var timeZone: TimeZone
  public var location: Coordinate
  public var seed: Seed

  public init(now: Date, timeZone: TimeZone, location: Coordinate, seed: Seed = .none) {
    self.now = now
    self.timeZone = timeZone
    self.location = location
    self.seed = seed
  }

  /// 2026-06-21T10:00:00+02:00, in Amsterdam, with no children.
  public static let standard = TestEnvironment(
    now: Date(timeIntervalSince1970: 1_782_028_800),
    timeZone: TimeZone(identifier: "Europe/Amsterdam")!,
    location: .amsterdam
  )
}

/// A point on Earth, in degrees.
public struct Coordinate: Equatable, Sendable {
  public var latitude: Double
  public var longitude: Double

  public init(latitude: Double, longitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
  }

  public static let amsterdam = Coordinate(latitude: 52.3676, longitude: 4.9041)
}
