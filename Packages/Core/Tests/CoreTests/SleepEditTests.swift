import Core
import Foundation
import Testing

@Suite struct SleepEditTests {
  private let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!
  private let mila = UUID()
  private let noah = UUID()
  private let now = date("2026-06-21T10:00:00+02:00")

  // MARK: Under 1 minute

  @Test func aSleepOf59SecondsIsTooShortAnd60SecondsIsNot() {
    let start = date("2026-06-21T09:00:00+02:00")
    #expect(problem(ended(start, start.addingTimeInterval(59))) == .tooShort)
    #expect(problem(ended(start, start.addingTimeInterval(60))) == nil)
  }

  @Test func aWakeUpBeforeTheStartIsTooShort() {
    #expect(problem(ended("2026-06-21T09:00:00+02:00", "2026-06-21T08:00:00+02:00")) == .tooShort)
  }

  // MARK: In the future

  @Test func aWakeUpAtNowSavesAnd1MinuteLaterIsInTheFuture() {
    #expect(problem(ended("2026-06-21T09:00:00+02:00", "2026-06-21T10:00:00+02:00")) == nil)
    #expect(problem(ended("2026-06-21T09:00:00+02:00", "2026-06-21T10:01:00+02:00")) == .inTheFuture)
  }

  @Test func aStartInTheFutureIsInTheFuture() {
    #expect(problem(ended("2026-06-21T10:01:00+02:00", "2026-06-21T10:30:00+02:00")) == .inTheFuture)
  }

  // MARK: Over 24 hours

  @Test func aSleepOf24HoursSavesAnd24Hours1MinuteIsTooLong() {
    #expect(problem(ended("2026-06-20T09:00:00+02:00", "2026-06-21T09:00:00+02:00")) == nil)
    #expect(problem(ended("2026-06-20T09:00:00+02:00", "2026-06-21T09:01:00+02:00")) == .tooLong)
  }

  @Test func aSavedSleepOf25HoursIsRefusedUntilItIsShortenedTo24Hours() {
    let saved = ended("2026-06-20T08:00:00+02:00", "2026-06-21T09:00:00+02:00")
    #expect(problem(saved) == .tooLong)
    var shortened = saved
    shortened.start = date("2026-06-20T09:00:00+02:00")
    #expect(problem(shortened, others: [saved]) == nil)
  }

  // MARK: Order

  @Test func theFirstProblemInTheOrderShows() {
    // Under 1 minute and in the future: under 1 minute shows.
    #expect(problem(ended("2026-06-21T11:00:00+02:00", "2026-06-21T11:00:30+02:00")) == .tooShort)
    // In the future and over 24 hours: in the future shows.
    #expect(problem(ended("2026-06-20T09:00:00+02:00", "2026-06-21T11:00:00+02:00")) == .inTheFuture)
    // Over 24 hours and an overlap: over 24 hours shows.
    let other = ended("2026-06-20T13:00:00+02:00", "2026-06-20T14:00:00+02:00")
    #expect(problem(ended("2026-06-20T08:00:00+02:00", "2026-06-21T09:00:00+02:00"), others: [other]) == .tooLong)
  }

  // MARK: Overlap

  @Test func anOverlapWithAnEndedSleepNamesThatSleep() {
    let lastNight = ended("2026-06-20T19:45:00+02:00", "2026-06-21T06:55:00+02:00", kind: .night)
    let new = ended("2026-06-21T06:30:00+02:00", "2026-06-21T07:30:00+02:00")
    #expect(problem(new, others: [lastNight], now: date("2026-06-21T07:30:00+02:00")) == .overlaps(lastNight))
  }

  @Test func anOverlapWithARunningSleepCountsItUntilNow() {
    let running = Sleep(id: UUID(), childID: mila, start: date("2026-06-21T09:30:00+02:00"), end: nil, kind: .nap)
    #expect(
      problem(ended("2026-06-21T09:00:00+02:00", "2026-06-21T09:31:00+02:00"), others: [running]) == .overlaps(running))
    #expect(problem(ended("2026-06-21T09:00:00+02:00", "2026-06-21T09:30:00+02:00"), others: [running]) == nil)
  }

  @Test func aSleepThatTouchesAnotherEndToStartDoesNotOverlap() {
    let nap = ended("2026-06-21T08:00:00+02:00", "2026-06-21T09:00:00+02:00")
    #expect(problem(ended("2026-06-21T09:00:00+02:00", "2026-06-21T10:00:00+02:00"), others: [nap]) == nil)
    #expect(problem(ended("2026-06-21T07:00:00+02:00", "2026-06-21T08:00:00+02:00"), others: [nap]) == nil)
  }

  @Test func aSleepOfAnotherChildNeverOverlaps() {
    let noahsNap = Sleep(
      id: UUID(), childID: noah, start: date("2026-06-21T08:00:00+02:00"), end: date("2026-06-21T09:30:00+02:00"),
      kind: .nap)
    #expect(problem(ended("2026-06-21T09:00:00+02:00", "2026-06-21T10:00:00+02:00"), others: [noahsNap]) == nil)
  }

  @Test func theEditedSleepNeverOverlapsItself() {
    let saved = ended("2026-06-21T08:00:00+02:00", "2026-06-21T09:00:00+02:00")
    var edited = saved
    edited.end = date("2026-06-21T09:30:00+02:00")
    #expect(problem(edited, others: [saved]) == nil)
  }

  /// Review focus 1: a night that now ends after the next nap starts overlaps that nap.
  @Test func aNightMovedPastTheStartOfTheNextNapOverlapsIt() {
    let night = ended("2026-06-20T19:45:00+02:00", "2026-06-21T06:55:00+02:00", kind: .night)
    let nap = ended("2026-06-21T08:00:00+02:00", "2026-06-21T09:00:00+02:00")
    var edited = night
    edited.end = date("2026-06-21T08:15:00+02:00")
    #expect(problem(edited, others: [night, nap]) == .overlaps(nap))
  }

  // MARK: Running sleep

  @Test func aRunningSleepThatStarted30SecondsAgoSaves() {
    let running = Sleep(id: UUID(), childID: mila, start: now.addingTimeInterval(-30), end: nil, kind: .nap)
    #expect(problem(running) == nil)
  }

  @Test func aRunningSleepOfOver24HoursSaves() {
    let running = Sleep(
      id: UUID(), childID: mila, start: now.addingTimeInterval(-25 * 3600), end: nil, kind: .night)
    #expect(problem(running) == nil)
  }

  @Test func aRunningSleepWithAStartInTheFutureIsInTheFuture() {
    let running = Sleep(id: UUID(), childID: mila, start: now.addingTimeInterval(60), end: nil, kind: .nap)
    #expect(problem(running) == .inTheFuture)
  }

  /// Review focus 3.
  @Test func aRunningStartMovedBackOverThePreviousSleepOverlapsIt() {
    let lastNight = ended("2026-06-20T19:45:00+02:00", "2026-06-21T06:55:00+02:00", kind: .night)
    let running = Sleep(id: UUID(), childID: mila, start: date("2026-06-21T19:42:00+02:00"), end: nil, kind: .night)
    let atNight = date("2026-06-21T21:56:00+02:00")
    var moved = running
    moved.start = date("2026-06-21T06:00:00+02:00")
    #expect(problem(moved, others: [lastNight, running], now: atNight) == .overlaps(lastNight))
    moved.start = date("2026-06-21T06:55:00+02:00")
    #expect(problem(moved, others: [lastNight, running], now: atNight) == nil)
  }

  /// Review focus 2: "Woke earlier?" with a wake-up before the start, or within 1 minute of it.
  @Test func wokeEarlierBeforeOrJustAfterTheStartIsTooShort() {
    let running = Sleep(id: UUID(), childID: mila, start: date("2026-06-21T09:00:00+02:00"), end: nil, kind: .nap)
    var woke = running
    woke.end = date("2026-06-21T08:59:00+02:00")
    #expect(problem(woke, others: [running]) == .tooShort)
    woke.end = date("2026-06-21T09:00:30+02:00")
    #expect(problem(woke, others: [running]) == .tooShort)
    woke.end = date("2026-06-21T09:01:00+02:00")
    #expect(problem(woke, others: [running]) == nil)
  }

  // MARK: Reason texts

  @Test func theReasonTexts() {
    #expect(
      SleepProblem.tooShort.text(childName: "Mila", in: amsterdam)
        == "Wake-up must be at least 1 minute after falling asleep.")
    #expect(SleepProblem.inTheFuture.text(childName: "Mila", in: amsterdam) == "This time is in the future.")
    #expect(SleepProblem.tooLong.text(childName: "Mila", in: amsterdam) == "A sleep can't be longer than 24 hours.")
    let night = ended("2026-06-20T19:45:00+02:00", "2026-06-21T06:55:00+02:00", kind: .night)
    #expect(
      SleepProblem.overlaps(night).text(childName: "Mila", in: amsterdam)
        == "This overlaps Mila's night from 19:45 to 06:55.")
    let nap = Sleep(id: UUID(), childID: mila, start: date("2026-06-21T13:05:00+02:00"), end: nil, kind: .nap)
    #expect(
      SleepProblem.overlaps(nap).text(childName: "Mila", in: amsterdam)
        == "This overlaps Mila's nap from 13:05, still asleep.")
  }

  // MARK: Start values

  @Test(arguments: [
    ("2026-06-21T10:00:00+02:00", "2026-06-21T09:00:00+02:00", "2026-06-21T10:00:00+02:00", SleepKind.nap),
    ("2026-06-21T10:04:59+02:00", "2026-06-21T09:00:00+02:00", "2026-06-21T10:00:00+02:00", .nap),
    ("2026-06-21T07:30:00+02:00", "2026-06-21T06:30:00+02:00", "2026-06-21T07:30:00+02:00", .nap),
    ("2026-06-21T19:12:00+02:00", "2026-06-21T18:10:00+02:00", "2026-06-21T19:10:00+02:00", .night),
  ])
  func startValuesRoundNowDownTo5MinutesAndStart1HourBefore(
    now: String, fellAsleep: String, wokeUp: String, kind: SleepKind
  ) {
    let values = SleepStartValues.today(now: date(now), in: amsterdam)
    #expect(values.fellAsleep == date(fellAsleep))
    #expect(values.wokeUp == date(wokeUp))
    #expect(values.kind == kind)
  }

  // MARK: Times on the form

  @Test func aFormTimeShowsTheDayAndTheTime() {
    #expect(SleepFormTime.text(date("2026-06-20T19:45:00+02:00"), in: amsterdam) == "Sat 20 Jun · 19:45")
    #expect(SleepFormTime.text(date("2026-06-21T09:00:00+02:00"), in: amsterdam) == "Sun 21 Jun · 09:00")
    #expect(SleepFormTime.text(date("2026-11-02T20:54:00+01:00"), in: amsterdam) == "Mon 2 Nov · 20:54")
  }

  // MARK: After a save or a delete

  /// A 17:30 → 18:30 nap is a nap, and counts its full 1 h for the sleep day it starts in (ADR 0006).
  @Test func aNapFrom1730To1830CountsWholeForTheSleepDayItStartsIn() {
    let values = SleepStartValues.today(now: date("2026-06-21T18:30:00+02:00"), in: amsterdam)
    #expect(values.kind == .nap)
    let nap = ended(values.fellAsleep, values.wokeUp, kind: values.kind)
    #expect(problem(nap, now: date("2026-06-21T18:30:00+02:00")) == nil)
    #expect(SleptToday.total(of: [nap], now: date("2026-06-21T20:00:00+02:00"), in: amsterdam) == 3600)
    #expect(SleptToday.total(of: [nap], now: date("2026-06-22T10:00:00+02:00"), in: amsterdam) == 0)
  }

  /// Review focus 5.
  @Test func afterADeleteTheStatusLineFallsBackToThePreviousSleep() {
    let lastNight = ended("2026-06-20T19:45:00+02:00", "2026-06-21T06:55:00+02:00", kind: .night)
    let nap = ended("2026-06-21T08:00:00+02:00", "2026-06-21T09:00:00+02:00")
    #expect(
      ChildStatus(sleeps: [nap, lastNight], now: now, in: amsterdam).line == "since 09:00 · 12 h 10 m slept today")
    #expect(ChildStatus(sleeps: [lastNight], now: now, in: amsterdam).line == "since 06:55 · 11 h 10 m slept today")
    #expect(ChildStatus(sleeps: [], now: now, in: amsterdam).line == "0 m slept today")
  }

  // MARK: Helpers

  private func problem(_ sleep: Sleep, others: [Sleep] = [], now: Date? = nil) -> SleepProblem? {
    SleepSaveRule.problem(of: sleep, among: others, now: now ?? self.now)
  }

  private func ended(_ start: String, _ end: String, kind: SleepKind = .nap) -> Sleep {
    ended(date(start), date(end), kind: kind)
  }

  private func ended(_ start: Date, _ end: Date, kind: SleepKind = .nap) -> Sleep {
    Sleep(id: UUID(), childID: mila, start: start, end: end, kind: kind)
  }
}
