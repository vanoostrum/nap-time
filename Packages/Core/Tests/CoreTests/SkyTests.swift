import Core
import Foundation
import Testing

@Suite struct SkyTests {
  private let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!

  // MARK: Sun times

  /// The reference sun times of Utrecht in Europe/Amsterdam, from the spec.
  @Test(arguments: [
    (day(2026, 6, 21), "2026-06-21T05:19:00+02:00", "2026-06-21T22:04:00+02:00"),
    (day(2026, 11, 15), "2026-11-15T08:00:00+01:00", "2026-11-15T16:48:00+01:00"),
    (day(2026, 12, 21), "2026-12-21T08:46:00+01:00", "2026-12-21T16:29:00+01:00"),
    (day(2026, 3, 29), "2026-03-29T07:22:00+02:00", "2026-03-29T20:08:00+02:00"),
    (day(2026, 10, 25), "2026-10-25T07:22:00+01:00", "2026-10-25T17:24:00+01:00"),
  ])
  func sunTimesOfUtrechtAreWithinTwoMinutes(on: BirthDate, sunrise: String, sunset: String) {
    let sun = SunTimes(on: on)
    #expect(abs(sun.sunrise.timeIntervalSince(date(sunrise))) <= 120)
    #expect(abs(sun.sunset.timeIntervalSince(date(sunset))) <= 120)
  }

  @Test func sunTimesUseUtrecht() {
    #expect(Coordinate.utrecht == Coordinate(latitude: 52.0907, longitude: 5.1214))
    #expect(SunTimes(on: day(2026, 6, 21)) == SunTimes(on: day(2026, 6, 21), at: .utrecht))
  }

  // MARK: Phase edges

  /// Each edge from the sun times, not hard-coded: the edge itself starts the new phase,
  /// and 1 second before it the old phase still shows.
  @Test(arguments: [day(2026, 6, 21), day(2026, 11, 15), day(2026, 12, 21), day(2026, 3, 29), day(2026, 10, 25)])
  func eachEdgeStartsItsPhase(on: BirthDate) {
    let sun = SunTimes(on: on)
    let half: TimeInterval = 30 * 60
    let edges: [(Date, before: SkyPhase, at: SkyPhase)] = [
      (sun.sunrise - half, .night, .sunrise),
      (sun.sunrise + half, .sunrise, .day),
      (sun.sunset - half, .day, .sunset),
      (sun.sunset + half, .sunset, .night),
    ]
    for edge in edges {
      #expect(SkyPhase(at: edge.0 - 1, in: amsterdam) == edge.before)
      #expect(SkyPhase(at: edge.0, in: amsterdam) == edge.at)
    }
  }

  @Test func theSkyAtTheTimesOfTheEntryPoints() {
    #expect(SkyPhase(at: date("2026-06-21T10:00:00+02:00"), in: amsterdam) == .day)
    #expect(SkyPhase(at: date("2026-06-21T22:05:00+02:00"), in: amsterdam) == .sunset)
    #expect(SkyPhase(at: date("2026-06-21T23:30:00+02:00"), in: amsterdam) == .night)
    #expect(SkyPhase(at: date("2026-11-15T08:00:00+01:00"), in: amsterdam) == .sunrise)
    #expect(SkyPhase(at: date("2026-06-21T21:56:00+02:00"), in: amsterdam) == .sunset)
  }

  /// Review focus 3: just after midnight, the sky comes from the sunrise of the new date.
  @Test func justAfterMidnightIsNight() {
    #expect(SkyPhase(at: date("2026-06-22T00:30:00+02:00"), in: amsterdam) == .night)
  }

  /// Review focus 1: on the days the clock changes, the sun times are in the new local time.
  @Test func clockChangeDays() {
    #expect(SkyPhase(at: date("2026-03-29T03:01:00+02:00"), in: amsterdam) == .night)
    #expect(SkyPhase(at: date("2026-03-29T07:22:00+02:00"), in: amsterdam) == .sunrise)
    #expect(SkyPhase(at: date("2026-03-29T08:00:00+02:00"), in: amsterdam) == .day)
    #expect(SkyPhase(at: date("2026-03-29T20:08:00+02:00"), in: amsterdam) == .sunset)
    #expect(SkyPhase(at: date("2026-10-25T02:30:00+01:00"), in: amsterdam) == .night)
    #expect(SkyPhase(at: date("2026-10-25T03:01:00+01:00"), in: amsterdam) == .night)
    #expect(SkyPhase(at: date("2026-10-25T07:22:00+01:00"), in: amsterdam) == .sunrise)
    #expect(SkyPhase(at: date("2026-10-25T17:24:00+01:00"), in: amsterdam) == .sunset)
  }

  // MARK: Running sleeps

  private func night(from start: String) -> Sleep {
    Sleep(id: UUID(), childID: UUID(), start: date(start), end: nil, kind: .night)
  }

  private func sky(_ sleeps: [Sleep], at instant: String) -> SkyPhase {
    ChildStatus(sleeps: sleeps, now: date(instant), in: amsterdam).sky
  }

  /// Criterion 1, review focus 1 and 4: a night that started the evening before shows sunrise at sunrise,
  /// also on the mornings the clock changes.
  @Test(arguments: [
    ("2026-11-14T19:48:00+01:00", "2026-11-15T08:00:00+01:00"),
    ("2026-03-28T19:45:00+01:00", "2026-03-29T07:22:00+02:00"),
    ("2026-10-24T19:45:00+02:00", "2026-10-25T07:22:00+01:00"),
  ])
  func aRunningNightShowsSunriseAtSunrise(start: String, now: String) {
    #expect(sky([night(from: start)], at: now) == .sunrise)
  }

  /// Criterion 2, review focus 2: after sunrise plus 30 minutes, a running night shows the day sky.
  @Test func aRunningNightShowsDayAfterSunrise() {
    #expect(sky([night(from: "2026-11-14T19:48:00+01:00")], at: "2026-11-15T09:00:00+01:00") == .day)
  }

  /// Criterion 3, review focus 3: in the evening and the night, a running night shows sunset, then night.
  @Test(arguments: [
    ("2026-06-21T19:42:00+02:00", "2026-06-21T21:56:00+02:00", SkyPhase.sunset),
    ("2026-06-21T19:42:00+02:00", "2026-06-21T23:30:00+02:00", .night),
    ("2026-06-21T19:42:00+02:00", "2026-06-22T03:00:00+02:00", .night),
    ("2026-12-21T19:30:00+01:00", "2026-12-21T21:00:00+01:00", .night),
  ])
  func aRunningNightInTheEveningAndTheNight(start: String, now: String, expected: SkyPhase) {
    #expect(sky([night(from: start)], at: now) == expected)
  }

  /// Criterion 4, review focus 5: a running night, a running nap, and no running sleep show the same sky,
  /// the sky of the sun at `now`.
  @Test func theSkyIsTheSameWithAndWithoutARunningSleep() {
    var instant = date("2026-03-28T00:10:00+01:00")
    let end = date("2026-03-30T00:00:00+02:00")
    let start = date("2026-03-27T19:00:00+01:00")
    let nap = Sleep(id: UUID(), childID: UUID(), start: start, end: nil, kind: .nap)
    let night = Sleep(id: UUID(), childID: UUID(), start: start, end: nil, kind: .night)
    while instant < end {
      let sun = SkyPhase(at: instant, in: amsterdam)
      #expect(ChildStatus(sleeps: [night], now: instant, in: amsterdam).sky == sun)
      #expect(ChildStatus(sleeps: [nap], now: instant, in: amsterdam).sky == sun)
      #expect(ChildStatus(sleeps: [], now: instant, in: amsterdam).sky == sun)
      instant += 10 * 60
    }
  }

  @Test func aRunningNapFollowsTheSun() {
    let nap = Sleep(
      id: UUID(), childID: UUID(), start: date("2026-12-21T16:00:00+01:00"), end: nil, kind: .nap)
    #expect(sky([nap], at: "2026-12-21T16:30:00+01:00") == .sunset)
  }

  /// At 21:00 in December, a child with no sleep and a child with a running night both see night.
  @Test func nineInTheEveningInDecemberIsNight() {
    #expect(sky([], at: "2026-12-21T21:00:00+01:00") == .night)
    #expect(sky([night(from: "2026-12-21T19:30:00+01:00")], at: "2026-12-21T21:00:00+01:00") == .night)
  }

  /// A night that runs after sunrise shows the day sky, and "Wake up" does not change the sky.
  @Test func theSkyAfterANightThatRanPastSunrise() {
    let running = night(from: "2026-06-20T19:45:00+02:00")
    let now = date("2026-06-21T06:55:00+02:00")
    #expect(ChildStatus(sleeps: [running], now: now, in: amsterdam).sky == .day)
    var ended = running
    ended.end = now
    #expect(ChildStatus(sleeps: [ended], now: now, in: amsterdam).sky == .day)
    #expect(ChildStatus(sleeps: [ended], now: date("2026-06-21T05:30:00+02:00"), in: amsterdam).sky == .sunrise)
  }

  // MARK: Next change

  @Test func nextChangeIsTheNextEdge() {
    let june21 = SunTimes(on: day(2026, 6, 21))
    let june22 = SunTimes(on: day(2026, 6, 22))
    let half: TimeInterval = 30 * 60
    #expect(SkyPhase.nextChange(after: date("2026-06-21T21:00:00+02:00"), in: amsterdam) == june21.sunset - half)
    #expect(SkyPhase.nextChange(after: june21.sunset - half, in: amsterdam) == june21.sunset + half)
    #expect(SkyPhase.nextChange(after: date("2026-06-21T23:00:00+02:00"), in: amsterdam) == june22.sunrise - half)
    #expect(SkyPhase.nextChange(after: date("2026-06-21T03:00:00+02:00"), in: amsterdam) == june21.sunrise - half)
  }

  /// The phase stays the same until the next change, and changes there.
  @Test func thePhaseChangesAtTheNextChange() {
    var instant = date("2026-03-28T12:00:00+01:00")
    for _ in 0..<12 {
      let next = SkyPhase.nextChange(after: instant, in: amsterdam)
      #expect(SkyPhase(at: next - 1, in: amsterdam) == SkyPhase(at: instant, in: amsterdam))
      #expect(SkyPhase(at: next, in: amsterdam) != SkyPhase(at: instant, in: amsterdam))
      instant = next
    }
  }
}
