import Foundation

/// The data that test mode starts with. `--seed <name>` picks one.
public enum Seed: String, CaseIterable, Sendable {
  /// No children: the app opens "Add your child".
  case none
  /// Mila (selected, no photo) and Noah (a photo that the app draws).
  case family
  /// One child with a name of 30 characters.
  case longName = "long-name"
  /// `family`, and Mila sleeps a night since 21 June 2026 19:42. Pass `--now 2026-06-21T21:56:00+02:00`.
  case sleeping
  /// `family`, and Mila naps since 21 June 2026 13:05. Pass `--now 2026-06-21T13:50:00+02:00`.
  case napping

  /// The children, in the order that test mode adds them.
  public var children: [SeedChild] {
    switch self {
    case .none:
      []
    case .family, .sleeping, .napping:
      [
        SeedChild(name: "Mila", birthDate: BirthDate(year: 2025, month: 3, day: 12)!, drawsPhoto: false),
        SeedChild(name: "Noah", birthDate: BirthDate(year: 2022, month: 2, day: 10)!, drawsPhoto: true),
      ]
    case .longName:
      [
        SeedChild(
          name: "Maximiliana Rosalind Pepperpot", birthDate: BirthDate(year: 2025, month: 3, day: 12)!,
          drawsPhoto: false)
      ]
    }
  }

  /// The sleeps, in the order that test mode adds them. The times are in Europe/Amsterdam (UTC+2 in June).
  public var sleeps: [SeedSleep] {
    let lastNight = SeedSleep(
      childIndex: 0, start: Self.june21(hour: -5, minute: 45), end: Self.june21(hour: 6, minute: 55), kind: .night)
    switch self {
    case .none, .longName:
      return []
    case .family:
      return [lastNight]
    case .sleeping:
      return [lastNight, SeedSleep(childIndex: 0, start: Self.june21(hour: 19, minute: 42), end: nil, kind: .night)]
    case .napping:
      return [lastNight, SeedSleep(childIndex: 0, start: Self.june21(hour: 13, minute: 5), end: nil, kind: .nap)]
    }
  }

  /// 21 June 2026 at `hour`:`minute` in UTC+2. A negative hour is on 20 June.
  private static func june21(hour: Int, minute: Int) -> Date {
    let midnight = 1_781_992_800  // 2026-06-21T00:00:00+02:00
    return Date(timeIntervalSince1970: TimeInterval(midnight + hour * 3600 + minute * 60))
  }

  /// The index in `children` of the selected child.
  public var selectedIndex: Int? { children.isEmpty ? nil : 0 }
}

/// A child of a seed. The data is made up.
public struct SeedChild: Equatable, Sendable {
  public let name: String
  public let birthDate: BirthDate
  /// The app draws a photo for this child, so a screenshot shows a photo. It is not a real photo.
  public let drawsPhoto: Bool
}

/// A sleep of a seed. The data is made up.
public struct SeedSleep: Equatable, Sendable {
  /// The index in `Seed.children` of the child who sleeps.
  public let childIndex: Int
  public let start: Date
  /// `nil` for a running sleep.
  public let end: Date?
  public let kind: SleepKind

  public init(childIndex: Int, start: Date, end: Date?, kind: SleepKind) {
    self.childIndex = childIndex
    self.start = start
    self.end = end
    self.kind = kind
  }
}
