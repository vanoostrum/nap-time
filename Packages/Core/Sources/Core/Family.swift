import Foundation

/// How this phone shares the family (ADR 0005).
public enum FamilySharing: Hashable, Sendable {
  /// No share, or a share with no participant but the owner, such as after a cancelled share sheet.
  case notShared
  /// This phone owns the share, and the partner has not opened the link yet.
  case invited
  /// This phone owns the share, and the partner joined.
  case shared(partner: String)
  /// This phone joined the family of the owner.
  case joined(owner: String)
  /// The phone has no available iCloud account.
  case noICloud

  /// The name that the texts use when a participant gives no given name.
  public static let unnamed = "your partner"

  /// The state that the facts of the shares and the iCloud account give.
  public init(_ facts: ShareFacts) {
    guard facts.hasICloudAccount else {
      self = .noICloud
      return
    }
    guard let share = facts.share else {
      self = .notShared
      return
    }
    guard share.isOwnedByMe else {
      self = .joined(owner: share.ownerGivenName ?? Self.unnamed)
      return
    }
    if let partner = share.participants.first(where: \.accepted) {
      self = .shared(partner: partner.givenName ?? Self.unnamed)
    } else if share.participants.isEmpty {
      self = .notShared
    } else {
      self = .invited
    }
  }

  /// The first line of the share card in Settings.
  public var settingsTitle: String {
    switch self {
    case .notShared, .noICloud: "Not shared yet"
    case .invited: "Invite sent"
    case .shared(let partner): "Shared with \(partner)"
    case .joined(let owner): "Shared with you by \(owner)"
    }
  }

  /// The second line of the share card in Settings.
  public var settingsText: String {
    switch self {
    case .notShared: "Your partner sees and logs the same children and sleeps."
    case .invited: "Waiting for your partner to open the link."
    case .shared, .joined: "You both see and log the same children and sleeps."
    case .noICloud: "Sign in to iCloud in the iPhone Settings to share with your partner."
    }
  }

  /// The button under the share card, or `nil` for none.
  public var settingsButton: SettingsShareButton? {
    switch self {
    case .notShared: .invite
    case .invited, .shared, .joined: .manage
    case .noICloud: nil
    }
  }

  /// The phone joined the family of someone else.
  public var isJoined: Bool {
    if case .joined = self { true } else { false }
  }
}

/// The button under the share card in Settings.
public enum SettingsShareButton: Hashable, Sendable {
  /// "Invite your partner": makes the family share and opens the iCloud sharing sheet.
  case invite
  /// "Manage sharing": opens the iCloud sharing sheet for the existing share.
  case manage

  public var title: String {
    switch self {
    case .invite: "Invite your partner"
    case .manage: "Manage sharing"
    }
  }

  /// The alert when the iCloud sharing sheet cannot open.
  public var failureTitle: String {
    switch self {
    case .invite: "Could not start the invite"
    case .manage: "Could not open sharing"
    }
  }

  public static let failureText = "Check your connection and try again."
}

/// The facts of the family share and the iCloud account, as CloudKit gives them.
public struct ShareFacts: Hashable, Sendable {
  public var hasICloudAccount: Bool
  /// The family share in either store, or `nil` for none.
  public var share: Share?

  public init(hasICloudAccount: Bool, share: Share?) {
    self.hasICloudAccount = hasICloudAccount
    self.share = share
  }

  public struct Share: Hashable, Sendable {
    /// This phone's iCloud account owns the share.
    public var isOwnedByMe: Bool
    public var ownerGivenName: String?
    /// The participants other than the owner.
    public var participants: [Participant]

    public init(isOwnedByMe: Bool, ownerGivenName: String?, participants: [Participant]) {
      self.isOwnedByMe = isOwnedByMe
      self.ownerGivenName = ownerGivenName
      self.participants = participants
    }
  }

  public struct Participant: Hashable, Sendable {
    /// The participant opened the link and joined.
    public var accepted: Bool
    public var givenName: String?

    public init(accepted: Bool, givenName: String?) {
      self.accepted = accepted
      self.givenName = givenName
    }
  }
}

/// What the app does with an opened invite link.
public enum InviteRule {
  public enum Decision: Hashable, Sendable {
    /// The owner opened their own link: nothing happens.
    case ignore
    /// The phone is already in a family: the app shows the refusal alert.
    case refuse
    /// The app joins the family.
    case accept
  }

  /// One family per phone: a phone that is `joined`, `shared`, or `invited` refuses another family's invite.
  public static func decision(isOwnLink: Bool, sharing: FamilySharing) -> Decision {
    if isOwnLink { return .ignore }
    switch sharing {
    case .joined, .shared, .invited: return .refuse
    case .notShared, .noICloud: return .accept
    }
  }

  public static let refusalTitle = "You are already in a family"
  public static let refusalText =
    "Nap Time holds one family per phone. Leave or stop sharing in Settings, under Manage sharing, first."

  /// The alert when the app cannot join the family.
  public static let failedJoinTitle = "Could not join the family"
  public static let failedJoinText = "Check your connection and try again."
}

/// The join screen that shows before the home screen and before "Add your child".
public enum JoinScreen: Hashable, Sendable {
  /// "Joining the family…".
  case joining
  /// "You joined the family".
  case joined

  /// `acceptRunning`: the app is accepting a share. `pendingJoin`: the app accepted a share and the partner has not
  /// tapped "Start" yet. `sharedChildCount`: the children in the shared store; a child only on this phone does not
  /// count. Gives `nil` for no join screen.
  public init?(acceptRunning: Bool, pendingJoin: Bool, sharedChildCount: Int) {
    if acceptRunning {
      self = .joining
    } else if !pendingJoin {
      return nil
    } else {
      self = sharedChildCount == 0 ? .joining : .joined
    }
  }

  public var title: String {
    switch self {
    case .joining: "Joining the family…"
    case .joined: JoinedText.title
    }
  }

  public static let joiningText = "This takes a few seconds."
}

/// The texts of "You joined the family".
public enum JoinedText {
  public static let title = "You joined the family"

  /// "You now see and log Mila and Noah, together with your partner.", with the names in the order they were added.
  public static func text(names: [String]) -> String {
    "You now see and log \(list(names)), together with your partner."
  }

  /// "Mila", "Mila and Noah", "Mila, Noah, and Lou".
  private static func list(_ names: [String]) -> String {
    switch names.count {
    case 0: ""
    case 1: names[0]
    case 2: "\(names[0]) and \(names[1])"
    default: "\(names.dropLast().joined(separator: ", ")), and \(names[names.count - 1])"
    }
  }
}

/// The second line of a child's row in Settings.
public enum ChildRow {
  /// "1 year · 11–14 h": the age, as the age text of "Add a child" gives it, and the recommended range.
  public static func text(birthDate: BirthDate, today: BirthDate) -> String {
    "\(Age(of: birthDate, on: today).text) · \(RecommendedRange(birthDate: birthDate, on: today))"
  }
}

/// The texts of the delete confirmations.
public enum DeleteText {
  /// "This deletes Mila and all of Mila's sleeps, on both phones. You cannot undo this.", or "…, on this phone. …"
  /// for a child only on this phone.
  public static func child(name: String, onlyOnThisPhone: Bool) -> String {
    "This deletes \(name) and all of \(name)'s sleeps, \(place(onlyOnThisPhone)). You cannot undo this."
  }

  /// "This deletes Mila's night from 19:45 to 06:55, on both phones. You cannot undo this.", or "…, on this phone. …"
  /// for a sleep of a child only on this phone. A running sleep ends at `now`.
  public static func sleep(
    _ sleep: Sleep, name: String, onlyOnThisPhone: Bool, now: Date, in timeZone: TimeZone
  ) -> String {
    let range = "\(ClockTime.text(sleep.start, in: timeZone)) to \(ClockTime.text(sleep.end ?? now, in: timeZone))"
    return
      "This deletes \(name)'s \(sleep.kind.rawValue) from \(range), \(place(onlyOnThisPhone)). You cannot undo this."
  }

  private static func place(_ onlyOnThisPhone: Bool) -> String {
    onlyOnThisPhone ? "on this phone" : "on both phones"
  }
}

/// The rule that merges overlapping sleeps of one child, which two phones can log before they sync (ADR 0005).
public enum SleepMerge {
  /// One group of overlapping sleeps: the sleep to keep, with its new times, and the sleeps to delete.
  public struct Merge: Hashable, Sendable {
    public let kept: Sleep
    public let deleted: [Sleep.ID]

    public init(kept: Sleep, deleted: [Sleep.ID]) {
      self.kept = kept
      self.deleted = deleted
    }
  }

  /// The merges for `sleeps`, which can be of several children.
  ///
  /// Sleeps of one child that overlap, directly or through another sleep, form one group. A running sleep counts as
  /// open-ended. Sleeps that only touch do not overlap. Each group keeps the sleep that started first, with the
  /// lowest id on a tie, so both phones keep the same sleep. The kept sleep starts at the earliest start and keeps its
  /// kind. It ends at the latest end of the ended sleeps in the group, and it runs only when every sleep in the group
  /// runs. The merges are in the order of the kept sleeps' starts; the deleted ids are in the order of their starts.
  public static func merges(of sleeps: [Sleep]) -> [Merge] {
    let ordered = sleeps.sorted { a, b in
      a.start != b.start ? a.start < b.start : a.id.uuidString < b.id.uuidString
    }
    var merges: [Merge] = []
    for childID in orderedUnique(ordered.map(\.childID)) {
      var group: [Sleep] = []
      // The end of the group so far; `nil` while the group holds a running sleep.
      var groupEnd: Date?
      for sleep in ordered where sleep.childID == childID {
        if !group.isEmpty, groupEnd.map({ sleep.start < $0 }) ?? true {
          group.append(sleep)
          if let end = groupEnd, let sleepEnd = sleep.end {
            groupEnd = max(end, sleepEnd)
          } else {
            groupEnd = nil
          }
        } else {
          if let merge = merge(group) { merges.append(merge) }
          group = [sleep]
          groupEnd = sleep.end
        }
      }
      if let merge = merge(group) { merges.append(merge) }
    }
    return merges.sorted { $0.kept.start < $1.kept.start }
  }

  private static func merge(_ group: [Sleep]) -> Merge? {
    guard group.count > 1, var kept = group.first else { return nil }
    kept.end = group.compactMap(\.end).max()
    return Merge(kept: kept, deleted: group.dropFirst().map(\.id))
  }

  private static func orderedUnique(_ ids: [UUID]) -> [UUID] {
    var seen = Set<UUID>()
    return ids.filter { seen.insert($0).inserted }
  }
}
