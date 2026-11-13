import Foundation

/// A launch argument with a value that the app cannot use.
public struct LaunchArgumentError: Error, Equatable, CustomStringConvertible {
  /// The argument, such as `--now`.
  public var argument: String
  /// The value given, or `nil` when the value is missing.
  public var value: String?

  public init(argument: String, value: String?) {
    self.argument = argument
    self.value = value
  }

  public var description: String {
    "Bad value for launch argument \(argument): \(value.map { "'\($0)'" } ?? "missing")"
  }
}

/// Reads the app's launch arguments.
///
/// - `--test-mode` starts test mode.
/// - `--now <ISO 8601 date with a UTC offset>` replaces the fixed clock in test mode.
/// - `--location <latitude>,<longitude>` replaces the fixed location in test mode.
///
/// Without `--test-mode`, `--now` and `--location` are ignored and not checked.
public enum LaunchArguments {
  public static let testMode = "--test-mode"
  public static let now = "--now"
  public static let location = "--location"

  public static func parse(_ arguments: [String]) throws(LaunchArgumentError) -> AppMode {
    guard arguments.contains(testMode) else { return .normal }

    var environment = TestEnvironment.standard
    if let raw = try value(of: now, in: arguments) {
      guard let date = parseDate(raw) else { throw LaunchArgumentError(argument: now, value: raw) }
      environment.now = date
    }
    if let raw = try value(of: location, in: arguments) {
      guard let coordinate = parseCoordinate(raw) else {
        throw LaunchArgumentError(argument: location, value: raw)
      }
      environment.location = coordinate
    }
    return .test(environment)
  }

  private static func value(of argument: String, in arguments: [String]) throws(LaunchArgumentError) -> String? {
    guard let index = arguments.lastIndex(of: argument) else { return nil }
    let next = arguments.index(after: index)
    guard next < arguments.endIndex, !arguments[next].hasPrefix("--") else {
      throw LaunchArgumentError(argument: argument, value: nil)
    }
    return arguments[next]
  }

  /// An ISO 8601 date and time that must hold a UTC offset, such as `2026-06-21T22:15:00+02:00` or `...Z`.
  private static func parseDate(_ raw: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: raw) { return date }
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: raw)
  }

  private static func parseCoordinate(_ raw: String) -> Coordinate? {
    let parts = raw.split(separator: ",", omittingEmptySubsequences: false)
    guard parts.count == 2,
      let latitude = Double(parts[0].trimmingCharacters(in: .whitespaces)),
      let longitude = Double(parts[1].trimmingCharacters(in: .whitespaces)),
      (-90.0...90.0).contains(latitude),
      (-180.0...180.0).contains(longitude)
    else { return nil }
    return Coordinate(latitude: latitude, longitude: longitude)
  }
}
