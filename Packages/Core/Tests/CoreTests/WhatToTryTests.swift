import Core
import Foundation
import Testing

@Suite struct WhatToTryTests {
  private let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!
  private let child = UUID()
  /// Mila's birthdate: 1 year old in November 2026, so 11–14 h.
  private let mila = BirthDate(year: 2025, month: 3, day: 12)!
  /// The week Mon 2 – Sun 8 Nov 2026.
  private let week = Week(containing: SleepDay(named: BirthDate(year: 2026, month: 11, day: 2)!))
  /// Sunday evening, after the week has ended.
  private let sundayEvening = date("2026-11-08T19:30:00+01:00")
  private static let window = BedtimeWindow(
    start: TimeOfDay(hour: 19, minute: 10), end: TimeOfDay(hour: 19, minute: 40))

  // MARK: The seeds

  @Test func theWeekSeedGivesTheBedtimeTipAndTheWindowOfTheGallery() throws {
    let card = try #require(whatToTry(sleeps: seedSleeps(.week), now: sundayEvening))
    guard case .tip(.bedtimesVary(let distance)) = card.content else {
      Issue.record("Expected the bedtime tip, got \(card.content)")
      return
    }
    #expect(abs(distance - 42.24 * 60) < 1)
    #expect(card.window == Self.window)
    #expect(
      card.message(name: "Mila")
        == WhatToTry.Message(
          text: "Mila's bedtime moved around by about 40 minutes this week.",
          bold: "Try a fixed bedtime between 19:10 and 19:40."))
    #expect(
      card.generalTips == [
        "Start a calm wind-down 30 minutes before bed.",
        "Keep the same wake-up time, also at the weekend.",
        "End the last nap at least 3 hours before bedtime.",
      ])
  }

  @Test func theWeekTodaySeedOnWednesdayAsksToKeepLoggingWith2DaysSoFar() throws {
    let now = date("2026-11-11T10:00:00+01:00")
    let card = try #require(
      WhatToTry(
        week: Week.current(now: now, in: amsterdam), sleeps: seedSleeps(.weekToday), birthDate: mila, now: now,
        in: amsterdam))
    #expect(card.content == .keepLogging(countedDays: 2))
    #expect(card.window == nil)
    #expect(
      card.message(name: "Mila")
        == WhatToTry.Message(
          text: "Keep logging. With sleeps on 4 days of the week, Nap Time shows what to try for Mila.",
          bold: "2 of 4 days so far."))
  }

  /// Review focus 5 in Core: a fourth counted day turns the card into a tip, and its delete turns it back.
  @Test func aFourthCountedDayShowsATipAndItsDeleteAsksToKeepLoggingAgain() throws {
    let now = date("2026-11-12T19:30:00+01:00")
    let current = Week.current(now: now, in: amsterdam)
    let threeDays = try #require(
      WhatToTry(week: current, sleeps: seedSleeps(.weekToday), birthDate: mila, now: now, in: amsterdam))
    #expect(threeDays.content == .keepLogging(countedDays: 3))
    #expect(threeDays.message(name: "Mila").bold == "3 of 4 days so far.")

    let added = sleep("2026-11-11T18:30:00+01:00", "2026-11-11T19:30:00+01:00", .night)
    let fourDays = try #require(
      WhatToTry(week: current, sleeps: seedSleeps(.weekToday) + [added], birthDate: mila, now: now, in: amsterdam))
    guard case .tip = fourDays.content else {
      Issue.record("Expected a tip, got \(fourDays.content)")
      return
    }
  }

  @Test func anEarlierWeekCountsTheDaysLogged() throws {
    let now = date("2026-06-21T19:30:00+02:00")
    let week = Week.opening(now: now, in: amsterdam)
    #expect(week.title == "Mon 15 – Sun 21 Jun")
    let card = try #require(
      WhatToTry(week: week, sleeps: seedSleeps(.family), birthDate: mila, now: now, in: amsterdam))
    #expect(card.content == .keepLogging(countedDays: 1))
    #expect(card.message(name: "Mila").bold == "1 of 4 days logged.")
  }

  // MARK: Which card

  @Test func aWeekWithNoSleepsHasNoCard() {
    #expect(whatToTry(sleeps: [], now: sundayEvening) == nil)
  }

  @Test func threeCountedDaysAskToKeepLoggingAndFourGiveATip() throws {
    let three = try #require(whatToTry(sleeps: days(6...8), now: sundayEvening))
    #expect(three.content == .keepLogging(countedDays: 3))
    let four = try #require(whatToTry(sleeps: days(5...8), now: sundayEvening))
    #expect(four.content == .tip(.praise(inRange: 4, counted: 4)))
  }

  /// A day that has not ended yet is not counted.
  @Test func aDaySoFarIsNotCounted() throws {
    let card = try #require(whatToTry(sleeps: days(2...5), now: date("2026-11-05T10:00:00+01:00")))
    #expect(card.content == .keepLogging(countedDays: 3))
  }

  // MARK: Bedtimes vary

  @Test func bedtimesThatMoveExactly30MinutesGiveNoBedtimeTip() throws {
    let sleeps = days(5...8, bedtimes: ["19:00", "20:00", "19:00", "20:00"])
    #expect(whatToTry(sleeps: sleeps, now: sundayEvening)?.content == .tip(.praise(inRange: 4, counted: 4)))
  }

  @Test func bedtimesThatMoveJustOver30MinutesGiveTheBedtimeTip() throws {
    let sleeps = days(5...8, bedtimes: ["19:00", "20:01", "19:00", "20:01"])
    #expect(whatToTry(sleeps: sleeps, now: sundayEvening)?.content == .tip(.bedtimesVary(distance: 30.5 * 60)))
  }

  /// Review focus 1.
  @Test func bedtimesAcrossMidnightMoveAbout15Minutes() throws {
    let nights = [
      sleep("2026-11-02T23:40:00+01:00", "2026-11-03T07:00:00+01:00", .night),
      sleep("2026-11-03T23:50:00+01:00", "2026-11-04T07:00:00+01:00", .night),
      sleep("2026-11-05T00:20:00+01:00", "2026-11-05T07:00:00+01:00", .night),
    ]
    let spread = try #require(UsualBedtime.spread(of: nights, in: amsterdam))
    #expect(abs(spread - (15 * 60 + 33.3)) < 1)
  }

  @Test func oneNightHasNoSpread() {
    let night = sleep("2026-11-02T19:40:00+01:00", "2026-11-03T07:00:00+01:00", .night)
    #expect(UsualBedtime.spread(of: [night], in: amsterdam) == nil)
  }

  // MARK: The order of the tips

  @Test func bedtimesVaryComesBeforeTooLittle() throws {
    // 20:30 to 06:30 and 22:00 to 06:30, with a 1 h nap: 11 h and 9 h 30 m, so below 11 h on average.
    let sleeps = days(5...8, bedtimes: ["20:30", "22:00", "20:30", "22:00"], nap: ("13:00", "14:00"))
    guard case .tip(.bedtimesVary) = try #require(whatToTry(sleeps: sleeps, now: sundayEvening)).content else {
      Issue.record("Expected the bedtime tip")
      return
    }
  }

  @Test func tooLittleComesBeforeTheLateNap() throws {
    // 21:30 to 06:30 with a nap from 16:00 to 17:00: 10 h, and the late nap would also apply.
    let sleeps = days(5...8, bedtimes: Array(repeating: "21:30", count: 4), nap: ("16:00", "17:00"))
    #expect(whatToTry(sleeps: sleeps, now: sundayEvening)?.content == .tip(.tooLittle(average: 10 * 3600)))
  }

  @Test func tooMuchComesBeforeTheLateNap() throws {
    let sleeps = days(5...8, bedtimes: Array(repeating: "18:00", count: 4), nap: ("13:00", "17:00"))
    #expect(whatToTry(sleeps: sleeps, now: sundayEvening)?.content == .tip(.tooMuch(average: 16.5 * 3600)))
  }

  @Test func theLateNapComesBeforePraise() throws {
    let sleeps = days(5...8, nap: ("16:00", "17:30"))
    #expect(whatToTry(sleeps: sleeps, now: sundayEvening)?.content == .tip(.lateNap(days: 4)))
  }

  // MARK: The late nap

  @Test func aLateNapOnOneDayGivesPraise() throws {
    let sleeps = days(5...7) + days(8...8, nap: ("16:00", "17:30"))
    #expect(whatToTry(sleeps: sleeps, now: sundayEvening)?.content == .tip(.praise(inRange: 4, counted: 4)))
  }

  @Test func aLateNapOnTwoDaysGivesTheLateNapTip() throws {
    let sleeps = days(5...6) + days(7...8, nap: ("16:00", "17:30"))
    #expect(whatToTry(sleeps: sleeps, now: sundayEvening)?.content == .tip(.lateNap(days: 2)))
  }

  @Test func aChildUnder1GetsNoLateNapTipAndTheBabyTip() throws {
    let baby = BirthDate(year: 2026, month: 1, day: 10)!
    // 12–16 h: 19:30 to 06:30 with a 1 h 30 m nap is 12 h 30 m.
    let sleeps = days(5...6) + days(7...8, nap: ("16:00", "17:30"))
    let card = try #require(
      WhatToTry(week: week, sleeps: sleeps, birthDate: baby, now: sundayEvening, in: amsterdam))
    #expect(card.content == .tip(.praise(inRange: 4, counted: 4)))
    #expect(card.generalTips[2] == "Follow the same steps every night, like a bath, a feed, and a song.")
  }

  /// Review focus 2.
  @Test func aChildWhoTurns1OnThursdayGetsTheRangeFrom1AndTheLateNapTip() throws {
    let birthday = BirthDate(year: 2025, month: 11, day: 5)!
    // 19:30 to 06:30 with a nap from 16:00 to 17:00: 12 h, in 11–14 h but not in 12–16 h on Monday.
    let sleeps = days(2...8, nap: ("16:00", "17:00"))
    let card = try #require(
      WhatToTry(week: week, sleeps: sleeps, birthDate: birthday, now: sundayEvening, in: amsterdam))
    #expect(card.range == RecommendedRange(birthDate: birthday, on: week.sunday.name))
    #expect(card.range.description == "11–14 h")
    #expect(card.isUnderOne == false)
    #expect(card.content == .tip(.lateNap(days: 7)))
    #expect(card.generalTips[2] == "End the last nap at least 3 hours before bedtime.")
  }

  /// A usual bedtime of 19:47:30 counts as 19:50, so a nap that ends at 16:50 is not late.
  @Test func aNapThatEnds3HoursBeforeTheRoundedBedtimeIsNotLate() throws {
    let sleeps = days(5...8, bedtimes: ["19:45", "19:50", "19:45", "19:50"], nap: ("15:20", "16:50"))
    #expect(whatToTry(sleeps: sleeps, now: sundayEvening)?.content == .tip(.praise(inRange: 4, counted: 4)))
  }

  @Test func aNapThatEndsAMinuteLaterIsLate() throws {
    let sleeps = days(5...8, bedtimes: ["19:45", "19:50", "19:45", "19:50"], nap: ("15:21", "16:51"))
    #expect(whatToTry(sleeps: sleeps, now: sundayEvening)?.content == .tip(.lateNap(days: 4)))
  }

  /// A day's last nap is the latest that starts inside it, with its real end, also after 18:00.
  @Test func theLastNapAcross1800CountsForTheDayItStartsIn() throws {
    let nights = (2...5).map { night(on: $0, bedtime: "19:45") }
    let naps = [
      sleep("2026-11-02T13:00:00+01:00", "2026-11-02T14:00:00+01:00", .nap),
      sleep("2026-11-03T16:30:00+01:00", "2026-11-03T18:15:00+01:00", .nap),
      sleep("2026-11-04T13:00:00+01:00", "2026-11-04T14:00:00+01:00", .nap),
      sleep("2026-11-05T16:00:00+01:00", "2026-11-05T17:00:00+01:00", .nap),
    ]
    // Tuesday and Thursday are late. Wednesday is not: Tuesday's nap is not a nap of Wednesday.
    #expect(whatToTry(sleeps: nights + naps, now: sundayEvening)?.content == .tip(.lateNap(days: 2)))
  }

  /// Review focus 3.
  @Test func onlyNapsGiveTheBelowRangeTipWithNoBoldPart() throws {
    let two = BirthDate(year: 2024, month: 6, day: 1)!
    let naps = (5...8).flatMap { day in
      [
        sleep("2026-11-0\(day)T09:00:00+01:00", "2026-11-0\(day)T10:00:00+01:00", .nap),
        sleep("2026-11-0\(day)T13:00:00+01:00", "2026-11-0\(day)T14:00:00+01:00", .nap),
      ]
    }
    let card = try #require(
      WhatToTry(week: week, sleeps: naps, birthDate: two, now: sundayEvening, in: amsterdam))
    #expect(card.content == .tip(.tooLittle(average: 2 * 3600)))
    #expect(card.window == nil)
    #expect(
      card.message(name: "Mila")
        == WhatToTry.Message(text: "Mila slept 2 h 00 m a day on average, below the 11–14 h range.", bold: nil))
  }

  // MARK: The bedtime window

  @Test func theWindowStartsFromTheRoundedWakeUpTime() throws {
    let range = RecommendedRange(birthDate: mila, on: week.sunday.name)
    let window = try #require(
      BedtimeWindow(wakeUp: TimeOfDay(hour: 6, minute: 27, second: 30), range: range, averageNap: 93 * 60))
    #expect(window == BedtimeWindow(start: TimeOfDay(hour: 19, minute: 20), end: TimeOfDay(hour: 19, minute: 50)))
  }

  @Test func noWakeUpTimeGivesNoWindow() {
    let range = RecommendedRange(birthDate: mila, on: week.sunday.name)
    #expect(BedtimeWindow(wakeUp: nil, range: range, averageNap: 0) == nil)
  }

  /// Review focus 4.
  @Test func aNapAcross1800AddsOnlyItsPartInsideTheDay() throws {
    let nap = sleep("2026-11-03T17:00:00+01:00", "2026-11-03T18:30:00+01:00", .nap)
    let tuesday = SleepDay(named: BirthDate(year: 2026, month: 11, day: 3)!)
    let wednesday = SleepDay(named: BirthDate(year: 2026, month: 11, day: 4)!)
    #expect(BedtimeWindow.averageNap(of: [nap], on: [tuesday], now: sundayEvening, in: amsterdam) == 3600)
    #expect(BedtimeWindow.averageNap(of: [nap], on: [wednesday], now: sundayEvening, in: amsterdam) == 1800)
    #expect(BedtimeWindow.averageNap(of: [nap], on: [tuesday, wednesday], now: sundayEvening, in: amsterdam) == 2700)

    // 12 h 30 m minus 45 m is a night of 11 h 45 m, so from 06:30 the ideal bedtime is 18:45.
    let range = RecommendedRange(birthDate: mila, on: week.sunday.name)
    let window = BedtimeWindow(wakeUp: TimeOfDay(hour: 6, minute: 30), range: range, averageNap: 2700)
    #expect(window == BedtimeWindow(start: TimeOfDay(hour: 18, minute: 30), end: TimeOfDay(hour: 19, minute: 0)))
  }

  // MARK: The copy

  @Test(arguments: [
    (42.24, "40 minutes"), (57, "55 minutes"), (58, "1 h 00 m"), (70, "1 h 10 m"), (32.4, "30 minutes"),
  ])
  func theBedtimeTipRoundsTheDistanceTo5MinutesFirst(minutes: Double, text: String) {
    #expect(
      message(.tip(.bedtimesVary(distance: minutes * 60)))
        == WhatToTry.Message(
          text: "Mila's bedtime moved around by about \(text) this week.",
          bold: "Try a fixed bedtime between 19:10 and 19:40."))
  }

  @Test func theTooLittleTip() {
    #expect(
      message(.tip(.tooLittle(average: (10 * 60 + 40) * 60)))
        == WhatToTry.Message(
          text: "Mila slept 10 h 40 m a day on average, below the 11–14 h range.",
          bold: "Try a bedtime between 19:10 and 19:40."))
  }

  @Test func theTooMuchTip() {
    #expect(
      message(.tip(.tooMuch(average: (14 * 60 + 20) * 60)))
        == WhatToTry.Message(
          text: "Mila slept 14 h 20 m a day on average, above the 11–14 h range.",
          bold: "Try a bedtime between 19:10 and 19:40."))
  }

  @Test func theLateNapTip() {
    #expect(
      message(.tip(.lateNap(days: 3)))
        == WhatToTry.Message(
          text: "Mila's last nap ended less than 3 hours before bedtime on 3 days.",
          bold: "Try to end it by 16:10, and go to bed between 19:10 and 19:40."))
  }

  @Test func thePraiseTip() {
    #expect(
      message(.tip(.praise(inRange: 5, counted: 6)))
        == WhatToTry.Message(
          text: "Mila slept well this week: in range on 5 of 6 days.",
          bold: "Keep a bedtime between 19:10 and 19:40."))
  }

  @Test func aTipWithoutAWindowHasNoBoldPart() {
    for tip: WhatToTry.Tip in [
      .bedtimesVary(distance: 2400), .tooLittle(average: 36000), .tooMuch(average: 54000), .lateNap(days: 2),
      .praise(inRange: 4, counted: 4),
    ] {
      #expect(message(.tip(tip), window: nil).bold == nil)
    }
  }

  @Test func theDoctorLine() {
    #expect(
      WhatToTry.doctorLine(name: "Mila")
        == "These are general tips. If you are worried about Mila's sleep, ask your doctor.")
  }

  // MARK: Helpers

  private func whatToTry(sleeps: [Sleep], now: Date) -> WhatToTry? {
    WhatToTry(week: week, sleeps: sleeps, birthDate: mila, now: now, in: amsterdam)
  }

  private func message(_ content: WhatToTry.Content, window: BedtimeWindow? = window) -> WhatToTry.Message {
    WhatToTry.message(
      content, window: window, range: RecommendedRange(birthDate: mila, on: week.sunday.name),
      isCurrentWeek: false, name: "Mila")
  }

  /// Mila's sleeps in the seed.
  private func seedSleeps(_ seed: Seed) -> [Sleep] {
    seed.sleeps.filter { $0.childIndex == 0 }.map {
      Sleep(id: UUID(), childID: child, start: $0.start, end: $0.end, kind: $0.kind)
    }
  }

  /// For each sleep day of November 2026 in `range`: the night before it from its bedtime to 06:30,
  /// and a nap on the day. The bedtimes default to 19:30: 11 h of night and 1 h 30 m of nap is 12 h 30 m.
  private func days(
    _ range: ClosedRange<Int>, bedtimes: [String]? = nil, nap: (String, String) = ("13:00", "14:30")
  ) -> [Sleep] {
    range.enumerated().flatMap { index, day in
      [
        night(on: day, bedtime: bedtimes?[index] ?? "19:30"),
        sleep("2026-11-0\(day)T\(nap.0):00+01:00", "2026-11-0\(day)T\(nap.1):00+01:00", .nap),
      ]
    }
  }

  /// The night of the sleep day `day` November 2026, from 2 to 9, from `bedtime` on the evening before to 06:30.
  private func night(on day: Int, bedtime: String) -> Sleep {
    sleep("2026-11-0\(day - 1)T\(bedtime):00+01:00", "2026-11-0\(day)T06:30:00+01:00", .night)
  }

  private func sleep(_ start: String, _ end: String, _ kind: SleepKind) -> Sleep {
    Sleep(id: UUID(), childID: child, start: date(start), end: date(end), kind: kind)
  }
}
