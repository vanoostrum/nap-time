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
  /// `family`, with Mila's sleeps from Monday 2 to Sunday 8 November 2026 (`charts/week.html`) and Noah's nap
  /// on Tuesday 3 November. Pass `--now 2026-11-08T19:30:00+01:00`.
  case week
  /// `week`, with Mila's sleeps from the sleep day Monday 9 November to the morning of Wednesday 11 November
  /// (`charts/week-today.html`). Pass `--now 2026-11-11T10:00:00+01:00`.
  case weekToday = "week-today"
  /// `family`, shared with the partner "Sam".
  case shared
  /// `family`, with an invite sent that the partner has not opened yet.
  case invited
  /// This phone joined Alex's family: Mila and Noah are family children, and Lou, born 3 May 2024 and added
  /// before joining, is only on this phone.
  case partner
  /// `family`, with no iCloud account.
  case noICloud = "no-icloud"
  /// This phone just joined Alex's family, and no shared child has arrived yet: "Joining the family…".
  case joining
  /// This phone just joined Alex's family, and Mila and Noah arrived: "You joined the family".
  case joined
  /// `family`, and two running nights for Mila from 21 June 2026 19:42 and 19:44, as two phones log them before
  /// they sync. Pass `--now 2026-06-22T07:30:00+02:00`.
  case duplicateRunning = "duplicate-running"
  /// `family`, and two overlapping nights for Mila, one from 21 June 2026 19:42 to 22 June 06:50 and one running
  /// from 19:44, and two overlapping sleeps for Noah, a night from 20 June 19:00 to 21 June 08:00 and a nap from
  /// 21 June 07:00 to 20:30. Pass `--now 2026-06-22T07:30:00+02:00`.
  case overlapping

  /// The children, in the order that test mode adds them.
  public var children: [SeedChild] {
    switch self {
    case .none, .joining:
      []
    case .family, .sleeping, .napping, .evening, .winterMorning, .week, .weekToday, .shared, .invited, .noICloud,
      .joined, .duplicateRunning, .overlapping:
      [Self.mila, Self.noah]
    case .partner:
      [
        SeedChild(
          name: "Lou", birthDate: BirthDate(year: 2024, month: 5, day: 3)!, drawsPhoto: false, onlyOnThisPhone: true),
        Self.mila, Self.noah,
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
    case .none, .longName, .joining:
      return []
    case .family, .shared, .invited, .noICloud, .joined:
      return [lastNight]
    case .partner:
      return [
        SeedSleep(childIndex: 1, start: lastNight.start, end: lastNight.end, kind: lastNight.kind)
      ]
    case .duplicateRunning:
      return [
        lastNight, SeedSleep(childIndex: 0, start: Self.instant("2026-06-21T19:42:00+02:00"), end: nil, kind: .night),
        SeedSleep(childIndex: 0, start: Self.instant("2026-06-21T19:44:00+02:00"), end: nil, kind: .night),
      ]
    case .overlapping:
      return [
        lastNight,
        SeedSleep(
          childIndex: 0, start: Self.instant("2026-06-21T19:42:00+02:00"),
          end: Self.instant("2026-06-22T06:50:00+02:00"), kind: .night),
        SeedSleep(childIndex: 0, start: Self.instant("2026-06-21T19:44:00+02:00"), end: nil, kind: .night),
        SeedSleep(
          childIndex: 1, start: Self.instant("2026-06-20T19:00:00+02:00"),
          end: Self.instant("2026-06-21T08:00:00+02:00"), kind: .night),
        SeedSleep(
          childIndex: 1, start: Self.instant("2026-06-21T07:00:00+02:00"),
          end: Self.instant("2026-06-21T20:30:00+02:00"), kind: .nap),
      ]
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
    case .week:
      return [lastNight] + Self.milasWeek + [Self.november("2026-11-03T13:00", "2026-11-03T14:30", .nap, child: 1)]
    case .weekToday:
      return Seed.week.sleeps + Self.milasWeekSoFar
    }
  }

  private static let mila = SeedChild(
    name: "Mila", birthDate: BirthDate(year: 2025, month: 3, day: 12)!, drawsPhoto: false)
  private static let noah = SeedChild(
    name: "Noah", birthDate: BirthDate(year: 2022, month: 2, day: 10)!, drawsPhoto: true)

  /// How the phone shares the family.
  public var sharing: FamilySharing {
    switch self {
    case .shared: .shared(partner: "Sam")
    case .invited: .invited
    case .partner, .joining, .joined: .joined(owner: "Alex")
    case .noICloud: .noICloud
    default: .notShared
    }
  }

  /// The app starts on a join screen: it has accepted a share, and the partner has not tapped "Start" yet.
  public var startsWithPendingJoin: Bool { self == .joining || self == .joined }

  /// Mila's sleeps in the sleep days from Monday 2 to Sunday 8 November 2026, as `charts/week.html` shows.
  private static let milasWeek = [
    november("2026-11-01T19:45", "2026-11-02T06:51", .night), november("2026-11-02T13:00", "2026-11-02T14:30", .nap),
    november("2026-11-02T20:54", "2026-11-03T06:12", .night), november("2026-11-03T13:30", "2026-11-03T14:24", .nap),
    november("2026-11-03T19:30", "2026-11-04T06:30", .night), november("2026-11-04T12:48", "2026-11-04T13:54", .nap),
    november("2026-11-04T19:00", "2026-11-05T06:30", .night), november("2026-11-05T13:00", "2026-11-05T14:30", .nap),
    november("2026-11-05T21:12", "2026-11-06T06:48", .night), november("2026-11-06T14:00", "2026-11-06T15:12", .nap),
    november("2026-11-06T20:00", "2026-11-07T06:24", .night), november("2026-11-07T13:12", "2026-11-07T14:42", .nap),
    november("2026-11-07T18:48", "2026-11-08T07:12", .night), november("2026-11-08T12:30", "2026-11-08T14:30", .nap),
  ]

  /// Mila's sleeps from the sleep day Monday 9 November to the morning of Wednesday 11 November 2026,
  /// as `charts/week-today.html` shows.
  private static let milasWeekSoFar = [
    november("2026-11-08T19:45", "2026-11-09T06:30", .night), november("2026-11-09T13:00", "2026-11-09T14:30", .nap),
    november("2026-11-09T20:30", "2026-11-10T06:15", .night), november("2026-11-10T13:30", "2026-11-10T14:24", .nap),
    november("2026-11-10T19:50", "2026-11-11T06:40", .night),
  ]

  /// A sleep in November 2026, in Amsterdam winter time.
  private static func november(_ start: String, _ end: String, _ kind: SleepKind, child: Int = 0) -> SeedSleep {
    SeedSleep(
      childIndex: child, start: instant("\(start):00+01:00"), end: instant("\(end):00+01:00"), kind: kind)
  }

  /// An ISO 8601 date and time with a UTC offset, written in this file.
  private static func instant(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso)!
  }

  /// The index in `children` of the selected child: the first family child.
  public var selectedIndex: Int? { children.firstIndex { !$0.onlyOnThisPhone } }
}

/// A child of a seed. The data is made up.
public struct SeedChild: Equatable, Sendable {
  public let name: String
  public let birthDate: BirthDate
  /// The app draws a photo for this child, so a screenshot shows a photo. It is not a real photo.
  public let drawsPhoto: Bool
  /// The child is not in the family: on a phone that joined a family, it stays in the private store.
  public let onlyOnThisPhone: Bool

  public init(name: String, birthDate: BirthDate, drawsPhoto: Bool, onlyOnThisPhone: Bool = false) {
    self.name = name
    self.birthDate = birthDate
    self.drawsPhoto = drawsPhoto
    self.onlyOnThisPhone = onlyOnThisPhone
  }
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
