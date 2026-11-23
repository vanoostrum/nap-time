import Core
import Foundation
import Testing

@Suite struct SleepTests {
  private let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!
  private let utc = TimeZone(identifier: "UTC")!
  private let child = UUID()

  // MARK: Night or nap

  @Test(arguments: [
    ("2026-06-21T17:59:00+02:00", SleepKind.nap),
    ("2026-06-21T18:00:00+02:00", .night),
    ("2026-06-21T05:59:00+02:00", .night),
    ("2026-06-21T06:00:00+02:00", .nap),
    ("2026-06-21T00:00:00+02:00", .night),
    ("2026-06-21T13:05:00+02:00", .nap),
  ])
  func theGuessIsANightFrom18To0559(start: String, kind: SleepKind) {
    #expect(SleepKind.guess(start: date(start), in: amsterdam) == kind)
  }

  @Test func theGuessUsesTheGivenTimeZone() {
    let instant = date("2026-06-21T17:30:00Z")
    #expect(SleepKind.guess(start: instant, in: amsterdam) == .night)
    #expect(SleepKind.guess(start: instant, in: utc) == .nap)
  }

  // MARK: Main button title

  @Test func aNapStartsWithNapTimeAndANightWithSleepTime() {
    #expect(SleepKind.nap.startTitle == "Nap time")
    #expect(SleepKind.night.startTitle == "Sleep time")
  }

  // Summer time starts at 02:00 on 29 March 2026 and ends at 03:00 on 25 October 2026.
  @Test(arguments: [
    ("2026-06-21T05:59:00+02:00", "Sleep time"),
    ("2026-06-21T06:00:00+02:00", "Nap time"),
    ("2026-06-21T17:59:00+02:00", "Nap time"),
    ("2026-06-21T18:00:00+02:00", "Sleep time"),
    ("2026-03-29T05:59:00+02:00", "Sleep time"),
    ("2026-03-29T06:00:00+02:00", "Nap time"),
    ("2026-03-29T17:59:00+02:00", "Nap time"),
    ("2026-03-29T18:00:00+02:00", "Sleep time"),
    ("2026-10-25T05:59:00+01:00", "Sleep time"),
    ("2026-10-25T06:00:00+01:00", "Nap time"),
    ("2026-10-25T17:59:00+01:00", "Nap time"),
    ("2026-10-25T18:00:00+01:00", "Sleep time"),
  ])
  func theMainButtonSaysNapTimeFrom06To1759(now: String, title: String) {
    #expect(SleepKind.guess(start: date(now), in: amsterdam).startTitle == title)
  }

  // MARK: Sleep day

  @Test func aSleepDayIsNamedAfterTheDateItEndsOn() {
    #expect(SleepDay(containing: date("2026-06-21T17:59:59+02:00"), in: amsterdam).name == day(2026, 6, 21))
    #expect(SleepDay(containing: date("2026-06-21T18:00:00+02:00"), in: amsterdam).name == day(2026, 6, 22))
    #expect(SleepDay(containing: date("2026-06-21T00:30:00+02:00"), in: amsterdam).name == day(2026, 6, 21))
  }

  @Test func oneInstantFallsInADifferentSleepDayPerTimeZone() {
    let instant = date("2026-06-21T17:30:00Z")
    #expect(SleepDay(containing: instant, in: amsterdam).name == day(2026, 6, 22))
    #expect(SleepDay(containing: instant, in: utc).name == day(2026, 6, 21))
    #expect(ClockTime.text(instant, in: amsterdam) == "19:30")
    #expect(ClockTime.text(instant, in: utc) == "17:30")
  }

  @Test func aSleepDayRunsFrom18To18AndIs23Or25HoursAtAClockChange() {
    let june = SleepDay(named: day(2026, 6, 21)).interval(in: amsterdam)
    #expect(june.start == date("2026-06-20T18:00:00+02:00"))
    #expect(june.end == date("2026-06-21T18:00:00+02:00"))
    // Summer time starts on Sunday 29 March 2026, winter time on Sunday 25 October 2026.
    #expect(SleepDay(named: day(2026, 3, 29)).interval(in: amsterdam).duration == 23 * 3600)
    #expect(SleepDay(named: day(2026, 10, 25)).interval(in: amsterdam).duration == 25 * 3600)
  }

  // MARK: Slept today

  @Test func sleptTodayCutsASleepAt18() {
    // A nap from 17:00 to 18:30: 1 h for 21 June, 30 m for 22 June.
    let nap = sleep("2026-06-21T17:00:00+02:00", "2026-06-21T18:30:00+02:00")
    #expect(SleptToday.total(of: [nap], now: date("2026-06-21T17:59:00+02:00"), in: amsterdam) == 3600)
    let night = sleep("2026-06-21T19:00:00+02:00", "2026-06-22T07:00:00+02:00")
    #expect(
      SleptToday.total(of: [nap, night], now: date("2026-06-22T08:00:00+02:00"), in: amsterdam) == 1800 + 12 * 3600)
  }

  @Test func inTheEveningSleptTodayCountsTheSleepDayThatJustEnded() {
    let lastNight = sleep("2026-06-20T19:45:00+02:00", "2026-06-21T06:55:00+02:00")
    let tonight = sleep("2026-06-21T19:42:00+02:00", "2026-06-21T21:56:00+02:00")
    let total = SleptToday.total(of: [lastNight, tonight], now: date("2026-06-21T21:56:00+02:00"), in: amsterdam)
    #expect(total == 11 * 3600 + 10 * 60)
  }

  @Test func aRunningSleepCountsUntilNow() {
    let lastNight = sleep("2026-06-20T19:45:00+02:00", "2026-06-21T06:55:00+02:00")
    let nap = sleep("2026-06-21T13:05:00+02:00", nil)
    let total = SleptToday.total(of: [lastNight, nap], now: date("2026-06-21T13:50:00+02:00"), in: amsterdam)
    #expect(total == 11 * 3600 + 55 * 60)
  }

  @Test func totalsAcrossTheClockChangesAreTheRealTimeAsleep() {
    // Winter time: 03:00 becomes 02:00 on 25 October 2026, so 20:00 to 07:00 is 12 hours.
    let autumn = sleep("2026-10-24T20:00:00+02:00", "2026-10-25T07:00:00+01:00")
    #expect(SleptToday.total(of: [autumn], now: date("2026-10-25T09:00:00+01:00"), in: amsterdam) == 12 * 3600)
    // Summer time: 02:00 becomes 03:00 on 29 March 2026, so 20:00 to 07:00 is 10 hours.
    let spring = sleep("2026-03-28T20:00:00+01:00", "2026-03-29T07:00:00+02:00")
    #expect(SleptToday.total(of: [spring], now: date("2026-03-29T09:00:00+02:00"), in: amsterdam) == 10 * 3600)
    // A nap across 18:00 on the day of the change is still cut at 18:00 local time.
    let nap = sleep("2026-10-25T17:30:00+01:00", "2026-10-25T18:30:00+01:00")
    #expect(SleptToday.total(of: [nap], now: date("2026-10-25T17:59:00+01:00"), in: amsterdam) == 1800)
    #expect(
      ChildStatus(sleeps: [autumn], now: date("2026-10-25T07:00:00+01:00"), in: amsterdam).line
        == "since 07:00 · 12 h 00 m slept today")
  }

  // MARK: Durations

  @Test(
    arguments: [
      (0, "0 m"), (59, "59 m"), (45, "45 m"), (60, "1 h 00 m"), (725, "12 h 05 m"), (134, "2 h 14 m"),
    ] as [(Int, String)])
  func aDurationReadsInHoursAndTwoDigitMinutes(minutes: Int, text: String) {
    #expect(SleepDuration.text(TimeInterval(minutes * 60)) == text)
    #expect(SleepDuration.text(TimeInterval(minutes * 60 + 59)) == text)
  }

  // MARK: Status

  /// At 21:56 on 21 June the sunset phase runs, and a running night follows the sun.
  @Test func aRunningNightShowsItsWholeDurationAndTheSkyOfTheSun() {
    let status = ChildStatus(
      sleeps: [sleep("2026-06-21T19:42:00+02:00", nil, kind: .night), lastNight],
      now: date("2026-06-21T21:56:00+02:00"), in: amsterdam)
    #expect(status.isSleeping)
    #expect(status.sky == .sunset)
    #expect(status.line == "2 h 14 m · since 19:42")
    #expect(status.heading(name: "Mila") == "Mila is sleeping")
  }

  @Test func aRunningNapShowsTheDaySky() {
    let status = ChildStatus(
      sleeps: [sleep("2026-06-21T13:05:00+02:00", nil, kind: .nap), lastNight],
      now: date("2026-06-21T13:50:00+02:00"), in: amsterdam)
    #expect(status.sky == .day)
    #expect(status.line == "45 m · since 13:05")
  }

  @Test func aRunningSleepOverTheCutShowsItsWholeDuration() {
    let status = ChildStatus(
      sleeps: [sleep("2026-06-21T17:00:00+02:00", nil, kind: .nap)], now: date("2026-06-21T18:30:00+02:00"),
      in: amsterdam)
    #expect(status.line == "1 h 30 m · since 17:00")
  }

  @Test func anAwakeChildShowsSinceOnlyForASleepThatEndedInThePast24Hours() {
    let awake = ChildStatus(sleeps: [lastNight], now: date("2026-06-21T10:00:00+02:00"), in: amsterdam)
    #expect(!awake.isSleeping)
    #expect(awake.sky == .day)
    #expect(awake.line == "since 06:55 · 11 h 10 m slept today")
    #expect(awake.heading(name: "Mila") == "Mila is awake")

    let older = ChildStatus(sleeps: [lastNight], now: date("2026-06-22T07:00:00+02:00"), in: amsterdam)
    #expect(older.line == "0 m slept today")
  }

  @Test func aChildWithNoSleepsHasSlept0Minutes() {
    let status = ChildStatus(sleeps: [], now: date("2026-06-21T10:00:00+02:00"), in: amsterdam)
    #expect(status.line == "0 m slept today")
    #expect(status.sky == .day)
  }

  // MARK: Helpers

  private var lastNight: Sleep { sleep("2026-06-20T19:45:00+02:00", "2026-06-21T06:55:00+02:00", kind: .night) }

  private func sleep(_ start: String, _ end: String?, kind: SleepKind = .nap) -> Sleep {
    Sleep(id: UUID(), childID: child, start: date(start), end: end.map(date), kind: kind)
  }
}

func date(_ iso: String) -> Date {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime]
  return formatter.date(from: iso)!
}
