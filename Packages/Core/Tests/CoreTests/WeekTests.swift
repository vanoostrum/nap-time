import Core
import Foundation
import Testing

@Suite struct WeekTests {
  private let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!
  private let child = UUID()
  /// Mila's birthdate: 1 year old in November 2026, so 11–14 h.
  private let mila = BirthDate(year: 2025, month: 3, day: 12)!

  // MARK: The week of a date

  @Test func sundayAt1759IsInTheWeekThatEndsThatSundayAnd1800IsInTheNextWeek() {
    let before = Week.current(now: date("2026-11-08T17:59:00+01:00"), in: amsterdam)
    let after = Week.current(now: date("2026-11-08T18:00:00+01:00"), in: amsterdam)
    #expect(before.monday == day(2026, 11, 2))
    #expect(after.monday == day(2026, 11, 9))
    #expect(after == before.adding(weeks: 1))
  }

  @Test func onSundayEveningTheChartsOpenOnTheWeekThatJustEnded() {
    let now = date("2026-11-08T19:00:00+01:00")
    #expect(Week.opening(now: now, in: amsterdam).monday == day(2026, 11, 2))
    #expect(Week.current(now: now, in: amsterdam).monday == day(2026, 11, 9))
  }

  @Test func aWeekHasSevenSleepDaysFromMondayToSunday() {
    let week = Week(containing: SleepDay(named: day(2026, 11, 5)))
    #expect(week.days.map(\.name) == (2...8).map { day(2026, 11, $0) })
    #expect(week.sunday.name == day(2026, 11, 8))
  }

  @Test(arguments: [
    ((2026, 11, 2), "Mon 2 – Sun 8 Nov"),
    ((2026, 11, 30), "Mon 30 Nov – Sun 6 Dec"),
    ((2026, 12, 28), "Mon 28 Dec – Sun 3 Jan"),
  ])
  func theTitleNamesTheFirstAndTheLastDay(monday: (Int, Int, Int), title: String) {
    #expect(Week(containing: SleepDay(named: day(monday.0, monday.1, monday.2))).title == title)
  }

  // MARK: How far the arrows go

  @Test func theArrowsRunFromTheWeekOfTheFirstSleepToTheCurrentWeek() {
    let weeks = Week.reachable(
      firstSleepStart: date("2026-06-20T19:45:00+02:00"), now: date("2026-11-11T10:00:00+01:00"), in: amsterdam)
    #expect(weeks.lowerBound.monday == day(2026, 6, 15))
    #expect(weeks.upperBound.monday == day(2026, 11, 9))
  }

  @Test func aChildWithNoSleepsHasOneWeekOnAWeekday() {
    let weeks = Week.reachable(firstSleepStart: nil, now: date("2026-11-11T10:00:00+01:00"), in: amsterdam)
    #expect(weeks.lowerBound == weeks.upperBound)
    #expect(weeks.lowerBound.monday == day(2026, 11, 9))
  }

  @Test func aChildWithNoSleepsOnSundayAt1900CanGoToTheCurrentWeekButNotBack() {
    let now = date("2026-11-08T19:00:00+01:00")
    let weeks = Week.reachable(firstSleepStart: nil, now: now, in: amsterdam)
    let opening = Week.opening(now: now, in: amsterdam)
    #expect(opening.monday == day(2026, 11, 2))
    #expect(weeks.lowerBound == opening)
    #expect(weeks.upperBound == opening.adding(weeks: 1))
  }

  @Test func aFirstSleepOnSundayAfter1800RunsFromTheWeekThatEndedToTheCurrentWeek() {
    let now = date("2026-11-08T19:00:00+01:00")
    let weeks = Week.reachable(firstSleepStart: date("2026-11-08T18:45:00+01:00"), now: now, in: amsterdam)
    #expect(weeks.lowerBound.monday == day(2026, 11, 2))
    #expect(weeks.upperBound.monday == day(2026, 11, 9))
  }

  // MARK: Week stats

  @Test func daysAreCountedSoFarOrEmpty() {
    let sleeps = [
      ended("2026-11-08T19:45:00+01:00", "2026-11-09T06:30:00+01:00", .night),
      ended("2026-11-10T13:00:00+01:00", "2026-11-10T14:00:00+01:00"),
      ended("2026-11-10T19:50:00+01:00", "2026-11-11T06:40:00+01:00", .night),
    ]
    let stats = stats(of: sleeps, week: (2026, 11, 9), now: "2026-11-11T10:00:00+01:00")
    #expect(stats.days.map(\.state) == [.counted, .counted, .soFar, .empty, .empty, .empty, .empty])
    let totals: [TimeInterval] = [38_700, 3600, 39_000, 0, 0, 0, 0]
    #expect(stats.days.map(\.total) == totals)
  }

  @Test func aSleepAcross1800IsSplitBetweenTheTwoSleepDays() {
    let stats = stats(
      of: [ended("2026-11-03T17:30:00+01:00", "2026-11-03T18:30:00+01:00")], week: (2026, 11, 2),
      now: "2026-11-11T10:00:00+01:00")
    #expect(stats.days[1].total == 30 * 60)
    #expect(stats.days[2].total == 30 * 60)
  }

  @Test func aSleepThatEndsAt1800LeavesTheNextDayEmpty() {
    let stats = stats(
      of: [ended("2026-11-03T17:00:00+01:00", "2026-11-03T18:00:00+01:00")], week: (2026, 11, 2),
      now: "2026-11-11T10:00:00+01:00")
    #expect(stats.days[1].state == .counted)
    #expect(stats.days[2].state == .empty)
  }

  @Test func aRunningSleepCountsUntilNow() {
    let running = Sleep(id: UUID(), childID: child, start: date("2026-11-10T19:50:00+01:00"), end: nil, kind: .night)
    let stats = stats(of: [running], week: (2026, 11, 9), now: "2026-11-11T01:50:00+01:00")
    #expect(stats.days[2].total == 6 * 3600)
    #expect(stats.days[2].state == .soFar)
  }

  /// Review focus 3.
  @Test func onSundayAt1900WithANightSince1845SundayIsJudgedAndNextMondayIsSoFar() {
    let now = "2026-11-08T19:00:00+01:00"
    let sleeps = [
      ended("2026-11-07T19:45:00+01:00", "2026-11-08T07:15:00+01:00", .night),
      Sleep(id: UUID(), childID: child, start: date("2026-11-08T18:45:00+01:00"), end: nil, kind: .night),
    ]
    let opening = Week.opening(now: date(now), in: amsterdam)
    let ended = stats(of: sleeps, week: (2026, 11, 2), now: now)
    #expect(opening.monday == day(2026, 11, 2))
    #expect(ended.days[6].state == .counted)
    #expect(ended.days[6].total == 11.5 * 3600)
    #expect(ended.days[6].judgement == .inRange)
    let next = stats(of: sleeps, week: (2026, 11, 9), now: now)
    #expect(Week.current(now: date(now), in: amsterdam) == opening.adding(weeks: 1))
    #expect(next.days[0].state == .soFar)
    #expect(next.days[0].total == 15 * 60)
  }

  @Test func theAverageAndInRangeUseOnlyCountedDays() {
    let sleeps = [
      ended("2026-11-01T19:00:00+01:00", "2026-11-02T07:00:00+01:00", .night),  // Mon 12 h: in range
      ended("2026-11-03T20:00:00+01:00", "2026-11-04T06:00:00+01:00", .night),  // Wed 10 h: too little
    ]
    let stats = stats(of: sleeps, week: (2026, 11, 2), now: "2026-11-11T10:00:00+01:00")
    #expect(stats.days.map(\.state) == [.counted, .empty, .counted, .empty, .empty, .empty, .empty])
    #expect(stats.average == TimeInterval(11 * 3600))
    #expect(stats.inRangeCount == 1)
    #expect(stats.averageText == "11 h 00 m")
    #expect(stats.inRangeText == "1 of 2 days")
  }

  @Test func theRangeLimitsAreInRange() {
    let sleeps = [
      ended("2026-11-01T19:00:00+01:00", "2026-11-02T06:00:00+01:00", .night),  // 11 h
      ended("2026-11-02T18:00:00+01:00", "2026-11-03T08:00:00+01:00", .night),  // 14 h
      ended("2026-11-03T19:00:00+01:00", "2026-11-04T05:59:00+01:00", .night),  // 10 h 59 m
      ended("2026-11-04T18:00:00+01:00", "2026-11-05T08:01:00+01:00", .night),  // 14 h 01 m
    ]
    let stats = stats(of: sleeps, week: (2026, 11, 2), now: "2026-11-11T10:00:00+01:00")
    #expect(stats.days.prefix(4).map(\.judgement) == [.inRange, .inRange, .tooLittle, .tooMuch])
  }

  /// Review focus 1: the child turns 1 on Thursday 5 November.
  @Test func eachDayIsJudgedWithTheRangeOnThatDay() {
    let birthDate = BirthDate(year: 2025, month: 11, day: 5)!
    let sleeps = (1...7).map { offset in
      let evening = day(2026, 11, offset)
      return Sleep(
        id: UUID(), childID: child, start: at(evening, hour: 19),
        end: at(evening, hour: 19).addingTimeInterval(11.5 * 3600),
        kind: .night)
    }
    let week = Week(containing: SleepDay(named: day(2026, 11, 2)))
    let stats = WeekStats(
      week: week, sleeps: sleeps, birthDate: birthDate, now: date("2026-11-11T10:00:00+01:00"), in: amsterdam)
    #expect(
      stats.days.map(\.range.description) == Array(repeating: "12–16 h", count: 3)
        + Array(repeating: "11–14 h", count: 4))
    #expect(
      stats.days.map(\.judgement) == Array(repeating: .tooLittle, count: 3) + Array(repeating: .inRange, count: 4))
    #expect(stats.range.description == "11–14 h")
  }

  /// Review focus 4: the clock goes back on Sunday 25 October 2026, so that sleep day is 25 hours long.
  @Test func theSleepDayWithTheChangeToWinterTimeCountsTheRealTimeAsleep() {
    let night = ended("2026-10-24T19:00:00+02:00", "2026-10-25T07:00:00+01:00", .night)
    let stats = stats(of: [night], week: (2026, 10, 19), now: "2026-11-11T10:00:00+01:00")
    #expect(SleepDay(named: day(2026, 10, 25)).interval(in: amsterdam).duration == 25 * 3600)
    #expect(stats.days[6].total == 13 * 3600)
  }

  @Test func aWeekWithSleepsButNoCountedDayHasNoAverage() {
    let stats = stats(
      of: [ended("2026-11-08T19:45:00+01:00", "2026-11-09T06:30:00+01:00", .night)], week: (2026, 11, 9),
      now: "2026-11-09T09:00:00+01:00")
    #expect(stats.hasSleep)
    #expect(stats.average == nil)
    #expect(stats.averageText == "–")
    #expect(stats.inRangeText == "–")
  }

  @Test func aWeekWithNoSleepsHasNoSleep() {
    let stats = stats(of: [], week: (2026, 11, 9), now: "2026-11-11T10:00:00+01:00")
    #expect(!stats.hasSleep)
    #expect(stats.days.allSatisfy { $0.state == .empty })
  }

  @Test(arguments: [(12.0, "1 of 1 day"), (10.0, "0 of 1 day")])
  func oneCountedDayReadsInTheSingular(hours: Double, text: String) {
    let start = date("2026-11-01T19:00:00+01:00")
    let sleep = Sleep(
      id: UUID(), childID: child, start: start, end: start.addingTimeInterval(hours * 3600), kind: .night)
    #expect(stats(of: [sleep], week: (2026, 11, 2), now: "2026-11-11T10:00:00+01:00").inRangeText == text)
  }

  @Test func theAverageRoundsToTheNearestMinuteHalfUp() {
    // 10 h 00 m 30 s and 10 h 00 m 00 s: the mean is 10 h 00 m 15 s, so 10 h 00 m.
    // 10 h 01 m 00 s and 10 h 00 m 00 s: the mean is 10 h 00 m 30 s, so 10 h 01 m.
    func average(_ seconds: Double) -> TimeInterval? {
      let first = date("2026-11-01T19:00:00+01:00")
      let second = date("2026-11-02T19:00:00+01:00")
      let sleeps = [
        Sleep(
          id: UUID(), childID: child, start: first, end: first.addingTimeInterval(10 * 3600 + seconds), kind: .night),
        Sleep(id: UUID(), childID: child, start: second, end: second.addingTimeInterval(10 * 3600), kind: .night),
      ]
      return stats(of: sleeps, week: (2026, 11, 2), now: "2026-11-11T10:00:00+01:00").average
    }
    #expect(average(30) == TimeInterval(10 * 3600))
    #expect(average(60) == TimeInterval(10 * 3600 + 60))
  }

  @Test func eachBarHasAnAccessibilityLabel() {
    let sleeps = [
      ended("2026-11-08T19:45:00+01:00", "2026-11-09T06:30:00+01:00", .night),
      ended("2026-11-10T19:50:00+01:00", "2026-11-11T06:40:00+01:00", .night),
    ]
    let stats = stats(of: sleeps, week: (2026, 11, 9), now: "2026-11-11T10:00:00+01:00")
    #expect(stats.days[0].accessibilityLabel == "Monday 9 Nov, 10 h 45 m")
    #expect(stats.days[2].accessibilityLabel == "Wednesday 11 Nov, 10 h 50 m so far")
  }

  // MARK: Helpers

  private func stats(of sleeps: [Sleep], week monday: (Int, Int, Int), now: String) -> WeekStats {
    WeekStats(
      week: Week(containing: SleepDay(named: day(monday.0, monday.1, monday.2))), sleeps: sleeps, birthDate: mila,
      now: date(now), in: amsterdam)
  }

  private func ended(_ start: String, _ end: String, _ kind: SleepKind = .nap) -> Sleep {
    Sleep(id: UUID(), childID: child, start: date(start), end: date(end), kind: kind)
  }

  private func at(_ date: BirthDate, hour: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = amsterdam
    return calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day, hour: hour))!
  }
}
