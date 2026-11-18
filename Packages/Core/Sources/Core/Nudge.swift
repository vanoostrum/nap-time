import Foundation

/// A notification that asks a parent to check one child's log: no sleep logged by the usual bedtime plus one hour,
/// or a sleep that has run for 14 hours. Each phone plans its own nudges.
public struct Nudge: Equatable, Sendable {
  public enum Kind: String, Sendable {
    case bedtime
    case longSleep
  }

  /// The id of the notification request, from `NudgeID`.
  public let id: String
  public let fireDate: Date
  public let kind: Kind
  public let childID: UUID
  public let title: String
  public let body: String

  public init(id: String, fireDate: Date, kind: Kind, childID: UUID, title: String, body: String) {
    self.id = id
    self.fireDate = fireDate
    self.kind = kind
    self.childID = childID
    self.title = title
    self.body = body
  }
}

/// The ids of the app's notification requests.
public enum NudgeID {
  /// The long-sleep nudge of one sleep: "long-sleep-" and the sleep id.
  public static func longSleep(sleepID: UUID) -> String {
    "long-sleep-\(sleepID.uuidString)"
  }

  /// The bedtime nudge of one child on one evening: "bedtime-", the child id, and the date of the evening's 18:00.
  public static func bedtime(childID: UUID, evening: BirthDate) -> String {
    "bedtime-\(childID.uuidString)-\(evening.year)-\(twoDigits(evening.month))-\(twoDigits(evening.day))"
  }

  /// True for the id of a nudge, of either kind.
  public static func isNudge(_ id: String) -> Bool {
    id.hasPrefix("bedtime-") || id.hasPrefix("long-sleep-")
  }
}

/// The nudges that a phone plans for the children and their sleeps.
public enum NudgeSchedule {
  /// A running sleep gets its long-sleep nudge after this much real time.
  public static let longSleep: TimeInterval = 14 * 3600
  /// The evenings that the plan looks at: the evening that began the current sleep day, and the 6 after it.
  public static let horizon = 7
  /// A child gets bedtime nudges for at most this many evenings.
  public static let bedtimeEvenings = 5
  /// iOS keeps at most 64 pending notifications.
  public static let limit = 64
  /// An evening gets a bedtime nudge only with this many nights in its 7 sleep days before.
  public static let nightsNeeded = 3

  /// At most `limit` nudges, sorted by fire date, then by id. Each fire date is after `now`.
  ///
  /// Bedtime: an evening begins at 18:00 on a date. Its usual bedtime is `UsualBedtime` of the child's nights in the
  /// 7 sleep days that end at that 18:00, rounded to 5 minutes, and needs 3 nights. The nudge fires at the evening's
  /// date at 12:00, plus the usual bedtime counted from 12:00, plus 1 hour, in wall-clock time. A sleep that starts
  /// in the silence window, from the earlier of 18:00 and the usual bedtime up to the fire date, silences the
  /// evening. A running sleep silences the first evening whose fire date is after `now`.
  ///
  /// Long sleep: the running sleep with the earliest start, then the lowest id, fires at its start plus 14 hours.
  public static func nudges(children: [Child], sleeps: [Sleep], now: Date, timeZone: TimeZone) -> [Nudge] {
    let all = children.flatMap { child in
      let own = sleeps.filter { $0.childID == child.id }
      let bedtime = bedtimeNudges(child, own, now: now, timeZone: timeZone)
      return bedtime + [longSleepNudge(child, own, now: now)].compactMap { $0 }
    }
    let sorted = all.sorted { $0.fireDate != $1.fireDate ? $0.fireDate < $1.fireDate : $0.id < $1.id }
    return Array(sorted.prefix(limit))
  }

  private struct Evening {
    let date: BirthDate
    let bedtime: TimeOfDay
    let fireDate: Date
    let silenceStart: Date
    let since: TimeOfDay
  }

  private static func bedtimeNudges(_ child: Child, _ sleeps: [Sleep], now: Date, timeZone: TimeZone) -> [Nudge] {
    let first = SleepDay(containing: now, in: timeZone).name.adding(days: -1)
    let nights = sleeps.filter { $0.kind == .night }
    let evenings = (0..<horizon).compactMap { offset in
      evening(first.adding(days: offset), nights: nights, timeZone: timeZone)
    }
    let silencedByRunning =
      sleeps.contains(where: \.isRunning) ? evenings.first { $0.fireDate > now }?.date : nil
    return
      evenings
      .filter { evening in
        evening.fireDate > now && evening.date != silencedByRunning
          && !sleeps.contains { $0.start >= evening.silenceStart && $0.start < evening.fireDate }
      }
      .prefix(bedtimeEvenings)
      .map { evening in
        Nudge(
          id: NudgeID.bedtime(childID: child.id, evening: evening.date), fireDate: evening.fireDate, kind: .bedtime,
          childID: child.id, title: "Is \(child.name) asleep?",
          body: "No sleep logged for \(child.name) since \(evening.since). \(child.name) usually sleeps by "
            + "\(evening.bedtime).")
      }
  }

  private static func evening(_ date: BirthDate, nights: [Sleep], timeZone: TimeZone) -> Evening? {
    let window = date.adding(days: -6)...date
    let windowNights = nights.filter { window.contains(SleepDay(containing: $0.start, in: timeZone).name) }
    guard windowNights.count >= nightsNeeded,
      let bedtime = UsualBedtime(nights: windowNights, in: timeZone).bedtime?.roundedToFiveMinutes
    else { return nil }
    let afterNoon = TimeOfDay(seconds: bedtime.seconds - 12 * 3600).seconds
    let isBefore1800 = afterNoon < 6 * 3600
    return Evening(
      date: date, bedtime: bedtime,
      fireDate: wallClock(date, afterNoon: afterNoon + 3600, timeZone: timeZone),
      silenceStart: wallClock(date, afterNoon: isBefore1800 ? afterNoon : 6 * 3600, timeZone: timeZone),
      since: isBefore1800 ? bedtime : TimeOfDay(hour: 18, minute: 0))
  }

  /// The instant `afterNoon` of wall-clock time after 12:00 on `date`. A time in the gap of the change to summer
  /// time moves to the end of the gap, and a time in the repeated hour takes its first occurrence.
  private static func wallClock(_ date: BirthDate, afterNoon: TimeInterval, timeZone: TimeZone) -> Date {
    let day: TimeInterval = 24 * 3600
    let total = 12 * 3600 + afterNoon
    let calendar = Calendar.gregorian(in: timeZone)
    let midnight = date.adding(days: Int(total / day)).date(in: calendar)
    let minutes = Int(total.truncatingRemainder(dividingBy: day) / 60)
    let parts = DateComponents(hour: minutes / 60, minute: minutes % 60, second: 0)
    return calendar.nextDate(
      after: midnight.addingTimeInterval(-1), matching: parts, matchingPolicy: .nextTime, repeatedTimePolicy: .first,
      direction: .forward) ?? midnight
  }

  private static func longSleepNudge(_ child: Child, _ sleeps: [Sleep], now: Date) -> Nudge? {
    let earliest = sleeps.filter(\.isRunning).min { a, b in
      a.start != b.start ? a.start < b.start : a.id.uuidString < b.id.uuidString
    }
    guard let sleep = earliest else { return nil }
    let fireDate = sleep.start.addingTimeInterval(longSleep)
    guard fireDate > now else { return nil }
    return Nudge(
      id: NudgeID.longSleep(sleepID: sleep.id), fireDate: fireDate, kind: .longSleep, childID: child.id,
      title: "\(child.name) has slept 14 hours", body: "Still asleep? Open Nap Time to check the sleep.")
  }
}

/// The changes that make the pending notifications match a new list of nudges.
public struct NudgeSync: Equatable, Sendable {
  /// Every pending nudge id. Other ids stay.
  public let idsToRemove: [String]
  /// Every nudge of the new list.
  public let nudgesToAdd: [Nudge]

  public init(pendingIDs: [String], nudges: [Nudge]) {
    idsToRemove = pendingIDs.filter(NudgeID.isNudge)
    nudgesToAdd = nudges
  }
}
