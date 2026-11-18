import Core
import Foundation
import Testing

@Suite struct UsualBedtimeTests {
  private let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!
  private let child = UUID()

  // MARK: Usual bedtime and wake-up time

  /// Review focus 2.
  @Test func bedtimesAcrossMidnightGiveABedtimeAfterMidnight() {
    let usual = UsualBedtime(
      nights: [
        night("2026-11-02T23:50:00+01:00", "2026-11-03T07:00:00+01:00"),
        night("2026-11-04T00:20:00+01:00", "2026-11-04T07:30:00+01:00"),
      ], in: amsterdam)
    #expect(usual.bedtime == TimeOfDay(hour: 0, minute: 5))
    #expect(usual.wakeUp == TimeOfDay(hour: 7, minute: 15))
  }

  @Test func anOddCountGivesTheMiddleTime() {
    let usual = UsualBedtime(
      nights: [
        night("2026-11-02T19:00:00+01:00", "2026-11-03T06:00:00+01:00"),
        night("2026-11-03T20:30:00+01:00", "2026-11-04T07:10:00+01:00"),
        night("2026-11-04T19:40:00+01:00", "2026-11-05T06:20:00+01:00"),
      ], in: amsterdam)
    #expect(usual.bedtime == TimeOfDay(hour: 19, minute: 40))
    #expect(usual.wakeUp == TimeOfDay(hour: 6, minute: 20))
  }

  @Test func noNightsGiveNoTimes() {
    let usual = UsualBedtime(nights: [], in: amsterdam)
    #expect(usual.bedtime == nil)
    #expect(usual.wakeUp == nil)
    #expect(usual.note == "bed – · up –")
  }

  @Test func aRunningNightCountsForTheBedtimeOnly() {
    let usual = UsualBedtime(
      nights: [
        night("2026-11-02T19:00:00+01:00", "2026-11-03T06:30:00+01:00"),
        Sleep(id: UUID(), childID: child, start: date("2026-11-03T20:00:00+01:00"), end: nil, kind: .night),
      ], in: amsterdam)
    #expect(usual.bedtime == TimeOfDay(hour: 19, minute: 30))
    #expect(usual.wakeUp == TimeOfDay(hour: 6, minute: 30))
  }

  @Test func bedtimesAreMeasuredFrom1200SoANightAt1745SortsAsEarly() {
    let usual = UsualBedtime(
      nights: [
        night("2026-11-02T19:00:00+01:00", "2026-11-03T06:00:00+01:00"),
        night("2026-11-03T17:45:00+01:00", "2026-11-04T06:00:00+01:00"),
      ], in: amsterdam)
    #expect(usual.bedtime == TimeOfDay(hour: 18, minute: 22, second: 30))
    #expect(usual.bedtime?.roundedToFiveMinutes == TimeOfDay(hour: 18, minute: 25))
    #expect(usual.note == "bed ~18:25 · up ~06:00")
  }

  @Test func wakeUpsAreMeasuredFrom1800() {
    let usual = UsualBedtime(
      nights: [
        night("2026-11-02T19:00:00+01:00", "2026-11-03T11:30:00+01:00"),
        night("2026-11-03T19:00:00+01:00", "2026-11-04T12:30:00+01:00"),
        night("2026-11-04T19:00:00+01:00", "2026-11-05T12:40:00+01:00"),
      ], in: amsterdam)
    #expect(usual.wakeUp == TimeOfDay(hour: 12, minute: 30))
  }

  @Test(arguments: [
    (TimeOfDay(hour: 19, minute: 47, second: 30), TimeOfDay(hour: 19, minute: 50)),
    (TimeOfDay(hour: 19, minute: 47, second: 29), TimeOfDay(hour: 19, minute: 45)),
    (TimeOfDay(hour: 23, minute: 57, second: 30), TimeOfDay(hour: 0, minute: 0)),
    (TimeOfDay(hour: 6, minute: 30), TimeOfDay(hour: 6, minute: 30)),
  ])
  func roundingIsToTheNearest5MinutesHalfUp(time: TimeOfDay, rounded: TimeOfDay) {
    #expect(time.roundedToFiveMinutes == rounded)
  }

  @Test func theNightsOfAWeekAreTheNightsThatStartInItsSleepDays() {
    let week = Week(containing: SleepDay(named: day(2026, 11, 9)))
    let before = night("2026-11-01T19:00:00+01:00", "2026-11-02T06:00:00+01:00")
    let first = night("2026-11-08T19:45:00+01:00", "2026-11-09T06:30:00+01:00")
    let nap = Sleep(
      id: UUID(), childID: child, start: date("2026-11-09T13:00:00+01:00"), end: date("2026-11-09T14:00:00+01:00"),
      kind: .nap)
    let last = night("2026-11-15T17:30:00+01:00", "2026-11-16T06:00:00+01:00")
    let after = night("2026-11-15T18:30:00+01:00", "2026-11-16T06:00:00+01:00")
    #expect(
      UsualBedtime.nights(of: [before, first, nap, last, after], in: week, timeZone: amsterdam) == [first, last])
  }

  // MARK: Start values on another sleep day

  @Test func onAnEarlierSundayAt2010TheSleepIsOnTheEveningBefore() {
    let values = SleepStartValues.on(
      SleepDay(named: day(2026, 11, 8)), now: date("2026-11-15T20:10:00+01:00"), in: amsterdam)
    #expect(values.fellAsleep == date("2026-11-07T19:10:00+01:00"))
    #expect(values.wokeUp == date("2026-11-07T20:10:00+01:00"))
    #expect(values.kind == .night)
  }

  @Test func at1830TheSleepEndsAtTheEndOfTheSleepDay() {
    let values = SleepStartValues.on(
      SleepDay(named: day(2026, 11, 8)), now: date("2026-11-15T18:30:00+01:00"), in: amsterdam)
    #expect(values.fellAsleep == date("2026-11-08T17:00:00+01:00"))
    #expect(values.wokeUp == date("2026-11-08T18:00:00+01:00"))
    #expect(values.kind == .nap)
  }

  @Test func inTheMorningTheSleepIsOnTheNamedDateRoundedDownTo5Minutes() {
    let values = SleepStartValues.on(
      SleepDay(named: day(2026, 11, 1)), now: date("2026-11-11T10:03:00+01:00"), in: amsterdam)
    #expect(values.fellAsleep == date("2026-11-01T09:00:00+01:00"))
    #expect(values.wokeUp == date("2026-11-01T10:00:00+01:00"))
    #expect(values.kind == .nap)
  }

  @Test func at1900TheSleepIsOnTheEveningBefore() {
    let values = SleepStartValues.on(
      SleepDay(named: day(2026, 11, 8)), now: date("2026-11-15T19:00:00+01:00"), in: amsterdam)
    #expect(values.fellAsleep == date("2026-11-07T18:00:00+01:00"))
    #expect(values.wokeUp == date("2026-11-07T19:00:00+01:00"))
  }

  // MARK: Helpers

  private func night(_ start: String, _ end: String) -> Sleep {
    Sleep(id: UUID(), childID: child, start: date(start), end: date(end), kind: .night)
  }
}
