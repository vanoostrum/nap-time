import ActivityKit
import AppIntents
import Core
import Foundation
import NapTimeStore
import OSLog
import UserNotifications

/// How "Awake" reaches the family store. The app registers one at launch with `AppDependencyManager`. `loaded`
/// waits until the store has loaded, and gives `nil` when it did not load.
struct FamilyStoreAccess: Sendable {
  let loaded: @MainActor @Sendable () async -> FamilyStore?
}

/// "Awake" on the sleep timer: ends the child's sleep without unlocking the phone.
///
/// It is a `LiveActivityIntent`, so iOS runs `perform()` in the app process, also when the app is closed. The
/// widget compiles it too, for `Button(intent:)`.
struct EndSleepIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Awake"
  static let isDiscoverable = false

  @Parameter(title: "Child") var childID: String
  @Parameter(title: "Sleep") var sleepID: String

  @Dependency private var access: FamilyStoreAccess

  init() {}

  init(childID: UUID, sleepID: UUID) {
    self.childID = childID.uuidString
    self.sleepID = sleepID.uuidString
  }

  private static let logger = Logger(subsystem: "nl.clearblocks.naptime", category: "SleepTimer")

  @MainActor
  func perform() async throws -> some IntentResult {
    guard let childID = UUID(uuidString: childID), let sleepID = UUID(uuidString: sleepID) else { return .result() }
    // 1 and 2: end the sleep only when it is the child's running sleep, so "Awake" never ends a newer sleep.
    if let store = await access.loaded(),
      SleepTimerRule.awakeEndsSleep(sleepID: sleepID, childSleeps: store.sleeps(of: childID))
    {
      // A sleep under 1 minute is deleted, as with "Wake up".
      try store.endSleep(childID: childID, at: Date())
    }
    // 3: the backup for the nudges of CRAFT-52.
    let nudge = NudgeID.longSleep(sleepID: sleepID)
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [nudge])
    Self.logger.info("Awake removed the pending notification request \(nudge, privacy: .public)")
    // 4: close the card at once. Another timer of the child stays for the next reconcile.
    await Self.endTimers(of: sleepID)
    return .result()
  }

  /// `Activity` is not Sendable, so the timers are found and ended outside the main actor.
  private nonisolated static func endTimers(of sleepID: UUID) async {
    for activity in Activity<SleepTimerAttributes>.activities where activity.content.state.sleepID == sleepID {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }
}
