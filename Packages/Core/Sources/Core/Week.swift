import Foundation

/// Seven sleep days, from Monday to Sunday.
public struct Week: Hashable, Comparable, Sendable {
  /// The name of the first sleep day.
  public let monday: BirthDate

  /// The week that holds `day`.
  public init(containing day: SleepDay) {
    monday = day.name.adding(days: -day.name.weekdayFromMonday)
  }

  /// The week that holds the current sleep day. On Sunday from 18:00 to midnight, that is the next week.
  public static func current(now: Date, in timeZone: TimeZone) -> Week {
    Week(containing: SleepDay(containing: now, in: timeZone))
  }

  /// The week that the Charts tab opens on: the week of the sleep day named after today's date,
  /// as "slept today" counts. On Sunday from 18:00 to midnight, that is the week that just ended.
  public static func opening(now: Date, in timeZone: TimeZone) -> Week {
    Week(containing: SleepDay(named: BirthDate(now, in: Calendar.gregorian(in: timeZone))))
  }

  /// The weeks that the arrows reach: from the earlier of the opening week and the week of the first sleep,
  /// up to the current week.
  public static func reachable(firstSleepStart: Date?, now: Date, in timeZone: TimeZone) -> ClosedRange<Week> {
    var first = opening(now: now, in: timeZone)
    if let firstSleepStart {
      first = min(first, Week(containing: SleepDay(containing: firstSleepStart, in: timeZone)))
    }
    return first...max(first, current(now: now, in: timeZone))
  }

  public var days: [SleepDay] { (0..<7).map { SleepDay(named: monday.adding(days: $0)) } }

  public var sunday: SleepDay { SleepDay(named: monday.adding(days: 6)) }

  public func adding(weeks: Int) -> Week {
    Week(containing: SleepDay(named: monday.adding(days: 7 * weeks)))
  }

  public func contains(_ day: SleepDay) -> Bool {
    Week(containing: day) == self
  }

  /// "Mon 2 – Sun 8 Nov", or "Mon 30 Nov – Sun 6 Dec" across two months.
  public var title: String {
    let last = sunday.name
    let first = monday.month == last.month ? "\(monday.day)" : "\(monday.day) \(monday.shortMonth)"
    return "Mon \(first) – Sun \(last.day) \(last.shortMonth)"
  }

  public static func < (lhs: Week, rhs: Week) -> Bool { lhs.monday < rhs.monday }
}

/// The totals of each sleep day of a week, which days count, and how they compare with the recommended range.
public struct WeekStats: Sendable {
  /// A sleep day with sleep that has ended is counted. One that has not ended yet is so far.
  /// A day with no sleep in it is empty.
  public enum DayState: Sendable {
    case counted
    case soFar
    case empty
  }

  public enum Judgement: Sendable {
    case inRange
    case tooLittle
    case tooMuch
  }

  public struct Day: Sendable {
    public let sleepDay: SleepDay
    /// The time asleep inside the sleep day. A running sleep counts until now.
    public let total: TimeInterval
    public let state: DayState
    /// The recommended range for the child's age on this day.
    public let range: RecommendedRange

    /// How a counted day compares with its range. The limits are in range. `nil` for a day that is not counted.
    public var judgement: Judgement? {
      guard state == .counted else { return nil }
      if total < TimeInterval(range.lowerHours) * 3600 { return .tooLittle }
      if total > TimeInterval(range.upperHours) * 3600 { return .tooMuch }
      return .inRange
    }

    /// "Monday 2 Nov, 12 h 36 m", with " so far" on a day that has not ended.
    public var accessibilityLabel: String {
      let name = sleepDay.name
      let label = "\(name.weekdayName) \(name.day) \(name.shortMonth), \(SleepDuration.text(total))"
      return state == .soFar ? "\(label) so far" : label
    }
  }

  public let week: Week
  /// Monday to Sunday.
  public let days: [Day]

  /// `sleeps` are the sleeps of one child, born on `birthDate`.
  public init(week: Week, sleeps: [Sleep], birthDate: BirthDate, now: Date, in timeZone: TimeZone) {
    self.week = week
    days = week.days.map { sleepDay in
      let interval = sleepDay.interval(in: timeZone)
      let total = sleeps.reduce(0) { total, sleep in
        let start = max(sleep.start, interval.start)
        let end = min(sleep.end ?? now, interval.end)
        return total + max(0, end.timeIntervalSince(start))
      }
      let state: DayState = total <= 0 ? .empty : interval.end <= now ? .counted : .soFar
      return Day(
        sleepDay: sleepDay, total: total, state: state, range: RecommendedRange(birthDate: birthDate, on: sleepDay.name)
      )
    }
  }

  public var countedDays: [Day] { days.filter { $0.state == .counted } }

  /// True when any day of the week has sleep, also so far.
  public var hasSleep: Bool { days.contains { $0.state != .empty } }

  /// The range of the last day of the week, for the band and the "range" note.
  public var range: RecommendedRange { days[6].range }

  /// The mean total of the counted days, rounded to the nearest minute, half up. `nil` with no counted day.
  public var average: TimeInterval? {
    let counted = countedDays
    guard !counted.isEmpty else { return nil }
    let mean = counted.reduce(0) { $0 + $1.total } / Double(counted.count)
    return (mean / 60 + 0.5).rounded(.down) * 60
  }

  public var inRangeCount: Int { countedDays.filter { $0.judgement == .inRange }.count }

  /// "12 h 09 m", or "–" with no counted day.
  public var averageText: String { average.map(SleepDuration.text) ?? "–" }

  /// "4 of 7 days", "1 of 1 day", or "–" with no counted day.
  public var inRangeText: String {
    let count = countedDays.count
    guard count > 0 else { return "–" }
    return "\(inRangeCount) of \(count) day\(count == 1 ? "" : "s")"
  }
}

extension BirthDate {
  /// 0 for Monday to 6 for Sunday.
  var weekdayFromMonday: Int {
    // 1 January 1970 was a Thursday.
    ((dayNumber + 3) % 7 + 7) % 7
  }

  /// "Monday".
  var weekdayName: String {
    ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][weekdayFromMonday]
  }

  /// "Nov".
  var shortMonth: String {
    ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][month - 1]
  }
}
