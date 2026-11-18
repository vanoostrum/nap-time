import Foundation

/// A time on the clock, from 00:00 to 23:59:59.
public struct TimeOfDay: Hashable, Sendable, CustomStringConvertible {
  /// Seconds after midnight, from 0 to less than 24 hours.
  public let seconds: TimeInterval

  public init(hour: Int, minute: Int, second: Double = 0) {
    self.init(seconds: TimeInterval(hour * 3600 + minute * 60) + second)
  }

  init(seconds: TimeInterval) {
    let day: TimeInterval = 24 * 3600
    self.seconds = seconds.truncatingRemainder(dividingBy: day) + (seconds < 0 ? day : 0)
  }

  /// The clock time of `instant` in `timeZone`.
  init(_ instant: Date, in timeZone: TimeZone) {
    let parts = Calendar.gregorian(in: timeZone).dateComponents([.hour, .minute, .second, .nanosecond], from: instant)
    self.init(
      hour: parts.hour ?? 0, minute: parts.minute ?? 0,
      second: Double(parts.second ?? 0) + Double(parts.nanosecond ?? 0) / 1e9)
  }

  /// The nearest 5 minutes, half up: 19:47:30 becomes 19:50, and 23:57:30 becomes 00:00.
  public var roundedToFiveMinutes: TimeOfDay {
    TimeOfDay(seconds: (seconds / 300 + 0.5).rounded(.down) * 300)
  }

  /// "06:55". Seconds are dropped.
  public var description: String {
    let minutes = Int(seconds / 60)
    let hour = minutes / 60
    let minute = minutes % 60
    return "\(hour < 10 ? "0" : "")\(hour):\(minute < 10 ? "0" : "")\(minute)"
  }
}

/// The usual bedtime and the usual wake-up time of a set of nights: the median start time and end time.
public struct UsualBedtime: Equatable, Sendable {
  /// The median start time, measured from 12:00, so 00:20 sorts after 23:50 and 17:45 sorts as early.
  /// `nil` with no nights.
  public let bedtime: TimeOfDay?
  /// The median end time of the ended nights, measured from 18:00. `nil` with no ended night.
  public let wakeUp: TimeOfDay?

  /// `nights` are nights of one child. With an even count, the median is the mean of the middle two.
  public init(nights: [Sleep], in timeZone: TimeZone) {
    bedtime = Self.median(nights.map(\.start), from: 12, in: timeZone)
    wakeUp = Self.median(nights.compactMap(\.end), from: 18, in: timeZone)
  }

  /// The nights among `sleeps` that start in a sleep day of `week`.
  public static func nights(of sleeps: [Sleep], in week: Week, timeZone: TimeZone) -> [Sleep] {
    sleeps.filter { $0.kind == .night && week.contains(SleepDay(containing: $0.start, in: timeZone)) }
  }

  /// "bed ~19:45 · up ~06:30", each rounded to 5 minutes, with "–" for a missing time.
  public var note: String {
    func text(_ time: TimeOfDay?) -> String { time.map { "~\($0.roundedToFiveMinutes)" } ?? "–" }
    return "bed \(text(bedtime)) · up \(text(wakeUp))"
  }

  /// How much the bedtimes of `nights` move around: the average distance of each start time from their mean,
  /// measured from 12:00 like the usual bedtime. `nil` with fewer than 2 nights.
  public static func spread(of nights: [Sleep], in timeZone: TimeZone) -> TimeInterval? {
    let offsets = offsets(nights.map(\.start), from: 12, in: timeZone)
    guard offsets.count >= 2 else { return nil }
    let mean = offsets.reduce(0, +) / Double(offsets.count)
    return offsets.reduce(0) { $0 + abs($1 - mean) } / Double(offsets.count)
  }

  private static func median(_ instants: [Date], from hour: Int, in timeZone: TimeZone) -> TimeOfDay? {
    let offsets = offsets(instants, from: hour, in: timeZone).sorted()
    guard !offsets.isEmpty else { return nil }
    let middle = offsets.count / 2
    let median = offsets.count % 2 == 1 ? offsets[middle] : (offsets[middle - 1] + offsets[middle]) / 2
    return TimeOfDay(seconds: median + TimeInterval(hour * 3600))
  }

  /// The clock time of each instant as the time since `hour`: from 0 to less than 24 hours.
  private static func offsets(_ instants: [Date], from hour: Int, in timeZone: TimeZone) -> [TimeInterval] {
    let origin = TimeInterval(hour * 3600)
    return instants.map { TimeOfDay(seconds: TimeOfDay($0, in: timeZone).seconds - origin).seconds }
  }
}
