import Core
import Foundation
import Testing

@Suite struct SeedTests {
  private let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!

  @Test func familyHasMilasLastNight() {
    #expect(
      Seed.family.sleeps == [
        SeedSleep(
          childIndex: 0, start: date("2026-06-20T19:45:00+02:00"), end: date("2026-06-21T06:55:00+02:00"), kind: .night)
      ])
  }

  @Test func sleepingIsTheFamilyWithARunningNightForMila() {
    #expect(Seed.sleeping.children == Seed.family.children)
    #expect(Seed.sleeping.selectedIndex == 0)
    #expect(
      Seed.sleeping.sleeps
        == Seed.family.sleeps + [
          SeedSleep(childIndex: 0, start: date("2026-06-21T19:42:00+02:00"), end: nil, kind: .night)
        ])
  }

  @Test func nappingIsTheFamilyWithARunningNapForMila() {
    #expect(Seed.napping.children == Seed.family.children)
    #expect(
      Seed.napping.sleeps
        == Seed.family.sleeps + [
          SeedSleep(childIndex: 0, start: date("2026-06-21T13:05:00+02:00"), end: nil, kind: .nap)
        ])
  }

  @Test func theSeedKindsMatchTheGuess() {
    for seed in Seed.allCases {
      for sleep in seed.sleeps {
        #expect(SleepKind.guess(start: sleep.start, in: amsterdam) == sleep.kind)
      }
    }
  }

  @Test func eveningIsTheFamilyWithANapForMila() {
    #expect(Seed.evening.children == Seed.family.children)
    #expect(Seed.evening.selectedIndex == 0)
    #expect(
      Seed.evening.sleeps
        == Seed.family.sleeps + [
          SeedSleep(
            childIndex: 0, start: date("2026-06-21T14:15:00+02:00"), end: date("2026-06-21T15:10:00+02:00"), kind: .nap)
        ])
  }

  @Test func theSharingSeedsAreTheFamily() {
    for seed in [Seed.shared, .invited, .noICloud, .joined] {
      #expect(seed.children == Seed.family.children)
      #expect(seed.sleeps == Seed.family.sleeps)
      #expect(seed.selectedIndex == 0)
    }
    #expect(Seed.family.children.allSatisfy { !$0.onlyOnThisPhone })
  }

  @Test func partnerHasLouOnlyOnThisPhoneAddedFirst() {
    let children = Seed.partner.children
    #expect(children.map(\.name) == ["Lou", "Mila", "Noah"])
    #expect(children.map(\.onlyOnThisPhone) == [true, false, false])
    #expect(children[0].birthDate == BirthDate(year: 2024, month: 5, day: 3)!)
    #expect(Array(children.dropFirst()) == Seed.family.children)
    #expect(Seed.partner.selectedIndex == 1)
    #expect(
      Seed.partner.sleeps == [
        SeedSleep(
          childIndex: 1, start: date("2026-06-20T19:45:00+02:00"), end: date("2026-06-21T06:55:00+02:00"), kind: .night)
      ])
  }

  @Test func joiningHasNoChildren() {
    #expect(Seed.joining.children.isEmpty)
    #expect(Seed.joining.sleeps.isEmpty)
  }

  @Test func duplicateRunningHasTwoRunningNightsForMila() {
    #expect(Seed.duplicateRunning.children == Seed.family.children)
    #expect(
      Seed.duplicateRunning.sleeps
        == Seed.family.sleeps + [
          SeedSleep(childIndex: 0, start: date("2026-06-21T19:42:00+02:00"), end: nil, kind: .night),
          SeedSleep(childIndex: 0, start: date("2026-06-21T19:44:00+02:00"), end: nil, kind: .night),
        ])
  }

  @Test func overlappingMergesIntoTheSleepsOfTheSpec() {
    let mila = UUID()
    let noah = UUID()
    let sleeps = Seed.overlapping.sleeps.map { seed in
      Sleep(id: UUID(), childID: seed.childIndex == 0 ? mila : noah, start: seed.start, end: seed.end, kind: seed.kind)
    }
    let merges = SleepMerge.merges(of: sleeps)
    #expect(merges.count == 2)
    let noahs = merges.first { $0.kept.childID == noah }
    #expect(noahs?.kept.start == date("2026-06-20T19:00:00+02:00"))
    #expect(noahs?.kept.end == date("2026-06-21T20:30:00+02:00"))
    let milas = merges.first { $0.kept.childID == mila }
    #expect(milas?.kept.start == date("2026-06-21T19:42:00+02:00"))
    #expect(milas?.kept.end == date("2026-06-22T06:50:00+02:00"))
  }

  @Test func winterMorningHasOnlyMilasNovemberNight() {
    #expect(Seed.winterMorning.children == Seed.family.children)
    #expect(Seed.winterMorning.selectedIndex == 0)
    #expect(
      Seed.winterMorning.sleeps == [
        SeedSleep(
          childIndex: 0, start: date("2026-11-14T19:48:00+01:00"), end: date("2026-11-15T06:40:00+01:00"), kind: .night)
      ])
  }

  @Test func theOtherSeedsHaveNoSleeps() {
    #expect(Seed.none.sleeps.isEmpty)
    #expect(Seed.longName.sleeps.isEmpty)
  }

  @Test(arguments: ["sleeping", "napping", "evening", "winter-morning", "week", "week-today"])
  func theNewSeedsParse(name: String) throws {
    let mode = try LaunchArguments.parse(["/path/to/NapTime", "--test-mode", "--seed", name])
    guard case .test(let environment) = mode else {
      Issue.record("Expected test mode, got \(mode)")
      return
    }
    #expect(environment.seed.rawValue == name)
    #expect(environment.timeZone.identifier == "Europe/Amsterdam")
  }

  /// What the home screen shows for Mila with each seed at the time its UI test passes.
  @Test(arguments: [
    (Seed.family, "2026-06-21T10:00:00+02:00", "Mila is awake", "since 06:55 · 11 h 10 m slept today", SkyPhase.day),
    (.sleeping, "2026-06-21T21:56:00+02:00", "Mila is sleeping", "2 h 14 m · since 19:42", .night),
    (.napping, "2026-06-21T13:50:00+02:00", "Mila is sleeping", "45 m · since 13:05", .day),
    (.evening, "2026-06-21T22:05:00+02:00", "Mila is awake", "since 15:10 · 12 h 05 m slept today", .sunset),
    (.evening, "2026-06-21T23:30:00+02:00", "Mila is awake", "since 15:10 · 12 h 05 m slept today", .night),
    (.winterMorning, "2026-11-15T08:00:00+01:00", "Mila is awake", "since 06:40 · 10 h 52 m slept today", .sunrise),
  ])
  func milasStatusForEachSeed(seed: Seed, now: String, heading: String, line: String, sky: SkyPhase) {
    let childID = UUID()
    let sleeps = seed.sleeps.filter { $0.childIndex == 0 }.map {
      Sleep(id: UUID(), childID: childID, start: $0.start, end: $0.end, kind: $0.kind)
    }
    let status = ChildStatus(sleeps: sleeps, now: date(now), in: amsterdam)
    #expect(status.heading(name: "Mila") == heading)
    #expect(status.line == line)
    #expect(status.sky == sky)
  }

  // MARK: The week seeds

  @Test func weekIsTheFamilyWithMilasWeekAndOneNapOfNoah() {
    #expect(Seed.week.children == Seed.family.children)
    #expect(Seed.week.selectedIndex == 0)
    #expect(Array(Seed.week.sleeps.prefix(1)) == Seed.family.sleeps)
    let noah = Seed.week.sleeps.filter { $0.childIndex == 1 }
    #expect(
      noah == [
        SeedSleep(
          childIndex: 1, start: date("2026-11-03T13:00:00+01:00"), end: date("2026-11-03T14:30:00+01:00"), kind: .nap)
      ])
  }

  @Test func weekTodayIsWeekWithMilasSleepsFromMonday9November() {
    #expect(Seed.weekToday.children == Seed.family.children)
    #expect(Array(Seed.weekToday.sleeps.prefix(Seed.week.sleeps.count)) == Seed.week.sleeps)
    let extra = Seed.weekToday.sleeps.dropFirst(Seed.week.sleeps.count)
    #expect(extra.allSatisfy { $0.childIndex == 0 })
    #expect(extra.first?.start == date("2026-11-08T19:45:00+01:00"))
  }

  /// `charts/week.html`: Mila's week on Sunday 8 November at 19:30.
  @Test func weekMatchesTheChartsWeekPage() {
    let stats = milasWeek(Seed.week, monday: day(2026, 11, 2), now: "2026-11-08T19:30:00+01:00")
    #expect(
      stats.days.map { SleepDuration.text($0.total) } == [
        "12 h 36 m", "10 h 12 m", "12 h 06 m", "13 h 00 m", "10 h 48 m", "11 h 54 m", "14 h 24 m",
      ])
    #expect(stats.days.map(\.judgement) == [.inRange, .tooLittle, .inRange, .inRange, .tooLittle, .inRange, .tooMuch])
    #expect(abs(stats.days.reduce(0) { $0 + $1.total } / 7 / 60 - 728.57) < 0.01)
    #expect(stats.averageText == "12 h 09 m")
    #expect(stats.range.description == "11–14 h")
    #expect(stats.inRangeText == "4 of 7 days")
    #expect(milasBedtime(Seed.week, monday: day(2026, 11, 2)).note == "bed ~19:45 · up ~06:30")
  }

  /// `charts/week-today.html`: Mila's week on Wednesday 11 November at 10:00.
  @Test func weekTodayMatchesTheChartsWeekTodayPage() {
    let stats = milasWeek(Seed.weekToday, monday: day(2026, 11, 9), now: "2026-11-11T10:00:00+01:00")
    #expect(stats.days.prefix(3).map { SleepDuration.text($0.total) } == ["12 h 15 m", "10 h 39 m", "10 h 50 m"])
    #expect(stats.days.map(\.state) == [.counted, .counted, .soFar, .empty, .empty, .empty, .empty])
    #expect(stats.days.prefix(2).map(\.judgement) == [.inRange, .tooLittle])
    #expect(stats.averageText == "11 h 27 m")
    #expect(stats.inRangeText == "1 of 2 days")
    #expect(milasBedtime(Seed.weekToday, monday: day(2026, 11, 9)).note == "bed ~19:50 · up ~06:30")
    let now = date("2026-11-11T10:00:00+01:00")
    #expect(Week.opening(now: now, in: amsterdam).monday == day(2026, 11, 9))
    #expect(Week.current(now: now, in: amsterdam).monday == day(2026, 11, 9))
  }

  /// `charts/empty.html`: Noah's week on Wednesday 11 November at 10:00.
  @Test func noahsCurrentWeekIsEmptyAndHisArrowsGoBackToHisNap() {
    let childID = UUID()
    let sleeps = sleeps(of: 1, in: Seed.week, childID: childID)
    let now = date("2026-11-11T10:00:00+01:00")
    let week = Week.opening(now: now, in: amsterdam)
    let stats = WeekStats(
      week: week, sleeps: sleeps, birthDate: Seed.week.children[1].birthDate, now: now, in: amsterdam)
    #expect(!stats.hasSleep)
    #expect(stats.range.description == "10–13 h")
    #expect(week.title == "Mon 9 – Sun 15 Nov")
    let weeks = Week.reachable(firstSleepStart: sleeps.map(\.start).min(), now: now, in: amsterdam)
    #expect(weeks.lowerBound.monday == day(2026, 11, 2))
    #expect(weeks.upperBound == week)
  }

  private func sleeps(of childIndex: Int, in seed: Seed, childID: UUID) -> [Sleep] {
    seed.sleeps.filter { $0.childIndex == childIndex }.map {
      Sleep(id: UUID(), childID: childID, start: $0.start, end: $0.end, kind: $0.kind)
    }
  }

  private func milasWeek(_ seed: Seed, monday: BirthDate, now: String) -> WeekStats {
    WeekStats(
      week: Week(containing: SleepDay(named: monday)), sleeps: sleeps(of: 0, in: seed, childID: UUID()),
      birthDate: seed.children[0].birthDate, now: date(now), in: amsterdam)
  }

  private func milasBedtime(_ seed: Seed, monday: BirthDate) -> UsualBedtime {
    let week = Week(containing: SleepDay(named: monday))
    let nights = UsualBedtime.nights(of: sleeps(of: 0, in: seed, childID: UUID()), in: week, timeZone: amsterdam)
    return UsualBedtime(nights: nights, in: amsterdam)
  }
}
