import Core
import Foundation
import Testing

@Suite struct SleepTimerTests {
  private let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!
  private let utc = TimeZone(identifier: "UTC")!
  private let mila = UUID()
  private let noah = UUID()

  // MARK: Small Core additions (criteria 11 to 13)

  @Test func theLongSleepNudgeIdIsLongSleepAndTheSleepId() {
    let id = UUID()
    #expect(NudgeID.longSleep(sleepID: id) == "long-sleep-\(id.uuidString)")
  }

  @Test(arguments: SleepKind.allCases)
  func aSleepKindEncodesAndDecodes(kind: SleepKind) throws {
    let data = try JSONEncoder().encode(kind)
    #expect(try JSONDecoder().decode(SleepKind.self, from: data) == kind)
  }

  @Test func liveActivitiesAreOnlyEnabledInTheNormalMode() {
    #expect(AppMode.normal.areLiveActivitiesEnabled)
    #expect(!AppMode.test(.standard).areLiveActivitiesEnabled)
  }

  // MARK: Start rule (criteria 1 to 5)

  @Test(arguments: [
    ("2026-11-16T19:45:00+01:00", SleepKind.night, String?("2026-11-17T04:00:00+01:00")),
    ("2026-11-17T02:10:00+01:00", .night, "2026-11-17T04:00:00+01:00"),
    ("2026-11-17T04:30:00+01:00", .night, nil),
    ("2026-11-17T03:59:00+01:00", .night, "2026-11-17T04:00:00+01:00"),
    ("2026-11-17T04:00:00+01:00", .night, nil),
    ("2026-11-16T12:00:00+01:00", .night, "2026-11-17T04:00:00+01:00"),
    ("2026-11-16T11:59:00+01:00", .night, nil),
    ("2026-11-16T15:30:00+01:00", .night, "2026-11-17T04:00:00+01:00"),
    ("2026-11-16T13:05:00+01:00", .nap, nil),
  ])
  func theStartIsNowOrScheduledAt0400(start: String, kind: SleepKind, showsFrom: String?) {
    let sleep = running(mila, from: start, kind)
    #expect(SleepTimerRule.start(for: sleep, now: date(start), timeZone: amsterdam) == showsFrom.map(date))
  }

  @Test func aScheduledStartThatHasPassedIsNow() {
    let sleep = running(mila, from: "2026-11-16T19:45:00+01:00", .night)
    #expect(SleepTimerRule.start(for: sleep, now: date("2026-11-17T05:00:00+01:00"), timeZone: amsterdam) == nil)
  }

  @Test func acrossTheStartOfSummerTime() throws {
    let evening = running(mila, from: "2026-03-28T20:00:00+01:00", .night)
    let scheduled = SleepTimerRule.start(for: evening, now: evening.start, timeZone: amsterdam)
    #expect(scheduled == date("2026-03-29T04:00:00+02:00"))
    #expect(try #require(scheduled).timeIntervalSince(evening.start) == TimeInterval(7 * 3600))

    let late = running(mila, from: "2026-03-29T01:30:00+01:00", .night)
    #expect(SleepTimerRule.start(for: late, now: late.start, timeZone: amsterdam) == date("2026-03-29T04:00:00+02:00"))
  }

  @Test func acrossTheEndOfSummerTime() throws {
    let evening = running(mila, from: "2026-10-24T20:00:00+02:00", .night)
    let scheduled = SleepTimerRule.start(for: evening, now: evening.start, timeZone: amsterdam)
    #expect(scheduled == date("2026-10-25T04:00:00+01:00"))
    #expect(try #require(scheduled).timeIntervalSince(evening.start) == TimeInterval(9 * 3600))

    for start in ["2026-10-25T02:30:00+02:00", "2026-10-25T02:30:00+01:00"] {
      let sleep = running(mila, from: start, .night)
      #expect(
        SleepTimerRule.start(for: sleep, now: sleep.start, timeZone: amsterdam) == date("2026-10-25T04:00:00+01:00"))
    }
  }

  @Test func theStartRuleUsesTheGivenTimeZone() {
    let sleep = running(mila, from: "2026-11-16T18:45:00Z", .night)
    #expect(
      SleepTimerRule.start(for: sleep, now: sleep.start, timeZone: amsterdam) == date("2026-11-17T04:00:00+01:00"))
    #expect(SleepTimerRule.start(for: sleep, now: sleep.start, timeZone: utc) == date("2026-11-17T04:00:00Z"))
  }

  // MARK: Reconcile (criteria 6 to 9 and 24)

  @Test func aTimerWithNoRunningSleepEnds() {
    let night = running(mila, from: "2026-11-16T19:45:00+01:00", .night)
    let timer = pending(night, showsFrom: "2026-11-17T04:00:00+01:00", id: "a")
    var ended = night
    ended.end = date("2026-11-17T06:30:00+01:00")

    for sleeps in [[], [ended]] {
      let changes = SleepTimerRule.changes(
        timers: [timer], runningSleeps: sleeps, now: date("2026-11-17T06:31:00+01:00"), timeZone: amsterdam)
      #expect(changes == [.end(id: "a")])
    }
  }

  /// Review focus 1: a night from 23:50 ends through "Wake up" at 02:00. The pending timer ends.
  @Test func aPendingNightTimerEndsWhenTheNightEndsBefore0400() {
    let night = running(mila, from: "2026-11-16T23:50:00+01:00", .night)
    let timer = pending(night, showsFrom: "2026-11-17T04:00:00+01:00", id: "a")

    let changes = SleepTimerRule.changes(
      timers: [timer], runningSleeps: [], now: date("2026-11-17T02:00:00+01:00"), timeZone: amsterdam)

    #expect(changes == [.end(id: "a")])
  }

  @Test func anEarlierStartWithTheSameShowTimeIsAnUpdate() {
    let night = running(mila, from: "2026-11-16T20:00:00+01:00", .night)
    let timer = pending(night, showsFrom: "2026-11-17T04:00:00+01:00", id: "a")
    let moved = Sleep(id: night.id, childID: mila, start: date("2026-11-16T19:30:00+01:00"), end: nil, kind: .night)

    let changes = SleepTimerRule.changes(
      timers: [timer], runningSleeps: [moved], now: date("2026-11-16T21:00:00+01:00"), timeZone: amsterdam)

    #expect(changes == [.update(id: "a", sleepID: night.id, start: moved.start, kind: .night)])
  }

  @Test func aTimerFollowsTheSleepThatTheMergeKeeps() {
    let own = running(mila, from: "2026-11-16T19:44:00+01:00", .night)
    let timer = pending(own, showsFrom: "2026-11-17T04:00:00+01:00", id: "a")
    let kept = running(mila, from: "2026-11-16T19:42:00+01:00", .night)

    let changes = SleepTimerRule.changes(
      timers: [timer], runningSleeps: [kept], now: date("2026-11-16T21:00:00+01:00"), timeZone: amsterdam)

    #expect(changes == [.update(id: "a", sleepID: kept.id, start: kept.start, kind: .night)])
  }

  @Test func aPendingNightThatBecomesANapShowsAtOnce() {
    let night = running(mila, from: "2026-11-16T20:30:00+01:00", .night)
    let timer = pending(night, showsFrom: "2026-11-17T04:00:00+01:00", id: "a")
    let nap = Sleep(id: night.id, childID: mila, start: night.start, end: nil, kind: .nap)

    let changes = SleepTimerRule.changes(
      timers: [timer], runningSleeps: [nap], now: date("2026-11-16T21:00:00+01:00"), timeZone: amsterdam)

    #expect(changes == [.replace(id: "a", sleepID: night.id, start: night.start, kind: .nap, showsFrom: nil)])
  }

  /// Review focus 3: the start of a pending night moves from 12:30 back to 11:50, so the night card shows at once.
  @Test func aNightStartThatMovesBefore1200ShowsAtOnce() {
    let night = running(mila, from: "2026-11-16T12:30:00+01:00", .night)
    let timer = pending(night, showsFrom: "2026-11-17T04:00:00+01:00", id: "a")
    let moved = Sleep(id: night.id, childID: mila, start: date("2026-11-16T11:50:00+01:00"), end: nil, kind: .night)

    let changes = SleepTimerRule.changes(
      timers: [timer], runningSleeps: [moved], now: date("2026-11-16T13:00:00+01:00"), timeZone: amsterdam)

    #expect(changes == [.replace(id: "a", sleepID: night.id, start: moved.start, kind: .night, showsFrom: nil)])
  }

  @Test(arguments: [
    ("2026-11-16T20:00:00+01:00", "2026-11-16T20:30:00+01:00"),
    ("2026-11-16T14:00:00+01:00", "2026-11-16T14:30:00+01:00"),
  ])
  func aShownNapThatBecomesANightIsScheduledAt0400(start: String, now: String) {
    let nap = running(mila, from: start, .nap)
    let timer = shown(nap, id: "a")
    let night = Sleep(id: nap.id, childID: mila, start: nap.start, end: nil, kind: .night)

    let changes = SleepTimerRule.changes(timers: [timer], runningSleeps: [night], now: date(now), timeZone: amsterdam)

    #expect(
      changes == [
        .replace(id: "a", sleepID: nap.id, start: nap.start, kind: .night, showsFrom: date("2026-11-17T04:00:00+01:00"))
      ])
  }

  @Test func aMatchingTimerAndASleepWithoutATimerGiveNoChange() {
    let night = running(mila, from: "2026-11-16T19:45:00+01:00", .night)
    let nap = running(noah, from: "2026-11-16T13:05:00+01:00", .nap)
    let timer = pending(night, showsFrom: "2026-11-17T04:00:00+01:00", id: "a")

    let changes = SleepTimerRule.changes(
      timers: [timer], runningSleeps: [night, nap], now: date("2026-11-16T21:00:00+01:00"), timeZone: amsterdam)

    #expect(changes.isEmpty)
  }

  @Test func aShownNightTimerAfter0400GivesNoChange() {
    let night = running(mila, from: "2026-11-16T19:42:00+01:00", .night)
    let timer = shown(night, showsFrom: "2026-11-17T04:00:00+01:00", id: "a")

    let changes = SleepTimerRule.changes(
      timers: [timer], runningSleeps: [night], now: date("2026-11-17T04:10:00+01:00"), timeZone: amsterdam)

    #expect(changes.isEmpty)
  }

  @Test func ofTwoTimersTheOneWithTheRunningSleepsIdStays() {
    let night = running(mila, from: "2026-11-16T19:44:00+01:00", .night)
    let other = running(mila, from: "2026-11-16T19:42:00+01:00", .night)
    let keep = pending(night, showsFrom: "2026-11-17T04:00:00+01:00", id: "b")
    let drop = pending(other, showsFrom: "2026-11-17T04:00:00+01:00", id: "a")

    let changes = SleepTimerRule.changes(
      timers: [drop, keep], runningSleeps: [night], now: date("2026-11-16T21:00:00+01:00"), timeZone: amsterdam)

    #expect(changes == [.end(id: "a")])
  }

  @Test func ofTwoTimersWithTheRunningSleepsIdTheEarliestStartStays() {
    let night = running(mila, from: "2026-11-16T19:42:00+01:00", .night)
    let early = pending(night, showsFrom: "2026-11-17T04:00:00+01:00", id: "b")
    let late = SleepTimerSnapshot(
      id: "a", childID: mila, sleepID: night.id, start: date("2026-11-16T19:44:00+01:00"), kind: .night,
      showsFrom: date("2026-11-17T04:00:00+01:00"), isShowing: false)

    let changes = SleepTimerRule.changes(
      timers: [late, early], runningSleeps: [night], now: date("2026-11-16T21:00:00+01:00"), timeZone: amsterdam)

    #expect(changes == [.end(id: "a")])
  }

  @Test func ofTwoEqualTimersTheLowestIdStays() {
    let night = running(mila, from: "2026-11-16T19:42:00+01:00", .night)
    let first = shown(night, showsFrom: "2026-11-17T04:00:00+01:00", id: "a")
    let duplicate = shown(night, showsFrom: "2026-11-17T04:00:00+01:00", id: "b")

    let changes = SleepTimerRule.changes(
      timers: [duplicate, first], runningSleeps: [night], now: date("2026-11-17T04:10:00+01:00"), timeZone: amsterdam)

    #expect(changes == [.end(id: "b")])
  }

  /// Criterion 24 and review focus 2: the partner's wake and nap reach this phone in one reconcile.
  @Test func aLaterSleepOfTheChildEndsTheTimerAndGetsNoTimer() {
    let night = running(mila, from: "2026-11-16T19:42:00+01:00", .night)
    let timer = shown(night, showsFrom: "2026-11-17T04:00:00+01:00", id: "a")
    var ended = night
    ended.end = date("2026-11-17T06:30:00+01:00")
    let nap = running(mila, from: "2026-11-17T09:00:00+01:00", .nap)

    let changes = SleepTimerRule.changes(
      timers: [timer], runningSleeps: [ended, nap], now: date("2026-11-17T09:05:00+01:00"), timeZone: amsterdam)

    #expect(changes == [.end(id: "a")])
  }

  /// Review focus 4: Mila and Noah both sleep, and Noah wakes. Only Noah's timer ends.
  @Test func onlyTheTimerOfTheChildThatWokeEnds() {
    let milaNight = running(mila, from: "2026-11-16T19:42:00+01:00", .night)
    let noahNight = running(noah, from: "2026-11-16T19:50:00+01:00", .night)
    let milaTimer = shown(milaNight, showsFrom: "2026-11-17T04:00:00+01:00", id: "a")
    let noahTimer = shown(noahNight, showsFrom: "2026-11-17T04:00:00+01:00", id: "b")

    let changes = SleepTimerRule.changes(
      timers: [milaTimer, noahTimer], runningSleeps: [milaNight], now: date("2026-11-17T06:00:00+01:00"),
      timeZone: amsterdam)

    #expect(changes == [.end(id: "b")])
  }

  // MARK: Awake (criterion 10)

  @Test func awakeEndsOnlyTheChildsRunningSleepWithThatId() {
    let night = running(mila, from: "2026-11-16T19:42:00+01:00", .night)
    var ended = night
    ended.end = date("2026-11-17T06:30:00+01:00")
    let nap = running(mila, from: "2026-11-17T09:00:00+01:00", .nap)

    #expect(SleepTimerRule.awakeEndsSleep(sleepID: night.id, childSleeps: [night]))
    #expect(!SleepTimerRule.awakeEndsSleep(sleepID: night.id, childSleeps: [ended]))
    #expect(!SleepTimerRule.awakeEndsSleep(sleepID: night.id, childSleeps: []))
    // Review focus 2: the partner woke Mila and started a nap. "Awake" on the night card keeps the nap.
    #expect(!SleepTimerRule.awakeEndsSleep(sleepID: night.id, childSleeps: [nap, ended]))
  }

  // MARK: Helpers

  private func running(_ child: UUID, from start: String, _ kind: SleepKind) -> Sleep {
    Sleep(id: UUID(), childID: child, start: date(start), end: nil, kind: kind)
  }

  private func pending(_ sleep: Sleep, showsFrom: String, id: String) -> SleepTimerSnapshot {
    SleepTimerSnapshot(
      id: id, childID: sleep.childID, sleepID: sleep.id, start: sleep.start, kind: sleep.kind,
      showsFrom: date(showsFrom), isShowing: false)
  }

  private func shown(_ sleep: Sleep, showsFrom: String? = nil, id: String) -> SleepTimerSnapshot {
    SleepTimerSnapshot(
      id: id, childID: sleep.childID, sleepID: sleep.id, start: sleep.start, kind: sleep.kind,
      showsFrom: showsFrom.map(date), isShowing: true)
  }
}
