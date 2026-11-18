import Foundation

extension SleepDay {
  /// The sleeps that cross into this sleep day: each one that overlaps it by more than zero time, oldest first.
  /// A sleep that ends at exactly 18:00 belongs only to the earlier day, and one that starts then only to the
  /// later day. A running sleep runs until `now`.
  public func sleeps(crossingInto sleeps: [Sleep], now: Date, in timeZone: TimeZone) -> [Sleep] {
    let interval = interval(in: timeZone)
    return
      sleeps
      .filter { $0.start < interval.end && ($0.end ?? now) > interval.start }
      .sorted { $0.start < $1.start }
  }

  /// True from 18:00 on the named date.
  public func hasEnded(now: Date, in timeZone: TimeZone) -> Bool {
    interval(in: timeZone).end <= now
  }

  /// The time asleep inside this sleep day: each sleep cut at 18:00, a running sleep until `now`.
  func asleep(in sleeps: [Sleep], now: Date, in timeZone: TimeZone) -> TimeInterval {
    let interval = interval(in: timeZone)
    return sleeps.reduce(0) { total, sleep in
      let start = max(sleep.start, interval.start)
      let end = min(sleep.end ?? now, interval.end)
      return total + max(0, end.timeIntervalSince(start))
    }
  }

  /// "Monday 2 Nov".
  var longTitle: String { "\(name.weekdayName) \(name.day) \(name.shortMonth)" }
}

/// The part of one sleep inside one sleep day, on the timeline's scale of 24 clock hours from 18:00.
public struct TimelineSegment: Hashable, Sendable {
  public let sleepID: UUID
  public let kind: SleepKind
  /// The clock hours from 18:00 to where the part starts: 0 to 24.
  public let from: Double
  /// The clock hours that the part lasts.
  public let length: Double
}

/// One row of the timeline "When <name> slept": a sleep day with its segments.
public struct TimelineRow: Sendable {
  public let sleepDay: SleepDay
  public let segments: [TimelineSegment]

  /// "Mon".
  public var dayName: String { String(sleepDay.name.weekdayName.prefix(3)) }

  /// "Monday 2 Nov details".
  public var accessibilityLabel: String { "\(sleepDay.longTitle) details" }
}

/// The timeline: one row per sleep day of a week, from 18:00 to 18:00.
public enum Timeline {
  /// The rows of `week`. A past week has seven rows; the current week has rows up to the current sleep day.
  public static func rows(of week: Week, sleeps: [Sleep], now: Date, in timeZone: TimeZone) -> [TimelineRow] {
    let current = SleepDay(containing: now, in: timeZone)
    return week.days
      .filter { $0.name <= current.name }
      .map { TimelineRow(sleepDay: $0, segments: segments(on: $0, sleeps: sleeps, now: now, in: timeZone)) }
  }

  /// The parts of `sleeps` inside `sleepDay`, oldest first: each sleep cut at 18:00, a running sleep until `now`.
  /// A segment sits at its clock times, so on the day the clock changes the row still spans 24 hours.
  public static func segments(on sleepDay: SleepDay, sleeps: [Sleep], now: Date, in timeZone: TimeZone)
    -> [TimelineSegment]
  {
    let interval = sleepDay.interval(in: timeZone)
    return sleepDay.sleeps(crossingInto: sleeps, now: now, in: timeZone).map { sleep in
      let start = max(sleep.start, interval.start)
      let end = min(sleep.end ?? now, interval.end)
      let from = start == interval.start ? 0 : hoursAfterSixPM(start, in: timeZone)
      let to = end == interval.end ? 24 : hoursAfterSixPM(end, in: timeZone)
      return TimelineSegment(sleepID: sleep.id, kind: sleep.kind, from: from, length: max(0, to - from))
    }
  }

  /// The clock time of `instant` as hours after 18:00: 18:00 is 0, 06:00 is 12.
  private static func hoursAfterSixPM(_ instant: Date, in timeZone: TimeZone) -> Double {
    let parts = Calendar.gregorian(in: timeZone).dateComponents([.hour, .minute, .second], from: instant)
    let hours = Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60 + Double(parts.second ?? 0) / 3600
    return (hours - 18 + 24).truncatingRemainder(dividingBy: 24)
  }
}

/// The day sheet of one sleep day: its sleeps, its total, and its pill.
public struct DaySheet: Sendable {
  /// The pill in the sheet head: the verdict of a counted day, or "So far" on a day that has not ended.
  public enum Pill: Hashable, Sendable {
    case judgement(WeekStats.Judgement)
    case soFar
  }

  /// One sleep on the sheet, with its full times and full duration.
  public struct Item: Sendable {
    public let sleep: Sleep
    /// "Night" or "Nap".
    public let kindName: String
    /// "20:54 → 06:12", or "19:42 → now" for a running sleep.
    public let times: String
    /// "9 h 18 m", or "54 m".
    public let duration: String
    /// "Edit night" or "Edit nap".
    public let editLabel: String
  }

  public let sleepDay: SleepDay
  public let items: [Item]
  /// The time asleep inside the sleep day.
  public let total: TimeInterval
  public let hasEnded: Bool
  private let range: RecommendedRange

  /// `sleeps` are the sleeps of one child, born on `birthDate`.
  public init(sleepDay: SleepDay, sleeps: [Sleep], birthDate: BirthDate, now: Date, in timeZone: TimeZone) {
    self.sleepDay = sleepDay
    let crossing = sleepDay.sleeps(crossingInto: sleeps, now: now, in: timeZone)
    items = crossing.map { sleep in
      let start = ClockTime.text(sleep.start, in: timeZone)
      let end = sleep.end.map { ClockTime.text($0, in: timeZone) } ?? "now"
      let kind = sleep.kind == .night ? "Night" : "Nap"
      return Item(
        sleep: sleep, kindName: kind, times: "\(start) → \(end)",
        duration: SleepDuration.text((sleep.end ?? now).timeIntervalSince(sleep.start)),
        editLabel: "Edit \(sleep.kind.rawValue)")
    }
    total = sleepDay.asleep(in: crossing, now: now, in: timeZone)
    hasEnded = sleepDay.hasEnded(now: now, in: timeZone)
    range = RecommendedRange(birthDate: birthDate, on: sleepDay.name)
  }

  /// "Tuesday 3 Nov".
  public var title: String { sleepDay.longTitle }

  /// "10 h 12 m slept in total", "10 h 50 m slept so far", or "No sleeps logged".
  public var summary: String {
    guard !items.isEmpty else { return "No sleeps logged" }
    return "\(SleepDuration.text(total)) slept \(hasEnded ? "in total" : "so far")"
  }

  /// "So far" until the day ends, also with no sleeps; the verdict on a counted day; none on a past empty day.
  public var pill: Pill? {
    guard hasEnded else { return .soFar }
    guard !items.isEmpty else { return nil }
    return .judgement(WeekStats.Judgement(total: total, range: range))
  }

  /// The start values of "Add a sleep to this day": from now on the current sleep day,
  /// else inside `sleepDay` (`SleepStartValues.on`).
  public static func startValues(on sleepDay: SleepDay, now: Date, in timeZone: TimeZone) -> SleepStartValues {
    sleepDay == SleepDay(containing: now, in: timeZone)
      ? SleepStartValues.today(now: now, in: timeZone) : SleepStartValues.on(sleepDay, now: now, in: timeZone)
  }
}
