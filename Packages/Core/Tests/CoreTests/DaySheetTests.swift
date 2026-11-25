import Core
import Foundation
import Testing

@Suite struct DaySheetTests {
  private let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!
  private let child = UUID()
  /// Mila's birthdate: 1 year old in November 2026, so 11–14 h.
  private let mila = BirthDate(year: 2025, month: 3, day: 12)!
  /// Sunday 8 November 2026, 19:30: the week of Mon 2 – Sun 8 Nov has ended.
  private let sundayEvening = "2026-11-08T19:30:00+01:00"

  // MARK: Timeline segments

  @Test func aSleepInsideOneDayIsOneSegmentAtItsClockTime() {
    let night = ended("2026-11-02T20:54:00+01:00", "2026-11-03T06:12:00+01:00", .night)
    let nap = ended("2026-11-03T13:30:00+01:00", "2026-11-03T14:24:00+01:00")
    let segments = Timeline.segments(on: tuesday, sleeps: [nap, night], now: date(sundayEvening), in: amsterdam)
    #expect(segments.count == 2)
    #expect(segments[0].kind == .night)
    #expect(isClose(segments[0].from, 2.9))
    #expect(isClose(segments[0].length, 9.3))
    #expect(segments[1].kind == .nap)
    #expect(isClose(segments[1].from, 19.5))
    #expect(isClose(segments[1].length, 0.9))
  }

  /// Criterion 8.
  @Test func aSleepAcross1800IsCutIntoAPartOnEachDay() {
    let nap = ended("2026-11-03T17:30:00+01:00", "2026-11-03T18:30:00+01:00")
    let now = date(sundayEvening)
    let onTuesday = Timeline.segments(on: tuesday, sleeps: [nap], now: now, in: amsterdam)
    let onWednesday = Timeline.segments(on: wednesday, sleeps: [nap], now: now, in: amsterdam)
    #expect(onTuesday.count == 1)
    #expect(isClose(onTuesday[0].from, 23.5))
    #expect(isClose(onTuesday[0].length, 0.5))
    #expect(onWednesday.count == 1)
    #expect(isClose(onWednesday[0].from, 0))
    #expect(isClose(onWednesday[0].length, 0.5))
  }

  @Test func aRunningSleepRunsUntilNow() {
    let running = Sleep(
      id: UUID(), childID: child, start: date("2026-06-21T19:42:00+02:00"), end: nil, kind: .night)
    let segments = Timeline.segments(
      on: SleepDay(named: day(2026, 6, 22)), sleeps: [running], now: date("2026-06-21T21:56:00+02:00"), in: amsterdam)
    #expect(segments.count == 1)
    #expect(isClose(segments[0].from, 1.7))
    #expect(isClose(segments[0].length, 2 + 14 / 60))
  }

  @Test func onTheDayTheClockGoesBackTheSegmentSitsAtItsClockTimesAndTheTotalKeepsTheRealDuration() {
    // The clock goes back at 03:00 on Sunday 25 October 2026: 20:00 to 07:00 is 12 real hours.
    let night = ended("2026-10-24T20:00:00+02:00", "2026-10-25T07:00:00+01:00", .night)
    let sunday = SleepDay(named: day(2026, 10, 25))
    let now = date("2026-10-26T10:00:00+01:00")
    let segments = Timeline.segments(on: sunday, sleeps: [night], now: now, in: amsterdam)
    #expect(isClose(segments[0].from, 2))
    #expect(isClose(segments[0].length, 11))
    let sheet = DaySheet(sleepDay: sunday, sleeps: [night], birthDate: mila, now: now, in: amsterdam)
    #expect(sheet.summary == "12 h 00 m slept in total")
    #expect(sheet.items[0].duration == "12 h 00 m")
  }

  @Test func aPastWeekHasSevenRows() {
    let week = Week(containing: tuesday)
    let rows = Timeline.rows(of: week, sleeps: [], now: date(sundayEvening), in: amsterdam)
    #expect(rows.map(\.sleepDay) == week.days)
    #expect(rows[0].accessibilityLabel == "Monday 2 Nov details")
    #expect(rows[0].dayName == "Mon")
    #expect(rows[0].segments.isEmpty)
  }

  @Test func theCurrentWeekHasRowsUpToTheCurrentSleepDay() {
    let now = date("2026-11-11T10:00:00+01:00")
    let rows = Timeline.rows(of: Week.current(now: now, in: amsterdam), sleeps: [], now: now, in: amsterdam)
    #expect(rows.map(\.sleepDay.name) == [day(2026, 11, 9), day(2026, 11, 10), day(2026, 11, 11)])
  }

  // MARK: The sleeps of a sleep day

  @Test func theSheetOfACountedDayListsItsSleepsOldestFirstWithTheTotalAndTheVerdict() {
    let night = ended("2026-11-02T20:54:00+01:00", "2026-11-03T06:12:00+01:00", .night)
    let nap = ended("2026-11-03T13:30:00+01:00", "2026-11-03T14:24:00+01:00")
    let other = ended("2026-11-04T13:00:00+01:00", "2026-11-04T14:00:00+01:00")
    let sheet = DaySheet(
      sleepDay: tuesday, sleeps: [other, nap, night], birthDate: mila, now: date(sundayEvening), in: amsterdam)
    #expect(sheet.title == "Tuesday 3 Nov")
    #expect(sheet.summary == "10 h 12 m slept in total")
    #expect(sheet.pill == .judgement(.tooLittle))
    #expect(sheet.hasEnded)
    #expect(sheet.items.map(\.sleep) == [night, nap])
    #expect(sheet.items.map(\.kindName) == ["Night", "Nap"])
    #expect(sheet.items.map(\.times) == ["20:54 → 06:12", "13:30 → 14:24"])
    #expect(sheet.items.map(\.duration) == ["9 h 18 m", "54 m"])
    #expect(sheet.items.map(\.editLabel) == ["Edit night", "Edit nap"])
  }

  /// Criterion 1: Theo's Wednesday 25 Nov.
  @Test func aNapFrom1600To1830CountsWholeSoTheSheetAddsUpTo11h26m() {
    let night = ended("2026-11-24T22:44:00+01:00", "2026-11-25T07:40:00+01:00", .night)
    let nap = ended("2026-11-25T16:00:00+01:00", "2026-11-25T18:30:00+01:00")
    let wednesday25 = SleepDay(named: day(2026, 11, 25))
    let sheet = DaySheet(
      sleepDay: wednesday25, sleeps: [nap, night], birthDate: mila, now: date("2026-11-25T21:00:00+01:00"),
      in: amsterdam)
    #expect(sheet.items.map(\.duration) == ["8 h 56 m", "2 h 30 m"])
    #expect(sheet.summary == "11 h 26 m slept in total")
    #expect(sheet.total == 11 * 3600 + 26 * 60)
    #expect(sheet.pill == .judgement(.inRange))
  }

  /// Review focus 1, criteria 2 and 3.
  @Test func aNapFrom1730To1830ShowsWholeOnlyOnTheSheetOfTheDayItStartsIn() {
    let nap = ended("2026-11-03T17:30:00+01:00", "2026-11-03T18:30:00+01:00")
    let now = date(sundayEvening)
    let earlier = DaySheet(sleepDay: tuesday, sleeps: [nap], birthDate: mila, now: now, in: amsterdam)
    #expect(earlier.items.map(\.times) == ["17:30 → 18:30"])
    #expect(earlier.items.map(\.duration) == ["1 h 00 m"])
    #expect(earlier.summary == "1 h 00 m slept in total")
    let later = DaySheet(sleepDay: wednesday, sleeps: [nap], birthDate: mila, now: now, in: amsterdam)
    #expect(later.items.isEmpty)
    #expect(later.summary == "No sleeps logged")
    #expect(later.pill == nil)
  }

  /// Criterion 3: a night that starts before 18:00 shows only on the earlier sheet.
  @Test func aNightFrom1745ShowsOnlyOnTheSheetOfTheDayItStartsIn() {
    let night = ended("2026-11-03T17:45:00+01:00", "2026-11-04T06:15:00+01:00", .night)
    let nap = ended("2026-11-04T13:00:00+01:00", "2026-11-04T14:00:00+01:00")
    let now = date(sundayEvening)
    #expect(tuesday.sleeps(startingIn: [nap, night], in: amsterdam) == [night])
    #expect(wednesday.sleeps(startingIn: [nap, night], in: amsterdam) == [nap])
    let later = DaySheet(sleepDay: wednesday, sleeps: [nap, night], birthDate: mila, now: now, in: amsterdam)
    #expect(later.items.map(\.sleep) == [nap])
    #expect(later.summary == "1 h 00 m slept in total")
  }

  /// Review focus 4.
  @Test func aSleepThatEndsAtExactly1800ShowsOnlyOnTheEarlierDay() {
    let nap = ended("2026-11-03T17:00:00+01:00", "2026-11-03T18:00:00+01:00")
    let now = date(sundayEvening)
    #expect(tuesday.sleeps(startingIn: [nap], in: amsterdam) == [nap])
    #expect(wednesday.sleeps(startingIn: [nap], in: amsterdam).isEmpty)
    let later = DaySheet(sleepDay: wednesday, sleeps: [nap], birthDate: mila, now: now, in: amsterdam)
    #expect(later.summary == "No sleeps logged")
    #expect(later.pill == nil)
  }

  /// Review focus 4.
  @Test func aSleepThatStartsAtExactly1800ShowsOnlyOnTheLaterDay() {
    let night = ended("2026-11-03T18:00:00+01:00", "2026-11-04T06:00:00+01:00", .night)
    let week = stats(of: [night], now: date(sundayEvening))
    #expect(tuesday.sleeps(startingIn: [night], in: amsterdam).isEmpty)
    #expect(wednesday.sleeps(startingIn: [night], in: amsterdam) == [night])
    #expect(week.days[1].state == .empty)
    #expect(week.days[2].total == 12 * 3600)
  }

  @Test func aPastDayWithNoSleepsHasNoPill() {
    let sheet = DaySheet(
      sleepDay: SleepDay(named: day(2026, 11, 2)), sleeps: [], birthDate: mila, now: date(sundayEvening), in: amsterdam)
    #expect(sheet.title == "Monday 2 Nov")
    #expect(sheet.summary == "No sleeps logged")
    #expect(sheet.items.isEmpty)
    #expect(sheet.pill == nil)
    #expect(sheet.hasEnded)
  }

  @Test func theCurrentDayWithNoSleepsHasNotEndedSoItKeepsTheSoFarPill() {
    let now = date("2026-11-11T10:00:00+01:00")
    let today = SleepDay(containing: now, in: amsterdam)
    #expect(!today.hasEnded(now: now, in: amsterdam))
    let sheet = DaySheet(sleepDay: today, sleeps: [], birthDate: mila, now: now, in: amsterdam)
    #expect(sheet.summary == "No sleeps logged")
    #expect(sheet.pill == .soFar)
    #expect(!sheet.hasEnded)
  }

  @Test func theCurrentDayCountsSoFar() {
    let night = ended("2026-11-10T19:50:00+01:00", "2026-11-11T06:40:00+01:00", .night)
    let now = date("2026-11-11T10:00:00+01:00")
    let sheet = DaySheet(
      sleepDay: SleepDay(named: day(2026, 11, 11)), sleeps: [night], birthDate: mila, now: now, in: amsterdam)
    #expect(sheet.title == "Wednesday 11 Nov")
    #expect(sheet.summary == "10 h 50 m slept so far")
    #expect(sheet.pill == .soFar)
  }

  /// Review focus 4.
  @Test func aRunningSleepReadsArrowNowWithItsDurationSoFar() {
    let running = Sleep(
      id: UUID(), childID: child, start: date("2026-06-21T19:42:00+02:00"), end: nil, kind: .night)
    let sheet = DaySheet(
      sleepDay: SleepDay(named: day(2026, 6, 22)), sleeps: [running], birthDate: mila,
      now: date("2026-06-21T21:56:00+02:00"), in: amsterdam)
    #expect(sheet.title == "Monday 22 Jun")
    #expect(sheet.items.map(\.times) == ["19:42 → now"])
    #expect(sheet.items.map(\.duration) == ["2 h 14 m"])
    #expect(sheet.summary == "2 h 14 m slept so far")
    #expect(sheet.pill == .soFar)
  }

  /// Review focus 2, criterion 5: a nap from 17:30 that still runs at 18:20.
  @Test func aRunningSleepFromBefore1800KeepsItsDaySoFarAfter1800AndLeavesTheNewDayEmpty() {
    let night = ended("2026-11-10T19:50:00+01:00", "2026-11-11T06:40:00+01:00", .night)
    let running = Sleep(id: UUID(), childID: child, start: date("2026-11-11T17:30:00+01:00"), end: nil, kind: .nap)
    let now = date("2026-11-11T18:20:00+01:00")
    let wednesday11 = SleepDay(named: day(2026, 11, 11))
    #expect(wednesday11.hasEnded(now: now, in: amsterdam))

    let sheet = DaySheet(sleepDay: wednesday11, sleeps: [night, running], birthDate: mila, now: now, in: amsterdam)
    #expect(sheet.total == TimeInterval(11 * 3600 + 40 * 60))
    #expect(sheet.summary == "11 h 40 m slept so far")
    #expect(sheet.pill == .soFar)
    #expect(!sheet.hasEnded)

    let week = WeekStats(
      week: Week.current(now: now, in: amsterdam), sleeps: [night, running], birthDate: mila, now: now, in: amsterdam)
    #expect(week.days[2].state == .soFar)
    #expect(week.days[2].judgement == nil)
    #expect(week.days[2].total == 11 * 3600 + 40 * 60)
    #expect(week.countedDays.isEmpty)
    #expect(week.inRangeText == "–")
    #expect(week.days[3].state == .empty)
    #expect(week.days[3].total == 0)
    let thursday = DaySheet(
      sleepDay: SleepDay(named: day(2026, 11, 12)), sleeps: [night, running], birthDate: mila, now: now, in: amsterdam)
    #expect(thursday.items.isEmpty)

    // Once the nap ends at 18:30, Wednesday is counted with the full 1 h of the nap.
    var ended = running
    ended.end = date("2026-11-11T18:30:00+01:00")
    let after = WeekStats(
      week: Week.current(now: now, in: amsterdam), sleeps: [night, ended], birthDate: mila, now: now, in: amsterdam)
    #expect(after.days[2].state == .counted)
    #expect(after.days[2].total == 11 * 3600 + 50 * 60)
    #expect(after.days[2].judgement == .inRange)
  }

  /// Review focus 5.
  @Test func aNapMovedToAnotherDayLeavesTheFirstDayAndShowsInTheOther() {
    let night = ended("2026-11-02T20:54:00+01:00", "2026-11-03T06:12:00+01:00", .night)
    let wednesdayNight = ended("2026-11-03T19:30:00+01:00", "2026-11-04T06:30:00+01:00", .night)
    var nap = ended("2026-11-03T13:30:00+01:00", "2026-11-03T14:24:00+01:00")
    let now = date(sundayEvening)
    let before = [night, nap, wednesdayNight]
    nap.start = date("2026-11-04T13:30:00+01:00")
    nap.end = date("2026-11-04T14:24:00+01:00")
    let after = [night, nap, wednesdayNight]

    #expect(tuesday.sleeps(startingIn: after, in: amsterdam).map(\.id) == [night.id])
    #expect(wednesday.sleeps(startingIn: after, in: amsterdam).map(\.id) == [wednesdayNight.id, nap.id])

    let statsBefore = stats(of: before, now: now)
    let statsAfter = stats(of: after, now: now)
    #expect(SleepDuration.text(statsBefore.days[1].total) == "10 h 12 m")
    #expect(SleepDuration.text(statsAfter.days[1].total) == "9 h 18 m")
    #expect(statsAfter.days[2].total - statsBefore.days[2].total == 54 * 60)
  }

  // MARK: The starts-in rule in WeekStats

  /// Criterion 4: Wednesday holds only the tail of Tuesday's nap.
  @Test func aPastDayWithOnlyTheTailOfASleepFromTheDayBeforeIsEmpty() {
    let nap = ended("2026-11-03T17:30:00+01:00", "2026-11-03T18:30:00+01:00")
    let week = stats(of: [nap], now: date(sundayEvening))
    #expect(week.days[1].state == .counted)
    #expect(week.days[1].total == 3600)
    #expect(week.days[2].state == .empty)
    #expect(week.days[2].total == 0)
    #expect(week.countedDays.count == 1)
    #expect(week.averageText == "1 h 00 m")
  }

  /// Review focus 3: the nap starts before the clock change at 18:00 and counts its real hour.
  @Test func onTheDayTheClockGoesBackANapAcross1800CountsItsRealDurationOnItsDay() {
    let nap = ended("2026-10-25T17:30:00+01:00", "2026-10-25T18:30:00+01:00")
    let night = ended("2026-10-24T20:00:00+02:00", "2026-10-25T07:00:00+01:00", .night)
    let sunday = SleepDay(named: day(2026, 10, 25))
    let sheet = DaySheet(
      sleepDay: sunday, sleeps: [night, nap], birthDate: mila, now: date("2026-10-26T10:00:00+01:00"), in: amsterdam)
    #expect(sheet.summary == "13 h 00 m slept in total")
  }

  @Test func aPastDayWhoseOnlySleepEndsAtExactly1800IsEmptyAndNotCounted() {
    let nap = ended("2026-11-03T17:00:00+01:00", "2026-11-03T18:00:00+01:00")
    let week = stats(of: [nap], now: date(sundayEvening))
    #expect(week.days[1].state == .counted)
    #expect(week.days[2].state == .empty)
    #expect(week.countedDays.count == 1)
    #expect(week.inRangeText == "0 of 1 day")
    #expect(week.averageText == "1 h 00 m")
  }

  /// Criterion 10.
  @Test func theCurrentDayAfterThe1830AddIsEmptyWithNoSoFarBar() {
    let now = date("2026-11-11T18:30:00+01:00")
    let values = DaySheet.startValues(on: SleepDay(containing: now, in: amsterdam), now: now, in: amsterdam)
    let added = Sleep(id: UUID(), childID: child, start: values.fellAsleep, end: values.wokeUp, kind: values.kind)
    let week = WeekStats(
      week: Week.current(now: now, in: amsterdam), sleeps: [added], birthDate: mila, now: now, in: amsterdam)
    // Thursday 12 Nov is the current sleep day; the new sleep starts in Wednesday 11 Nov and counts whole there.
    #expect(week.days[3].state == .empty)
    #expect(week.days[2].state == .counted)
    #expect(week.days[2].total == 3600)
    #expect(!week.days.contains { $0.state == .soFar })
    let sheet = DaySheet(
      sleepDay: SleepDay(containing: now, in: amsterdam), sleeps: [added], birthDate: mila, now: now, in: amsterdam)
    #expect(sheet.items.isEmpty)
  }

  // MARK: Start values of "Add a sleep to this day"

  @Test func onTheCurrentDayTheStartValuesComeFromNow() {
    let now = date("2026-11-11T10:07:00+01:00")
    let values = DaySheet.startValues(on: SleepDay(containing: now, in: amsterdam), now: now, in: amsterdam)
    #expect(values == SleepStartValues.today(now: now, in: amsterdam))
    #expect(values.fellAsleep == date("2026-11-11T09:05:00+01:00"))
    #expect(values.wokeUp == date("2026-11-11T10:05:00+01:00"))
    #expect(values.kind == .nap)
  }

  /// Criterion 10.
  @Test func onTheCurrentDayAt1830TheStartValuesStartInThePreviousSleepDay() {
    let now = date("2026-11-11T18:30:00+01:00")
    let today = SleepDay(containing: now, in: amsterdam)
    #expect(today.name == day(2026, 11, 12))
    let values = DaySheet.startValues(on: today, now: now, in: amsterdam)
    #expect(values.fellAsleep == date("2026-11-11T17:30:00+01:00"))
    #expect(values.wokeUp == date("2026-11-11T18:30:00+01:00"))
    let previous = SleepDay(named: day(2026, 11, 11))
    #expect(previous.sleeps(startingIn: [sleep(values)], in: amsterdam).count == 1)
    #expect(today.sleeps(startingIn: [sleep(values)], in: amsterdam).isEmpty)
  }

  @Test(arguments: [
    ("10:00", "2026-11-03T09:00:00+01:00", "2026-11-03T10:00:00+01:00", SleepKind.nap),
    ("18:00", "2026-11-03T17:00:00+01:00", "2026-11-03T18:00:00+01:00", SleepKind.nap),
    ("18:04", "2026-11-03T17:00:00+01:00", "2026-11-03T18:00:00+01:00", SleepKind.nap),
    // Review focus 3: the evening that opens the sleep day, not the day after it.
    ("20:10", "2026-11-02T19:10:00+01:00", "2026-11-02T20:10:00+01:00", SleepKind.night),
  ])
  func onAPastDayTheWholeSleepLiesInsideThatDay(clock: String, fellAsleep: String, wokeUp: String, kind: SleepKind) {
    let now = date("2026-11-08T\(clock):00+01:00")
    let values = DaySheet.startValues(on: tuesday, now: now, in: amsterdam)
    #expect(values == SleepStartValues.on(tuesday, now: now, in: amsterdam))
    #expect(values.fellAsleep == date(fellAsleep))
    #expect(values.wokeUp == date(wokeUp))
    #expect(values.kind == kind)
    #expect(tuesday.sleeps(startingIn: [sleep(values)], in: amsterdam).count == 1)
  }

  // MARK: Helpers

  private var tuesday: SleepDay { SleepDay(named: day(2026, 11, 3)) }
  private var wednesday: SleepDay { SleepDay(named: day(2026, 11, 4)) }

  private func stats(of sleeps: [Sleep], now: Date) -> WeekStats {
    WeekStats(week: Week(containing: tuesday), sleeps: sleeps, birthDate: mila, now: now, in: amsterdam)
  }

  private func ended(_ start: String, _ end: String, _ kind: SleepKind = .nap) -> Sleep {
    Sleep(id: UUID(), childID: child, start: date(start), end: date(end), kind: kind)
  }

  private func sleep(_ values: SleepStartValues) -> Sleep {
    Sleep(id: UUID(), childID: child, start: values.fellAsleep, end: values.wokeUp, kind: values.kind)
  }

  private func isClose(_ value: Double, _ expected: Double) -> Bool {
    abs(value - expected) < 0.001
  }
}
