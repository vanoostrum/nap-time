import Core
import Foundation
import Testing

@Suite struct NudgeTests {
  private let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!
  private let mila = Child(id: UUID(), name: "Mila", birthDate: BirthDate(year: 2025, month: 3, day: 12)!, photo: nil)
  private let noah = Child(id: UUID(), name: "Noah", birthDate: BirthDate(year: 2022, month: 2, day: 10)!, photo: nil)

  // MARK: Bedtime nudges (Plan task 1)

  /// Criteria 1 and 2.
  @Test func theWeekSeedGivesMilaFiveEveningsAndNoahNone() throws {
    let nudges = schedule(seed: .week, now: "2026-11-08T19:30:00+01:00")
    let first = try #require(nudges.first)
    #expect(first.id == "bedtime-\(mila.id.uuidString)-2026-11-08")
    #expect(first.kind == .bedtime)
    #expect(first.childID == mila.id)
    #expect(first.fireDate == date("2026-11-08T20:45:00+01:00"))
    #expect(first.title == "Is Mila asleep?")
    #expect(first.body == "No sleep logged for Mila since 18:00. Mila usually sleeps by 19:45.")
    #expect(nudges.map(\.id) == ["08", "09", "10", "11", "12"].map { "bedtime-\(mila.id.uuidString)-2026-11-\($0)" })
    #expect(!nudges.contains { $0.childID == noah.id })
  }

  /// Criterion 3.
  @Test func anEveningNeedsThreeNightsInItsSevenSleepDays() {
    let sleeps = [
      night("2026-10-30T19:30:00+01:00"),  // sleep day 31 October: before the window
      nap("2026-11-05T19:30:00+01:00"),  // a nap does not count
      night("2026-11-06T19:30:00+01:00"),
      night("2026-11-07T19:30:00+01:00"),
    ]
    let now = date("2026-11-08T12:00:00+01:00")
    #expect(bedtimeIDs(sleeps, now: now).isEmpty)
    let withThird = sleeps + [night("2026-11-04T19:30:00+01:00")]
    #expect(bedtimeIDs(withThird, now: now).first == "bedtime-\(mila.id.uuidString)-2026-11-08")
  }

  /// Criterion 4.
  @Test func atMostFiveEveningsGetABedtimeNudge() {
    let sleeps = [
      night("2026-11-05T19:30:00+01:00"), night("2026-11-06T19:30:00+01:00"),
      night("2026-11-07T19:30:00+01:00"), night("2026-11-07T23:30:00+01:00"),
    ]
    let ids = bedtimeIDs(sleeps, now: date("2026-11-08T19:00:00+01:00"))
    #expect(ids == ["08", "09", "10", "11", "12"].map { "bedtime-\(mila.id.uuidString)-2026-11-\($0)" })
  }

  /// Criterion 5.
  @Test func aBedtimeAfterMidnightFiresOnTheNextDateWithTheEveningsId() throws {
    let sleeps = [
      night("2026-11-05T23:50:00+01:00"), night("2026-11-07T00:20:00+01:00"), night("2026-11-07T23:55:00+01:00"),
    ]
    let nudge = try #require(nudges(sleeps, now: date("2026-11-08T12:00:00+01:00")).first)
    #expect(nudge.id == "bedtime-\(mila.id.uuidString)-2026-11-08")
    #expect(nudge.fireDate == date("2026-11-09T00:55:00+01:00"))
    #expect(nudge.body == "No sleep logged for Mila since 18:00. Mila usually sleeps by 23:55.")
  }

  /// Criterion 5: the rounding of `UsualBedtime` to 5 minutes, half up.
  @Test func theFireDateAndTheBodyUseTheUsualBedtimeRoundedToFiveMinutes() throws {
    let sleeps = [
      night("2026-11-05T19:42:00+01:00"), night("2026-11-06T19:44:00+01:00"), night("2026-11-07T19:48:00+01:00"),
    ]
    let nudge = try #require(nudges(sleeps, now: date("2026-11-08T12:00:00+01:00")).first)
    #expect(nudge.fireDate == date("2026-11-08T20:45:00+01:00"))
    #expect(nudge.body == "No sleep logged for Mila since 18:00. Mila usually sleeps by 19:45.")
  }

  /// Criterion 6, first check.
  @Test func aUsualBedtimeBefore1800FiresThatEvening() throws {
    let nudge = try #require(nudges(nightsBefore1800, now: date("2026-11-08T12:00:00+01:00")).first)
    #expect(nudge.id == "bedtime-\(mila.id.uuidString)-2026-11-08")
    #expect(nudge.fireDate == date("2026-11-08T18:50:00+01:00"))
  }

  /// Criterion 7.
  @Test func aUsualBedtimeBefore1800IsTheStartOfTheSilenceWindowInTheBody() throws {
    let sleeps = [
      night("2026-11-05T16:30:00+01:00"), night("2026-11-06T16:30:00+01:00"), night("2026-11-07T16:30:00+01:00"),
    ]
    let nudge = try #require(nudges(sleeps, now: date("2026-11-08T12:00:00+01:00")).first)
    #expect(nudge.id == "bedtime-\(mila.id.uuidString)-2026-11-08")
    #expect(nudge.fireDate == date("2026-11-08T17:30:00+01:00"))
    #expect(nudge.body == "No sleep logged for Mila since 16:30. Mila usually sleeps by 16:30.")
  }

  /// Review focus 3, first half.
  @Test func aNightChangedToANapNoLongerCountsForTheUsualBedtime() throws {
    let now = date("2026-11-08T12:00:00+01:00")
    let nights = [
      night("2026-11-04T21:30:00+01:00"), night("2026-11-05T19:00:00+01:00"), night("2026-11-06T20:00:00+01:00"),
    ]
    let asNight = try #require(nudges(nights + [night("2026-11-07T21:00:00+01:00")], now: now).first)
    #expect(asNight.fireDate == date("2026-11-08T21:30:00+01:00"))
    let asNap = try #require(nudges(nights + [nap("2026-11-07T21:00:00+01:00")], now: now).first)
    #expect(asNap.fireDate == date("2026-11-08T21:00:00+01:00"))
  }

  // MARK: Silence rules and past fire dates (Plan task 2)

  /// Criterion 6, second check: the window rule.
  @Test func aNapInTheSilenceWindowBefore1800SilencesTheEvening() {
    let sleeps = nightsBefore1800 + [nap("2026-11-08T17:55:00+01:00", end: "2026-11-08T17:58:00+01:00")]
    let ids = bedtimeIDs(sleeps, now: date("2026-11-08T18:00:00+01:00"))
    #expect(!ids.contains("bedtime-\(mila.id.uuidString)-2026-11-08"))
  }

  /// Criterion 8.
  @Test(arguments: [true, false])
  func aSleepFrom1810SilencesThatEveningOnly(running: Bool) {
    let sleep = Sleep(
      id: UUID(), childID: mila.id, start: date("2026-11-08T18:10:00+01:00"),
      end: running ? nil : date("2026-11-08T18:20:00+01:00"), kind: .night)
    let ids = bedtimeIDs(nightsAt1945 + [sleep], now: date("2026-11-08T18:30:00+01:00"))
    #expect(!ids.contains("bedtime-\(mila.id.uuidString)-2026-11-08"))
    #expect(ids.contains("bedtime-\(mila.id.uuidString)-2026-11-09"))
  }

  /// Criterion 9.
  @Test(arguments: ["2026-11-08T17:30:00+01:00", "2026-11-08T18:30:00+01:00"])
  func aRunningNapFrom1730SilencesTonightOnly(now: String) {
    let sleeps = nightsAt1945 + [runningNap("2026-11-08T17:30:00+01:00")]
    let ids = bedtimeIDs(sleeps, now: date(now))
    #expect(!ids.contains("bedtime-\(mila.id.uuidString)-2026-11-08"))
    #expect(ids.contains("bedtime-\(mila.id.uuidString)-2026-11-09"))
  }

  /// Criterion 12, bedtime part: no fire date at or before now.
  @Test func aFireDateAtNowIsLeftOut() {
    let ids = bedtimeIDs(nightsAt1945, now: date("2026-11-08T20:45:00+01:00"))
    #expect(ids.first == "bedtime-\(mila.id.uuidString)-2026-11-09")
    for now in ["2026-11-08T12:00:00+01:00", "2026-11-08T20:44:00+01:00", "2026-11-09T03:00:00+01:00"] {
      #expect(nudges(nightsAt1945, now: date(now)).allSatisfy { $0.fireDate > date(now) })
    }
  }

  /// Review focus 1.
  @Test func deletingOrMovingTheEveningsSleepBringsTheNudgeBack() {
    let now = date("2026-11-08T20:00:00+01:00")
    let tonight = "bedtime-\(mila.id.uuidString)-2026-11-08"
    let ended = night("2026-11-08T19:50:00+01:00", end: "2026-11-08T19:58:00+01:00")
    #expect(!bedtimeIDs(nightsAt1945 + [ended], now: now).contains(tonight))
    #expect(bedtimeIDs(nightsAt1945, now: now).contains(tonight))
    let moved = nap("2026-11-08T17:50:00+01:00", end: "2026-11-08T19:58:00+01:00")
    #expect(bedtimeIDs(nightsAt1945 + [moved], now: now).contains(tonight))
    let movedRunning = runningNap("2026-11-08T17:50:00+01:00")
    #expect(!bedtimeIDs(nightsAt1945 + [movedRunning], now: now).contains(tonight))
  }

  /// Review focus 2.
  @Test func aMissedFireDateGivesNoLateNudge() {
    let ids = bedtimeIDs(nightsAt1945, now: date("2026-11-08T21:00:00+01:00"))
    #expect(ids.first == "bedtime-\(mila.id.uuidString)-2026-11-09")
  }

  /// Review focus 3, second half.
  @Test func aNapFrom1800StillSilencesTheEvening() {
    let sleeps = nightsAt1945 + [nap("2026-11-08T18:30:00+01:00", end: "2026-11-08T18:40:00+01:00")]
    let ids = bedtimeIDs(sleeps, now: date("2026-11-08T18:45:00+01:00"))
    #expect(!ids.contains("bedtime-\(mila.id.uuidString)-2026-11-08"))
    #expect(ids.contains("bedtime-\(mila.id.uuidString)-2026-11-09"))
  }

  // MARK: Long-sleep nudges (Plan task 3)

  /// Criterion 10.
  @Test func theSleepingSeedGivesOneLongSleepNudge() throws {
    let sleeps = seedSleeps(.sleeping)
    let found = sleeps.first { $0.isRunning }
    let running = try #require(found)
    let now = date("2026-06-21T21:56:00+02:00")
    let nudges = NudgeSchedule.nudges(children: [mila, noah], sleeps: sleeps, now: now, timeZone: amsterdam)
    #expect(
      nudges == [
        Nudge(
          id: NudgeID.longSleep(sleepID: running.id), fireDate: date("2026-06-22T09:42:00+02:00"), kind: .longSleep,
          childID: mila.id, title: "Mila has slept 14 hours", body: "Still asleep? Open Nap Time to check the sleep.")
      ])
    #expect(nudges.first?.id == "long-sleep-\(running.id.uuidString)")
    var ended = running
    ended.end = now
    let afterWaking = sleeps.map { $0.id == running.id ? ended : $0 }
    #expect(NudgeSchedule.nudges(children: [mila, noah], sleeps: afterWaking, now: now, timeZone: amsterdam).isEmpty)
  }

  /// Criterion 11.
  @Test func theNappingSeedGivesALongSleepNudgeAt0305() {
    let nudges = schedule(seed: .napping, now: "2026-06-21T13:50:00+02:00")
    #expect(nudges.map(\.fireDate) == [date("2026-06-22T03:05:00+02:00")])
    #expect(nudges.map(\.kind) == [.longSleep])
  }

  /// Criterion 12, long-sleep part.
  @Test func aSleepOf14HoursOrMoreGetsNoLateNudge() {
    let start = date("2026-11-08T20:00:00+01:00")
    let sleeps = [Sleep(id: UUID(), childID: mila.id, start: start, end: nil, kind: .night)]
    #expect(nudges(sleeps, now: start.addingTimeInterval(14 * 3600)).isEmpty)
    #expect(nudges(sleeps, now: start.addingTimeInterval(15 * 3600)).isEmpty)
    let almost = nudges(sleeps, now: start.addingTimeInterval(14 * 3600 - 60))
    #expect(almost.map(\.fireDate) == [start.addingTimeInterval(14 * 3600)])
  }

  /// Criterion 13.
  @Test func twoRunningSleepsGiveOneNudgeForTheEarliest() {
    let now = date("2026-11-08T21:00:00+01:00")
    let early = Sleep(id: UUID(), childID: mila.id, start: date("2026-11-08T20:00:00+01:00"), end: nil, kind: .night)
    let late = Sleep(id: UUID(), childID: mila.id, start: date("2026-11-08T20:30:00+01:00"), end: nil, kind: .night)
    #expect(
      nudges([late, early], now: now).map(\.id) == [NudgeID.longSleep(sleepID: early.id)])
    #expect(nudges([late, early], now: now).map(\.fireDate) == [date("2026-11-09T10:00:00+01:00")])
    let twin = Sleep(id: UUID(), childID: mila.id, start: early.start, end: nil, kind: .night)
    let lower = [early, twin].min { $0.id.uuidString < $1.id.uuidString }!
    #expect(nudges([early, twin], now: now).map(\.id) == [NudgeID.longSleep(sleepID: lower.id)])
    #expect(nudges([twin, early], now: now).map(\.id) == [NudgeID.longSleep(sleepID: lower.id)])
  }

  // MARK: Children, the cap, and clock changes (Plan task 4)

  /// Criterion 14 and review focus 4.
  @Test func twoChildrenGetTheirNudgesIndependently() {
    let now = date("2026-11-08T12:00:00+01:00")
    let noahsSleeps = [
      sleep(noah, "2026-11-05T20:30:00+01:00", .night), sleep(noah, "2026-11-06T20:30:00+01:00", .night),
      sleep(noah, "2026-11-07T20:30:00+01:00", .night),
      Sleep(
        id: UUID(), childID: noah.id, start: date("2026-11-08T11:00:00+01:00"), end: nil, kind: .nap),
    ]
    let sleeps = nightsAt1945 + noahsSleeps
    let both = NudgeSchedule.nudges(children: [mila, noah], sleeps: sleeps, now: now, timeZone: amsterdam)
    let milaAlone = NudgeSchedule.nudges(children: [mila], sleeps: sleeps, now: now, timeZone: amsterdam)
    let noahAlone = NudgeSchedule.nudges(children: [noah], sleeps: sleeps, now: now, timeZone: amsterdam)
    #expect(both.filter { $0.childID == mila.id } == milaAlone)
    #expect(both.filter { $0.childID == noah.id } == noahAlone)
    #expect(both.count == milaAlone.count + noahAlone.count)
    #expect(Set(both.map(\.id)).count == both.count)
    #expect(!milaAlone.isEmpty && !noahAlone.isEmpty)
    #expect(noahAlone.contains { $0.kind == .longSleep })
    #expect(noahAlone.allSatisfy { $0.title.contains("Noah") })
  }

  /// Criterion 15.
  @Test func elevenChildrenGiveTheFirst64NudgesByFireDate() {
    let now = date("2026-11-08T12:00:00+01:00")
    let children = (0..<11).map {
      Child(id: UUID(), name: "Child \($0)", birthDate: BirthDate(year: 2024, month: 1, day: 1)!, photo: nil)
    }
    let sleeps = children.flatMap { child in
      [
        sleep(child, "2026-11-05T19:45:00+01:00", .night), sleep(child, "2026-11-06T19:45:00+01:00", .night),
        sleep(child, "2026-11-06T23:30:00+01:00", .night), sleep(child, "2026-11-07T19:45:00+01:00", .night),
        sleep(child, "2026-11-07T23:30:00+01:00", .night),
        Sleep(id: UUID(), childID: child.id, start: date("2026-11-08T11:00:00+01:00"), end: nil, kind: .nap),
      ]
    }
    let each = children.map {
      NudgeSchedule.nudges(children: [$0], sleeps: sleeps, now: now, timeZone: amsterdam)
    }
    #expect(each.allSatisfy { $0.count == 6 })
    let all = each.flatMap { $0 }.sorted {
      $0.fireDate != $1.fireDate ? $0.fireDate < $1.fireDate : $0.id < $1.id
    }
    let nudges = NudgeSchedule.nudges(children: children, sleeps: sleeps, now: now, timeZone: amsterdam)
    #expect(nudges.count == 64)
    #expect(nudges == Array(all.prefix(64)))
    #expect(NudgeSync(pendingIDs: [], nudges: nudges).nudgesToAdd == nudges)
  }

  /// Criterion 16.
  @Test func theEndOfSummerTimeKeepsRealHoursAndClockTimes() {
    let running = Sleep(
      id: UUID(), childID: mila.id, start: date("2026-10-24T20:00:00+02:00"), end: nil, kind: .night)
    let long = nudges([running], now: date("2026-10-24T21:00:00+02:00"))
    #expect(long.map(\.id) == [NudgeID.longSleep(sleepID: running.id)])
    #expect(long.map(\.fireDate) == [date("2026-10-25T09:00:00+01:00")])

    let nights = [
      night("2026-10-22T19:45:00+02:00"), night("2026-10-23T19:45:00+02:00"), night("2026-10-24T19:45:00+02:00"),
    ]
    let bedtime = nudges(nights, now: date("2026-10-25T12:00:00+01:00"))
    #expect(bedtime.first?.id == "bedtime-\(mila.id.uuidString)-2026-10-25")
    #expect(bedtime.first?.fireDate == date("2026-10-25T20:45:00+01:00"))
    #expect(!bedtime.contains { $0.id.hasSuffix("2026-10-24") })
  }

  /// Criterion 17 and review focus 5.
  @Test func aFireDateInTheGapMovesToTheEndOfTheGap() {
    let nights = [
      night("2026-03-26T01:30:00+01:00"), night("2026-03-27T01:30:00+01:00"), night("2026-03-28T01:30:00+01:00"),
    ]
    let evening = nudges(nights, now: date("2026-03-28T12:00:00+01:00")).filter {
      $0.id.hasSuffix("2026-03-28")
    }
    #expect(evening.map(\.fireDate) == [date("2026-03-29T03:00:00+02:00")])
    #expect(evening.first?.body == "No sleep logged for Mila since 18:00. Mila usually sleeps by 01:30.")
  }

  /// The repeated hour at the end of summer time uses the first occurrence.
  @Test func aFireDateInTheRepeatedHourUsesTheFirstOccurrence() {
    let nights = [
      night("2026-10-22T01:30:00+02:00"), night("2026-10-23T01:30:00+02:00"), night("2026-10-24T01:30:00+02:00"),
    ]
    let evening = nudges(nights, now: date("2026-10-24T12:00:00+02:00")).filter {
      $0.id.hasSuffix("2026-10-24")
    }
    #expect(evening.map(\.fireDate) == [date("2026-10-25T02:30:00+02:00")])
  }

  // MARK: NudgeSync (Plan task 5)

  /// Criterion 18.
  @Test func syncReplacesTheNudgesAndKeepsOtherRequests() {
    let new = nudges(nightsAt1945, now: date("2026-11-08T12:00:00+01:00")).prefix(2).map { $0 }
    #expect(new.count == 2)
    let pending = ["bedtime-A-2026-11-08", "long-sleep-S", "other-1"]
    let first = NudgeSync(pendingIDs: pending, nudges: new)
    #expect(first.idsToRemove == ["bedtime-A-2026-11-08", "long-sleep-S"])
    #expect(first.nudgesToAdd == new)
    let afterFirst = apply(first, to: pending)
    let second = NudgeSync(pendingIDs: afterFirst, nudges: new)
    #expect(apply(second, to: afterFirst).sorted() == afterFirst.sorted())
    #expect(afterFirst.contains("other-1"))
  }

  @Test func notificationsAreOnlyEnabledInTheNormalMode() {
    #expect(AppMode.normal.areNotificationsEnabled)
    #expect(!AppMode.test(.standard).areNotificationsEnabled)
  }

  // MARK: Helpers

  /// Nights from 19:45 on Thursday 5, Friday 6, and Saturday 7 November 2026: a usual bedtime of 19:45.
  private var nightsAt1945: [Sleep] {
    [night("2026-11-05T19:45:00+01:00"), night("2026-11-06T19:45:00+01:00"), night("2026-11-07T19:45:00+01:00")]
  }

  /// Nights from 17:45, 17:55, and 17:50 on 5 to 7 November 2026, set to nights: a usual bedtime of 17:50.
  private var nightsBefore1800: [Sleep] {
    [night("2026-11-05T17:45:00+01:00"), night("2026-11-06T17:55:00+01:00"), night("2026-11-07T17:50:00+01:00")]
  }

  private func schedule(seed: Seed, now: String) -> [Nudge] {
    NudgeSchedule.nudges(children: [mila, noah], sleeps: seedSleeps(seed), now: date(now), timeZone: amsterdam)
  }

  private func seedSleeps(_ seed: Seed) -> [Sleep] {
    let ids = [mila.id, noah.id]
    return seed.sleeps.map {
      Sleep(id: UUID(), childID: ids[$0.childIndex], start: $0.start, end: $0.end, kind: $0.kind)
    }
  }

  private func nudges(_ sleeps: [Sleep], now: Date) -> [Nudge] {
    NudgeSchedule.nudges(children: [mila], sleeps: sleeps, now: now, timeZone: amsterdam)
  }

  private func bedtimeIDs(_ sleeps: [Sleep], now: Date) -> [String] {
    nudges(sleeps, now: now).filter { $0.kind == .bedtime }.map(\.id)
  }

  /// An ended night of Mila of 10 hours, or one that ends at `end`.
  private func night(_ start: String, end: String? = nil) -> Sleep {
    let begin = date(start)
    return Sleep(
      id: UUID(), childID: mila.id, start: begin, end: end.map(date) ?? begin.addingTimeInterval(10 * 3600),
      kind: .night)
  }

  /// A nap of Mila of 1 hour, or one that ends at `end`.
  private func nap(_ start: String, end: String? = nil) -> Sleep {
    let begin = date(start)
    return Sleep(
      id: UUID(), childID: mila.id, start: begin, end: end.map(date) ?? begin.addingTimeInterval(3600), kind: .nap)
  }

  /// A running nap of Mila.
  private func runningNap(_ start: String) -> Sleep {
    Sleep(id: UUID(), childID: mila.id, start: date(start), end: nil, kind: .nap)
  }

  private func sleep(_ child: Child, _ start: String, _ kind: SleepKind) -> Sleep {
    let begin = date(start)
    return Sleep(id: UUID(), childID: child.id, start: begin, end: begin.addingTimeInterval(3600), kind: kind)
  }

  private func apply(_ sync: NudgeSync, to pending: [String]) -> [String] {
    pending.filter { !sync.idsToRemove.contains($0) } + sync.nudgesToAdd.map(\.id)
  }

  private func date(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso)!
  }
}
