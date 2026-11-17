import Foundation

/// Why the sleep form cannot save a sleep. The cases are in the order the form checks them.
public enum SleepProblem: Hashable, Sendable {
  /// The wake-up is less than `Sleep.shortest` after the start, or before it.
  case tooShort
  /// The start or the wake-up is after now.
  case inTheFuture
  /// The sleep is longer than `SleepSaveRule.longest`.
  case tooLong
  /// The sleep overlaps this other sleep of the same child.
  case overlaps(Sleep)

  /// The red reason line under "Woke up".
  public func text(childName: String, in timeZone: TimeZone) -> String {
    switch self {
    case .tooShort:
      return "Wake-up must be at least 1 minute after falling asleep."
    case .inTheFuture:
      return "This time is in the future."
    case .tooLong:
      return "A sleep can't be longer than 24 hours."
    case .overlaps(let other):
      let from = "This overlaps \(childName)'s \(other.kind.rawValue) from \(ClockTime.text(other.start, in: timeZone))"
      guard let end = other.end else { return "\(from), still asleep." }
      return "\(from) to \(ClockTime.text(end, in: timeZone))."
    }
  }
}

/// The rule that says whether the sleep form, and `FamilyStore.saveSleep`, can save a sleep.
public enum SleepSaveRule {
  /// The longest sleep that the form saves. "Wake up" keeps a longer one.
  public static let longest: TimeInterval = 24 * 3600

  /// The first problem of `sleep`, or `nil` when it can be saved.
  ///
  /// `others` are the saved sleeps; only those of the same child, other than `sleep` itself, count.
  /// A running sleep counts until `now`. For a running `sleep`, only the future rule and the overlap apply.
  public static func problem(of sleep: Sleep, among others: [Sleep], now: Date) -> SleepProblem? {
    if let end = sleep.end {
      let duration = end.timeIntervalSince(sleep.start)
      if duration < Sleep.shortest { return .tooShort }
      if sleep.start > now || end > now { return .inTheFuture }
      if duration > longest { return .tooLong }
    } else if sleep.start > now {
      return .inTheFuture
    }
    let end = sleep.end ?? now
    let overlapping = others.first { other in
      other.childID == sleep.childID && other.id != sleep.id && other.start < end && sleep.start < (other.end ?? now)
    }
    return overlapping.map(SleepProblem.overlaps)
  }
}

/// The values that "Add a sleep from earlier" starts with.
public struct SleepStartValues: Hashable, Sendable {
  public let fellAsleep: Date
  public let wokeUp: Date
  /// The night-or-nap guess from `fellAsleep`.
  public let kind: SleepKind

  public init(fellAsleep: Date, wokeUp: Date, kind: SleepKind) {
    self.fellAsleep = fellAsleep
    self.wokeUp = wokeUp
    self.kind = kind
  }

  /// For the current sleep day: "Woke up" at `now` rounded down to 5 minutes, "Fell asleep" 1 hour before.
  public static func today(now: Date, in timeZone: TimeZone) -> SleepStartValues {
    let calendar = Calendar.gregorian(in: timeZone)
    let parts = calendar.dateComponents([.minute, .second, .nanosecond], from: now)
    let extra = TimeInterval((parts.minute ?? 0) % 5 * 60 + (parts.second ?? 0)) + Double(parts.nanosecond ?? 0) / 1e9
    let wokeUp = now.addingTimeInterval(-extra)
    let fellAsleep = wokeUp.addingTimeInterval(-3600)
    return SleepStartValues(
      fellAsleep: fellAsleep, wokeUp: wokeUp, kind: SleepKind.guess(start: fellAsleep, in: timeZone))
  }
}

/// A time on the sleep form.
public enum SleepFormTime {
  private static let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

  /// "Sun 21 Jun · 09:00", in `timeZone`.
  public static func text(_ instant: Date, in timeZone: TimeZone) -> String {
    let parts = Calendar.gregorian(in: timeZone).dateComponents([.weekday, .day, .month], from: instant)
    let weekday = weekdays[((parts.weekday ?? 1) - 1) % 7]
    let month = months[((parts.month ?? 1) - 1) % 12]
    return "\(weekday) \(parts.day ?? 1) \(month) · \(ClockTime.text(instant, in: timeZone))"
  }
}
