import Foundation

/// A calendar date: a year, a month, and a day, in the Gregorian calendar.
///
/// It is not an instant, so a child's age does not move with the time zone.
/// The app also uses it for today's date.
public struct BirthDate: Hashable, Comparable, Sendable, CustomStringConvertible {
  public let year: Int
  public let month: Int
  public let day: Int

  /// `nil` when the date does not exist, such as 29 February 2025.
  public init?(year: Int, month: Int, day: Int) {
    guard (1...12).contains(month), (1...Self.daysIn(year: year, month: month)).contains(day) else { return nil }
    self.year = year
    self.month = month
    self.day = day
  }

  /// The calendar date of an instant, in the time zone of `calendar`.
  public init(_ date: Date, in calendar: Calendar) {
    var gregorian = Calendar(identifier: .gregorian)
    gregorian.timeZone = calendar.timeZone
    let parts = gregorian.dateComponents([.year, .month, .day], from: date)
    self.init(dayNumber: Self.dayNumber(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1))
  }

  /// The start of this date in the time zone of `calendar`.
  public func date(in calendar: Calendar) -> Date {
    var gregorian = Calendar(identifier: .gregorian)
    gregorian.timeZone = calendar.timeZone
    let parts = DateComponents(year: year, month: month, day: day)
    return gregorian.date(from: parts) ?? Date(timeIntervalSince1970: 0)
  }

  /// "12 March 2025".
  public var description: String {
    "\(day) \(Self.monthNames[month - 1]) \(year)"
  }

  public static func < (lhs: BirthDate, rhs: BirthDate) -> Bool {
    (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
  }

  public func adding(days: Int) -> BirthDate {
    BirthDate(dayNumber: dayNumber + days)
  }

  /// The same day `years` earlier, or the last day of the month when that day does not exist.
  public func subtracting(years: Int) -> BirthDate {
    let year = self.year - years
    return BirthDate(uncheckedYear: year, month: month, day: min(day, Self.daysIn(year: year, month: month)))
  }

  /// Days since 1 January 1970.
  var dayNumber: Int { Self.dayNumber(year: year, month: month, day: day) }

  static func daysIn(year: Int, month: Int) -> Int {
    switch month {
    case 2: isLeap(year) ? 29 : 28
    case 4, 6, 9, 11: 30
    default: 31
    }
  }

  private static func isLeap(_ year: Int) -> Bool {
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
  }

  private init(uncheckedYear year: Int, month: Int, day: Int) {
    self.year = year
    self.month = month
    self.day = day
  }

  // The day-number conversions follow Howard Hinnant's days_from_civil and civil_from_days.

  private static func dayNumber(year: Int, month: Int, day: Int) -> Int {
    let y = month <= 2 ? year - 1 : year
    let era = (y >= 0 ? y : y - 399) / 400
    let yearOfEra = y - era * 400
    let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
    let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
    return era * 146_097 + dayOfEra - 719_468
  }

  private init(dayNumber: Int) {
    let z = dayNumber + 719_468
    let era = (z >= 0 ? z : z - 146_096) / 146_097
    let dayOfEra = z - era * 146_097
    let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
    let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
    let mp = (5 * dayOfYear + 2) / 153
    let day = dayOfYear - (153 * mp + 2) / 5 + 1
    let month = mp < 10 ? mp + 3 : mp - 9
    self.init(uncheckedYear: yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month: month, day: day)
  }

  private static let monthNames = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
  ]
}

/// A child's age on a date.
public struct Age: Equatable, Sendable {
  /// Whole days since birth.
  public let days: Int
  /// Whole months since birth. A child reaches a month on the same day of the month,
  /// or on the last day of a shorter month.
  public let months: Int

  public var weeks: Int { days / 7 }
  public var years: Int { months / 12 }

  public init(of birthDate: BirthDate, on today: BirthDate) {
    guard birthDate < today else {
      days = 0
      months = 0
      return
    }
    days = today.dayNumber - birthDate.dayNumber
    var months = (today.year - birthDate.year) * 12 + (today.month - birthDate.month)
    if today.day < min(birthDate.day, BirthDate.daysIn(year: today.year, month: today.month)) {
      months -= 1
    }
    self.months = months
  }

  /// "Mila is 3 days old": days under 1 week, weeks under 1 month, months under 1 year, then years.
  public func sentence(name: String) -> String {
    let count: Int
    let unit: String
    if days < 7 {
      (count, unit) = (days, "day")
    } else if months < 1 {
      (count, unit) = (weeks, "week")
    } else if months < 12 {
      (count, unit) = (months, "month")
    } else {
      (count, unit) = (years, "year")
    }
    return "\(name) is \(count) \(unit)\(count == 1 ? "" : "s") old"
  }
}

/// The dates that the birthdate picker allows: a child from 0 to 6 years old.
public enum BirthDateLimits {
  /// From the day after the date 7 years ago, to today.
  public static func forAdding(today: BirthDate) -> ClosedRange<BirthDate> {
    today.subtracting(years: 7).adding(days: 1)...today
  }

  /// Like `forAdding`, but the earliest date is the saved birthdate when that is earlier,
  /// so a child who turned 7 keeps the saved birthdate.
  public static func forEditing(saved: BirthDate, today: BirthDate) -> ClosedRange<BirthDate> {
    let adding = forAdding(today: today)
    return min(saved, adding.lowerBound)...adding.upperBound
  }
}

/// The hint under the birthdate: the age and the recommended range.
public enum ChildHint {
  /// "Mila is 1 year old. The range is 11–14 h of sleep a day."
  public static func text(name: String, birthDate: BirthDate, today: BirthDate) -> String {
    let age = Age(of: birthDate, on: today).sentence(name: name)
    let range = RecommendedRange(birthDate: birthDate, on: today)
    return "\(age). The range is \(range) of sleep a day."
  }
}
