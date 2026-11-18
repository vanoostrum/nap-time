import Foundation

/// The total hours of sleep per sleep day, naps included, that the guidelines recommend for a child's age.
///
/// Under 4 months 14–17 h (National Sleep Foundation); then AASM: 4 months to the 1st birthday 12–16 h,
/// the 1st to the 3rd birthday 11–14 h, the 3rd to the 6th birthday 10–13 h, and from the 6th birthday 9–12 h,
/// also after the 7th. A child moves to the next range on the day the child reaches that age.
public struct RecommendedRange: Equatable, Sendable, CustomStringConvertible {
  public let lowerHours: Int
  public let upperHours: Int

  public init(birthDate: BirthDate, on today: BirthDate) {
    let months = Age(of: birthDate, on: today).months
    (lowerHours, upperHours) =
      switch months {
      case ..<4: (14, 17)
      case ..<12: (12, 16)
      case ..<36: (11, 14)
      case ..<72: (10, 13)
      default: (9, 12)
      }
  }

  /// "11–14 h".
  public var description: String { "\(lowerHours)–\(upperHours) h" }
}
