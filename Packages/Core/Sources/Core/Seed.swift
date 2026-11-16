import Foundation

/// The data that test mode starts with. `--seed <name>` picks one.
public enum Seed: String, CaseIterable, Sendable {
  /// No children: the app opens "Add your child".
  case none
  /// Mila (selected, no photo) and Noah (a photo that the app draws).
  case family
  /// One child with a name of 30 characters.
  case longName = "long-name"

  /// The children, in the order that test mode adds them.
  public var children: [SeedChild] {
    switch self {
    case .none:
      []
    case .family:
      [
        SeedChild(name: "Mila", birthDate: BirthDate(year: 2025, month: 3, day: 12)!, drawsPhoto: false),
        SeedChild(name: "Noah", birthDate: BirthDate(year: 2022, month: 2, day: 10)!, drawsPhoto: true),
      ]
    case .longName:
      [
        SeedChild(
          name: "Maximiliana Rosalind Pepperpot", birthDate: BirthDate(year: 2025, month: 3, day: 12)!,
          drawsPhoto: false)
      ]
    }
  }

  /// The index in `children` of the selected child.
  public var selectedIndex: Int? { children.isEmpty ? nil : 0 }
}

/// A child of a seed. The data is made up.
public struct SeedChild: Equatable, Sendable {
  public let name: String
  public let birthDate: BirthDate
  /// The app draws a photo for this child, so a screenshot shows a photo. It is not a real photo.
  public let drawsPhoto: Bool
}
