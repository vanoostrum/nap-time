import Foundation

/// A point on Earth, in degrees.
public struct Coordinate: Equatable, Sendable {
  public var latitude: Double
  public var longitude: Double

  public init(latitude: Double, longitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
  }

  /// The sky uses the sun times of Utrecht (ADR 0007).
  public static let utrecht = Coordinate(latitude: 52.0907, longitude: 5.1214)
}

/// The sunrise and the sunset of one date, from the NOAA solar calculator equations with the standard zenith of 90.833°.
public struct SunTimes: Equatable, Sendable {
  public let sunrise: Date
  public let sunset: Date

  /// The sun times of Utrecht, or of `coordinate`, on the calendar date `date`.
  ///
  /// The equations count from midnight UTC of `date`. For the Netherlands, the sunrise and
  /// the sunset fall on the same date in UTC and in local time, also on the days the clock changes.
  public init(on date: BirthDate, at coordinate: Coordinate = .utrecht) {
    let midnight = Double(date.dayNumber) * 86_400
    sunrise = Date(timeIntervalSince1970: midnight + Self.minutes(.rise, midnight: midnight, at: coordinate) * 60)
    sunset = Date(timeIntervalSince1970: midnight + Self.minutes(.set, midnight: midnight, at: coordinate) * 60)
  }

  private enum Event: Double {
    case rise = -1
    case set = 1
  }

  /// Minutes after midnight UTC. The sun's position is taken at the time of the event, so the
  /// estimate starts at noon and is refined three times.
  private static func minutes(_ event: Event, midnight: TimeInterval, at coordinate: Coordinate) -> Double {
    var minutes = 720.0
    for _ in 0..<3 {
      let sun = SolarPosition(at: midnight + minutes * 60)
      let latitude = radians(coordinate.latitude)
      let cosHourAngle =
        cos(radians(90.833)) / (cos(latitude) * cos(sun.declination)) - tan(latitude) * tan(sun.declination)
      let hourAngle = degrees(acos(min(1, max(-1, cosHourAngle))))
      minutes = 720 - 4 * coordinate.longitude - sun.equationOfTime + event.rawValue * 4 * hourAngle
    }
    return minutes
  }
}

/// The sun's declination (radians) and the equation of time (minutes) at an instant, as in the NOAA solar calculator.
private struct SolarPosition {
  let declination: Double
  let equationOfTime: Double

  init(at secondsSince1970: TimeInterval) {
    let julianDay = secondsSince1970 / 86_400 + 2_440_587.5
    let t = (julianDay - 2_451_545) / 36_525
    let meanLongitude = (280.46646 + t * (36_000.76983 + t * 0.000_303_2)).truncatingRemainder(dividingBy: 360)
    let meanAnomaly = radians(357.52911 + t * (35_999.05029 - 0.000_153_7 * t))
    let eccentricity = 0.016_708_634 - t * (0.000_042_037 + 0.000_000_126_7 * t)
    let center =
      sin(meanAnomaly) * (1.914602 - t * (0.004817 + 0.000014 * t)) + sin(2 * meanAnomaly) * (0.019993 - 0.000101 * t)
      + sin(3 * meanAnomaly) * 0.000289
    let omega = radians(125.04 - 1934.136 * t)
    let apparentLongitude = radians(meanLongitude + center - 0.00569 - 0.00478 * sin(omega))
    let meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
    let obliquity = radians(meanObliquity + 0.00256 * cos(omega))
    declination = asin(sin(obliquity) * sin(apparentLongitude))
    let y = pow(tan(obliquity / 2), 2)
    let l0 = radians(meanLongitude)
    equationOfTime =
      4
      * degrees(
        y * sin(2 * l0) - 2 * eccentricity * sin(meanAnomaly) + 4 * eccentricity * y * sin(meanAnomaly) * cos(2 * l0)
          - 0.5 * y * y * sin(4 * l0) - 1.25 * eccentricity * eccentricity * sin(2 * meanAnomaly))
  }
}

private func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
private func degrees(_ radians: Double) -> Double { radians * 180 / .pi }

/// The sky behind the home screen. The UI tests read it as the sky's accessibility value.
///
/// Sunrise and sunset each last from 30 minutes before to 30 minutes after the sun time.
/// Each phase starts inclusive and ends exclusive.
public enum SkyPhase: String, CaseIterable, Sendable {
  case day
  case sunset
  case night
  case sunrise

  /// How long before and after the sun time sunrise and sunset last.
  public static let halfWidth: TimeInterval = 30 * 60

  /// The sky at `instant` in `timeZone`, from the sun times of Utrecht. A running sleep does not change it.
  public init(at instant: Date, in timeZone: TimeZone) {
    let sun = SunTimes(on: BirthDate(instant, in: Calendar.gregorian(in: timeZone)))
    self =
      switch instant {
      case ..<sun.sunrise.addingTimeInterval(-Self.halfWidth): .night
      case ..<sun.sunrise.addingTimeInterval(Self.halfWidth): .sunrise
      case ..<sun.sunset.addingTimeInterval(-Self.halfWidth): .day
      case ..<sun.sunset.addingTimeInterval(Self.halfWidth): .sunset
      default: .night
      }
  }

  /// The first phase edge after `instant` in `timeZone`:
  /// sunrise or sunset, minus or plus 30 minutes.
  public static func nextChange(after instant: Date, in timeZone: TimeZone) -> Date {
    let today = BirthDate(instant, in: Calendar.gregorian(in: timeZone))
    let edges = [today, today.adding(days: 1)].flatMap { date in
      let sun = SunTimes(on: date)
      return [sun.sunrise, sun.sunset].flatMap { [$0 - halfWidth, $0 + halfWidth] }
    }
    return edges.filter { $0 > instant }.min()!
  }
}
