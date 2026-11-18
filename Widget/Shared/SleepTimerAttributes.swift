import ActivityKit
import Core
import Foundation

/// The sleep timer: a Live Activity that counts a running sleep from its start (ADR 0008).
///
/// The sleep id is in the content state, not in the attributes, so a timer can follow the sleep that a merge keeps
/// with an update. An app in the background can update a Live Activity, but cannot request a new one.
struct SleepTimerAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var sleepID: UUID
    var start: Date
    var kind: SleepKind
  }

  var childID: UUID
  var childName: String
  /// The child's position in `FamilyStore.children`, from 0, for the avatar colour.
  var avatarColorIndex: Int
  /// The scheduled start, or `nil` for a timer that started at once.
  var showsFrom: Date?
}
