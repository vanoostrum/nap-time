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

  @Test func aRunningNightIsNightAtAnyTime() {
    let instants = [
      "2026-06-21T12:00:00+02:00", "2026-06-21T05:25:00+02:00", "2026-06-21T06:55:00+02:00",
      "2026-06-21T22:05:00+02:00", "2026-12-21T21:00:00+01:00",
    ]
    for instant in instants {
      #expect(SkyPhase(at: date(instant), in: amsterdam, running: .night) == .night)
    }
  }

  @Test func aRunningNapFollowsTheSun() {
    for instant in ["2026-06-21T22:05:00+02:00", "2026-06-21T13:50:00+02:00", "2026-12-21T16:30:00+01:00"] {
      let at = date(instant)
      #expect(SkyPhase(at: at, in: amsterdam, running: .nap) == SkyPhase(at: at, in: amsterdam))
    }
    #expect(SkyPhase(at: date("2026-12-21T16:30:00+01:00"), in: amsterdam, running: .nap) == .sunset)
  }

  /// Review focus 5: at 21:00 in December, a child with no sleep and a child with a running night both see night.
  @Test func nineInTheEveningInDecemberIsNight() {
    let at = date("2026-12-21T21:00:00+01:00")
    #expect(SkyPhase(at: at, in: amsterdam) == .night)
    #expect(SkyPhase(at: at, in: amsterdam, running: .night) == .night)
  }

  /// Review focus 2: a night that runs after sunrise shows night, and the sky after "Wake up" follows the sun.
  @Test func theSkyAfterANightThatRanPastSunrise() {
    let night = Sleep(
      id: UUID(), childID: UUID(), start: date("2026-06-20T19:45:00+02:00"), end: nil, kind: .night)
    let now = date("2026-06-21T06:55:00+02:00")
    #expect(ChildStatus(sleeps: [night], now: now, in: amsterdam).sky == .night)
    var ended = night
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
