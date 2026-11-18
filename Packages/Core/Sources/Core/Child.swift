import Foundation

/// A child in the family, with a name, a birthdate, and an optional photo.
public struct Child: Identifiable, Hashable, Sendable {
  public let id: UUID
  public var name: String
  public var birthDate: BirthDate
  /// The image data as the family store keeps it, or `nil` for no photo.
  public var photo: Data?

  public init(id: UUID, name: String, birthDate: BirthDate, photo: Data?) {
    self.id = id
    self.name = name
    self.birthDate = birthDate
    self.photo = photo
  }

  /// The first letter of the name, for the avatar of a child without a photo.
  public var initial: String { name.first.map { String($0).uppercased() } ?? "" }
}

/// The rule for a child's name.
public enum ChildName {
  public static let maxLength = 30

  /// The trimmed name, or `nil` when it is empty or longer than `maxLength` characters.
  public static func validated(_ raw: String) -> String? {
    let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, name.count <= maxLength else { return nil }
    return name
  }
}

/// The rule for the child that the home screen shows.
public enum SelectedChild {
  /// The saved child when it exists, else the first child, else `nil`.
  public static func id(saved: Child.ID?, in children: [Child]) -> Child.ID? {
    if let saved, children.contains(where: { $0.id == saved }) { return saved }
    return children.first?.id
  }
}
