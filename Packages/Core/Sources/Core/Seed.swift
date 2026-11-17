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
  /// `family`, and Mila napped on 21 June 2026 from 14:15 to 15:10. Pass `--now 2026-06-21T22:05:00+02:00` (sunset)
  /// or `--now 2026-06-21T23:30:00+02:00` (night).
  case evening
  /// `family`, with only Mila's night from 14 November 2026 19:48 to 15 November 06:40.
  /// Pass `--now 2026-11-15T08:00:00+01:00` (sunrise).
  case winterMorning = "winter-morning"

  /// The children, in the order that test mode adds them.
  public var children: [SeedChild] {
    switch self {
    case .none:
      []
    case .family, .sleeping, .napping, .evening, .winterMorning:
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

  /// The sleeps, in the order that test mode adds them. The times are in Europe/Amsterdam.
  public var sleeps: [SeedSleep] {
    let lastNight = SeedSleep(
      childIndex: 0, start: Self.instant("2026-06-20T19:45:00+02:00"), end: Self.instant("2026-06-21T06:55:00+02:00"),
      kind: .night)
    switch self {
    case .none, .longName:
      return []
    case .family:
      return [lastNight]
    case .sleeping:
      return [
        lastNight, SeedSleep(childIndex: 0, start: Self.instant("2026-06-21T19:42:00+02:00"), end: nil, kind: .night),
      ]
    case .napping:
      return [
        lastNight, SeedSleep(childIndex: 0, start: Self.instant("2026-06-21T13:05:00+02:00"), end: nil, kind: .nap),
      ]
    case .evening:
      let nap = SeedSleep(
        childIndex: 0, start: Self.instant("2026-06-21T14:15:00+02:00"), end: Self.instant("2026-06-21T15:10:00+02:00"),
        kind: .nap)
      return [lastNight, nap]
    case .winterMorning:
      return [
        SeedSleep(
          childIndex: 0, start: Self.instant("2026-11-14T19:48:00+01:00"),
          end: Self.instant("2026-11-15T06:40:00+01:00"), kind: .night)
      ]
    }
  }

  /// An ISO 8601 date and time with a UTC offset, written in this file.
  private static func instant(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso)!
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
