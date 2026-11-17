import Foundation

/// One period in which a child sleeps. A running sleep has no end yet.
public struct Sleep: Identifiable, Hashable, Sendable {
  public let id: UUID
  public let childID: UUID
  public var start: Date
  /// `nil` while the sleep runs.
  public var end: Date?
  public var kind: SleepKind

  public init(id: UUID, childID: UUID, start: Date, end: Date?, kind: SleepKind) {
    self.id = id
    self.childID = childID
    self.start = start
    self.end = end
    self.kind = kind
  }

  public var isRunning: Bool { end == nil }

  /// A sleep shorter than this is not kept: "Wake up" deletes it.
  public static let shortest: TimeInterval = 60
}

/// A night or a nap.
public enum SleepKind: String, CaseIterable, Sendable {
  case night
  case nap

  /// A sleep that starts from 18:00 to 05:59 in `timeZone` is a night. Any other sleep is a nap.
  public static func guess(start: Date, in timeZone: TimeZone) -> SleepKind {
    let hour = Calendar.gregorian(in: timeZone).component(.hour, from: start)
    return hour >= 18 || hour < 6 ? .night : .nap
  }
}

/// The time from 18:00 on one date to 18:00 on the next, named after the second date (ADR 0006).
public struct SleepDay: Hashable, Sendable {
  /// The date the sleep day ends on.
  public let name: BirthDate

  public init(named name: BirthDate) {
    self.name = name
  }

  /// The sleep day that holds `instant` in `timeZone`.
  public init(containing instant: Date, in timeZone: TimeZone) {
    let calendar = Calendar.gregorian(in: timeZone)
    let date = BirthDate(instant, in: calendar)
    name = calendar.component(.hour, from: instant) >= 18 ? date.adding(days: 1) : date
  }

  /// From 18:00 on the date before `name` to 18:00 on `name`: 23 or 25 hours on the day the clock changes.
  public func interval(in timeZone: TimeZone) -> DateInterval {
    DateInterval(start: Self.sixPM(on: name.adding(days: -1), in: timeZone), end: Self.sixPM(on: name, in: timeZone))
  }

  private static func sixPM(on date: BirthDate, in timeZone: TimeZone) -> Date {
    let parts = DateComponents(year: date.year, month: date.month, day: date.day, hour: 18)
    return Calendar.gregorian(in: timeZone).date(from: parts) ?? Date(timeIntervalSince1970: 0)
  }
}

/// The total of "slept today" on the home screen.
public enum SleptToday {
  /// The sleep in the sleep day named after today's date: before 18:00 the current sleep day,
  /// from 18:00 to midnight the sleep day that just ended. Each sleep is cut to that sleep day,
  /// and a running sleep counts until `now`.
  public static func total(of sleeps: [Sleep], now: Date, in timeZone: TimeZone) -> TimeInterval {
    let today = BirthDate(now, in: Calendar.gregorian(in: timeZone))
    let day = SleepDay(named: today).interval(in: timeZone)
    return sleeps.reduce(0) { total, sleep in
      let start = max(sleep.start, day.start)
      let end = min(sleep.end ?? now, day.end)
      return total + max(0, end.timeIntervalSince(start))
    }
  }
}

/// A duration as the app shows it.
public enum SleepDuration {
  /// "45 m" under 1 hour, else "2 h 14 m" or "12 h 05 m". Seconds are dropped.
  public static func text(_ duration: TimeInterval) -> String {
    let minutes = max(0, Int(duration / 60))
    guard minutes >= 60 else { return "\(minutes) m" }
    return "\(minutes / 60) h \(twoDigits(minutes % 60)) m"
  }
}

/// A time of day as the app shows it.
public enum ClockTime {
  /// "06:55": 24-hour time in `timeZone`.
  public static func text(_ instant: Date, in timeZone: TimeZone) -> String {
    let parts = Calendar.gregorian(in: timeZone).dateComponents([.hour, .minute], from: instant)
    return "\(twoDigits(parts.hour ?? 0)):\(twoDigits(parts.minute ?? 0))"
  }
}

/// What the home screen shows for a child: asleep or awake, the sky, and the status line.
public struct ChildStatus: Equatable, Sendable {
  public let isSleeping: Bool
  public let sky: SkyPhase
  /// "2 h 14 m · since 19:42" while a sleep runs; else "since 06:55 · 11 h 10 m slept today",
  /// with "since" only when the last sleep ended in the past 24 hours.
  public let line: String

  /// `sleeps` are the sleeps of one child.
  public init(sleeps: [Sleep], now: Date, in timeZone: TimeZone) {
    if let running = sleeps.first(where: \.isRunning) {
      isSleeping = true
      sky = SkyPhase(at: now, in: timeZone, running: running.kind)
      let duration = SleepDuration.text(now.timeIntervalSince(running.start))
      line = "\(duration) · since \(ClockTime.text(running.start, in: timeZone))"
      return
    }
    isSleeping = false
    sky = SkyPhase(at: now, in: timeZone)
    let total = "\(SleepDuration.text(SleptToday.total(of: sleeps, now: now, in: timeZone))) slept today"
    if let lastEnd = sleeps.compactMap(\.end).max(), now.timeIntervalSince(lastEnd) < 24 * 3600 {
      line = "since \(ClockTime.text(lastEnd, in: timeZone)) · \(total)"
    } else {
      line = total
    }
  }

  /// "Mila is sleeping" or "Mila is awake".
  public func heading(name: String) -> String {
    "\(name) is \(isSleeping ? "sleeping" : "awake")"
  }
}

private func twoDigits(_ value: Int) -> String {
  value < 10 ? "0\(value)" : "\(value)"
}

extension Calendar {
  /// The Gregorian calendar in `timeZone`.
  static func gregorian(in timeZone: TimeZone) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar
  }
}
