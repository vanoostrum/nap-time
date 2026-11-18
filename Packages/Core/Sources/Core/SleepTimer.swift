import Foundation

/// One sleep timer on this phone, as the app reads it from a Live Activity that is pending or showing.
public struct SleepTimerSnapshot: Equatable, Sendable {
  /// The id of the Live Activity.
  public var id: String
  public var childID: UUID
  public var sleepID: UUID
  /// The start of the sleep that the timer counts from.
  public var start: Date
  public var kind: SleepKind
  /// The scheduled start of the Live Activity, or `nil` for a timer that started at once.
  public var showsFrom: Date?
  /// True when the Live Activity shows, false while it waits for its scheduled start.
  public var isShowing: Bool

  public init(
    id: String, childID: UUID, sleepID: UUID, start: Date, kind: SleepKind, showsFrom: Date?, isShowing: Bool
  ) {
    self.id = id
    self.childID = childID
    self.sleepID = sleepID
    self.start = start
    self.kind = kind
    self.showsFrom = showsFrom
    self.isShowing = isShowing
  }
}

/// What the app does to one sleep timer so that it matches the running sleeps.
public enum SleepTimerChange: Equatable, Sendable {
  /// Give the timer `id` this content.
  case update(id: String, sleepID: UUID, start: Date, kind: SleepKind)
  /// End the timer `id`, and request a new timer that shows from `showsFrom`, or now when it is `nil`.
  case replace(id: String, sleepID: UUID, start: Date, kind: SleepKind, showsFrom: Date?)
  /// End the timer `id`.
  case end(id: String)
}

/// The rules of the sleep timer on the Lock Screen and in the Dynamic Island (ADR 0008).
public enum SleepTimerRule {
  /// When the timer of a running sleep shows: `nil` for now, or the scheduled date.
  ///
  /// A nap shows now. A night shows from 04:00 on the wall clock of `timeZone`: on the same date for a night that
  /// starts from 00:00 to 03:59, on the next date for a night that starts from 12:00 to 23:59. A night that starts
  /// from 04:00 to 11:59 shows now. A scheduled date that is not after `now` gives now.
  public static func start(for sleep: Sleep, now: Date, timeZone: TimeZone) -> Date? {
    guard sleep.kind == .night else { return nil }
    let calendar = Calendar.gregorian(in: timeZone)
    let hour = calendar.component(.hour, from: sleep.start)
    guard hour < 4 || hour >= 12 else { return nil }
    let date = BirthDate(sleep.start, in: calendar)
    let day = hour < 4 ? date : date.adding(days: 1)
    let parts = DateComponents(year: day.year, month: day.month, day: day.day, hour: 4)
    guard let scheduled = calendar.date(from: parts), scheduled > now else { return nil }
    return scheduled
  }

  /// The changes that make the timers on this phone match the running sleeps: at most one change per timer.
  ///
  /// A child keeps one timer: the one for a running sleep of the child, else the earliest start, then the lowest
  /// sleep id, then the lowest timer id. The others end. A timer follows its own sleep, or else the child's running
  /// sleep that starts at or before the timer's start: the sleep that a merge keeps. With no such sleep it ends.
  /// A running sleep without a timer gets none: only "Sleep time" asks for a timer.
  public static func changes(
    timers: [SleepTimerSnapshot], runningSleeps: [Sleep], now: Date, timeZone: TimeZone
  ) -> [SleepTimerChange] {
    var changes: [SleepTimerChange] = []
    var children: [UUID] = []
    for timer in timers where !children.contains(timer.childID) {
      children.append(timer.childID)
    }
    for child in children {
      let running = runningSleeps.filter { $0.childID == child && $0.isRunning }
      let childTimers = timers.filter { $0.childID == child }
      let withRunningID = childTimers.filter { timer in running.contains { $0.id == timer.sleepID } }
      let kept = (withRunningID.isEmpty ? childTimers : withRunningID).min(by: isBefore)!
      for timer in childTimers where timer.id != kept.id {
        changes.append(.end(id: timer.id))
      }
      if let change = change(of: kept, running: running, now: now, timeZone: timeZone) {
        changes.append(change)
      }
    }
    return changes
  }

  /// "Awake" on a timer ends the sleep only when the child's running sleep has the timer's sleep id. So it never
  /// ends a newer sleep, and does nothing for a sleep that has ended or that a merge deleted.
  public static func awakeEndsSleep(sleepID: UUID, childSleeps: [Sleep]) -> Bool {
    childSleeps.contains { $0.id == sleepID && $0.isRunning }
  }

  private static func change(
    of timer: SleepTimerSnapshot, running: [Sleep], now: Date, timeZone: TimeZone
  ) -> SleepTimerChange? {
    let followed =
      running.first { $0.id == timer.sleepID }
      ?? running.filter { $0.start <= timer.start }.min { a, b in
        a.start != b.start ? a.start < b.start : a.id.uuidString < b.id.uuidString
      }
    guard let sleep = followed else { return .end(id: timer.id) }
    let showsFrom = start(for: sleep, now: now, timeZone: timeZone)
    // A timer that shows already counts as now.
    let current = timer.isShowing ? nil : timer.showsFrom
    if showsFrom != current {
      return .replace(id: timer.id, sleepID: sleep.id, start: sleep.start, kind: sleep.kind, showsFrom: showsFrom)
    }
    if sleep.id != timer.sleepID || sleep.start != timer.start || sleep.kind != timer.kind {
      return .update(id: timer.id, sleepID: sleep.id, start: sleep.start, kind: sleep.kind)
    }
    return nil
  }

  private static func isBefore(_ a: SleepTimerSnapshot, _ b: SleepTimerSnapshot) -> Bool {
    if a.start != b.start { return a.start < b.start }
    if a.sleepID != b.sleepID { return a.sleepID.uuidString < b.sleepID.uuidString }
    return a.id < b.id
  }
}

/// The ids of the app's notification requests.
public enum NudgeID {
  /// The long-sleep nudge of one sleep: "long-sleep-" and the sleep id.
  public static func longSleep(sleepID: UUID) -> String {
    "long-sleep-\(sleepID.uuidString)"
  }
}
