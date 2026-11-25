import Foundation

/// A 30-minute span of bedtimes that the app suggests: the usual wake-up time minus the night the child needs,
/// which is the middle of the recommended range minus the child's naps.
public struct BedtimeWindow: Equatable, Sendable {
  public let start: TimeOfDay
  public let end: TimeOfDay

  public init(start: TimeOfDay, end: TimeOfDay) {
    self.start = start
    self.end = end
  }

  /// The window around the ideal bedtime: the rounded usual wake-up time minus the middle of `range`
  /// plus `averageNap`. It runs from 15 minutes before to 15 minutes after, each end rounded to 5 minutes.
  /// `nil` without a usual wake-up time.
  public init?(wakeUp: TimeOfDay?, range: RecommendedRange, averageNap: TimeInterval) {
    guard let wakeUp else { return nil }
    let night = TimeInterval(range.lowerHours + range.upperHours) * 1800 - averageNap
    let ideal = wakeUp.roundedToFiveMinutes.seconds - night
    start = TimeOfDay(seconds: ideal - 15 * 60).roundedToFiveMinutes
    end = TimeOfDay(seconds: ideal + 15 * 60).roundedToFiveMinutes
  }

  /// The mean nap time per sleep day of `days`: each nap counts whole for the day it starts in, as the hours per
  /// day do (ADR 0006).
  /// 0 with no days.
  public static func averageNap(of sleeps: [Sleep], on days: [SleepDay], now: Date, in timeZone: TimeZone)
    -> TimeInterval
  {
    guard !days.isEmpty else { return 0 }
    let naps = sleeps.filter { $0.kind == .nap }
    return days.reduce(0) { $0 + $1.asleep(startingIn: naps, now: now, in: timeZone) } / Double(days.count)
  }
}

/// The "What to try" card of a week: one tip from the child's week with its bedtime window, or "keep logging"
/// before the week has 4 counted days.
public struct WhatToTry: Sendable {
  /// The tip from the child's week. Only the first that applies shows, in the order of the cases.
  public enum Tip: Equatable, Sendable {
    /// The bedtimes move around by more than 30 minutes: the average distance from the mean bedtime.
    case bedtimesVary(distance: TimeInterval)
    /// The average of the counted days is below the range.
    case tooLittle(average: TimeInterval)
    /// The average of the counted days is above the range.
    case tooMuch(average: TimeInterval)
    /// On `days` counted days, the last nap ended less than 3 hours before the usual bedtime.
    case lateNap(days: Int)
    case praise(inRange: Int, counted: Int)
  }

  public enum Content: Equatable, Sendable {
    case tip(Tip)
    /// The week has sleeps, but fewer than 4 counted days.
    case keepLogging(countedDays: Int)
  }

  /// The text of the tip or of "keep logging", and the part in bold after it.
  public struct Message: Equatable, Sendable {
    public let text: String
    /// `nil` for a tip without a bedtime window.
    public let bold: String?

    public init(text: String, bold: String?) {
      self.text = text
      self.bold = bold
    }
  }

  /// The counted days a week needs before it shows a tip.
  public static let neededDays = 4

  public let content: Content
  /// The window for the tip. `nil` while the card asks to keep logging, and without a usual wake-up time.
  public let window: BedtimeWindow?
  /// The range of the last day of the week.
  public let range: RecommendedRange
  /// The child is under 1 on the last day of the week.
  public let isUnderOne: Bool
  /// The week holds the current sleep day.
  public let isCurrentWeek: Bool

  /// The card for `week`. `sleeps` are the sleeps of one child, born on `birthDate`. `nil` for a week with no sleeps.
  public init?(week: Week, sleeps: [Sleep], birthDate: BirthDate, now: Date, in timeZone: TimeZone) {
    let stats = WeekStats(week: week, sleeps: sleeps, birthDate: birthDate, now: now, in: timeZone)
    guard stats.hasSleep else { return nil }
    range = stats.range
    isUnderOne = Age(of: birthDate, on: week.sunday.name).months < 12
    isCurrentWeek = week == Week.current(now: now, in: timeZone)
    let counted = stats.countedDays
    guard counted.count >= Self.neededDays, let average = stats.average else {
      content = .keepLogging(countedDays: counted.count)
      window = nil
      return
    }
    let nights = UsualBedtime.nights(of: sleeps, in: week, timeZone: timeZone)
    let usual = UsualBedtime(nights: nights, in: timeZone)
    window = BedtimeWindow(
      wakeUp: usual.wakeUp, range: range,
      averageNap: BedtimeWindow.averageNap(of: sleeps, on: counted.map(\.sleepDay), now: now, in: timeZone))
    content = .tip(
      Self.tip(
        stats: stats, average: average, nights: nights, bedtime: isUnderOne ? nil : usual.bedtime,
        sleeps: sleeps, now: now, in: timeZone))
  }

  /// The first tip that applies. `bedtime` is `nil` when the late-nap tip does not apply.
  private static func tip(
    stats: WeekStats, average: TimeInterval, nights: [Sleep], bedtime: TimeOfDay?, sleeps: [Sleep], now: Date,
    in timeZone: TimeZone
  ) -> Tip {
    if let distance = UsualBedtime.spread(of: nights, in: timeZone), distance > 30 * 60 {
      return .bedtimesVary(distance: distance)
    }
    switch WeekStats.Judgement(total: average, range: stats.range) {
    case .tooLittle: return .tooLittle(average: average)
    case .tooMuch: return .tooMuch(average: average)
    case .inRange: break
    }
    if let bedtime = bedtime?.roundedToFiveMinutes {
      let late = stats.countedDays.filter {
        lastNapEndsLate(on: $0.sleepDay, bedtime: bedtime, sleeps: sleeps, now: now, in: timeZone)
      }
      if late.count >= 2 {
        return .lateNap(days: late.count)
      }
    }
    return .praise(inRange: stats.inRangeCount, counted: stats.countedDays.count)
  }

  /// True when the last nap of `day`, the nap with the latest start inside it, ends less than 3 hours
  /// before `bedtime` on the evening of `day`. It uses the real end, also after 18:00.
  private static func lastNapEndsLate(
    on day: SleepDay, bedtime: TimeOfDay, sleeps: [Sleep], now: Date, in timeZone: TimeZone
  ) -> Bool {
    let interval = day.interval(in: timeZone)
    let lastNap =
      sleeps
      .filter { $0.kind == .nap && $0.start >= interval.start && $0.start < interval.end }
      .max { $0.start < $1.start }
    guard let lastNap else { return false }
    // The bedtime after the day: on its named date, or on the next date for a bedtime after midnight.
    let date = bedtime.seconds >= 12 * 3600 ? day.name : day.name.adding(days: 1)
    let seconds = Int(bedtime.seconds)
    let parts = DateComponents(
      year: date.year, month: date.month, day: date.day, hour: seconds / 3600, minute: seconds / 60 % 60,
      second: seconds % 60)
    guard let bedtimeInstant = Calendar.gregorian(in: timeZone).date(from: parts) else { return false }
    return bedtimeInstant.timeIntervalSince(lastNap.end ?? now) < 3 * 3600
  }

  /// The tip or "keep logging" for the child named `name`.
  public func message(name: String) -> Message {
    Self.message(content, window: window, range: range, isCurrentWeek: isCurrentWeek, name: name)
  }

  /// The text of `content`, with the bold part from `window`.
  public static func message(
    _ content: Content, window: BedtimeWindow?, range: RecommendedRange, isCurrentWeek: Bool, name: String
  ) -> Message {
    let between = window.map { "between \($0.start) and \($0.end)" }
    switch content {
    case .keepLogging(let days):
      return Message(
        text: "Keep logging. With sleeps on \(neededDays) days of the week, Nap Time shows what to try for \(name).",
        bold: "\(days) of \(neededDays) days \(isCurrentWeek ? "so far" : "logged").")
    case .tip(.bedtimesVary(let distance)):
      return Message(
        text: "\(name)'s bedtime moved around by about \(aboutText(distance)) this week.",
        bold: between.map { "Try a fixed bedtime \($0)." })
    case .tip(.tooLittle(let average)):
      return Message(
        text: "\(name) slept \(SleepDuration.text(average)) a day on average, below the \(range) range.",
        bold: between.map { "Try a bedtime \($0)." })
    case .tip(.tooMuch(let average)):
      return Message(
        text: "\(name) slept \(SleepDuration.text(average)) a day on average, above the \(range) range.",
        bold: between.map { "Try a bedtime \($0)." })
    case .tip(.lateNap(let days)):
      let napEnd = window.map { TimeOfDay(seconds: $0.start.seconds - 3 * 3600) }
      return Message(
        text: "\(name)'s last nap ended less than 3 hours before bedtime on \(days) days.",
        bold: both(napEnd, between).map { "Try to end it by \($0), and go to bed \($1)." })
    case .tip(.praise(let inRange, let counted)):
      return Message(
        text: "\(name) slept well this week: in range on \(inRange) of \(counted) days.",
        bold: between.map { "Keep a bedtime \($0)." })
    }
  }

  /// "40 minutes", or "1 h 10 m" from 60 minutes: `distance` rounded to the nearest 5 minutes, half up, first.
  private static func aboutText(_ distance: TimeInterval) -> String {
    let rounded = (distance / 300 + 0.5).rounded(.down) * 300
    return rounded >= 3600 ? SleepDuration.text(rounded) : "\(Int(rounded / 60)) minutes"
  }

  /// The three general tips. For a child under 1, the third is about the same steps every night.
  public var generalTips: [String] {
    [
      "Start a calm wind-down 30 minutes before bed.",
      "Keep the same wake-up time, also at the weekend.",
      isUnderOne
        ? "Follow the same steps every night, like a bath, a feed, and a song."
        : "End the last nap at least 3 hours before bedtime.",
    ]
  }

  /// "These are general tips. If you are worried about Mila's sleep, ask your doctor."
  public static func doctorLine(name: String) -> String {
    "These are general tips. If you are worried about \(name)'s sleep, ask your doctor."
  }
}

/// Both values, or `nil` when either is `nil`.
private func both<A, B>(_ first: A?, _ second: B?) -> (A, B)? {
  guard let first, let second else { return nil }
  return (first, second)
}
