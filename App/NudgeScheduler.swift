import Core
import Foundation
import NapTimeStore
import OSLog
import UserNotifications

/// Plans the nudges on this phone: it asks for permission, makes the pending notifications match Core
/// `NudgeSchedule`, and opens the tapped nudge's child.
///
/// `AppModel` creates it at launch, outside a view, and plans at launch, when the app becomes active, after each save
/// of the family store (`FamilyStore.onSave`), and on each remote change. Test mode plans nothing and never asks for
/// permission: with `AppMode.areNotificationsEnabled` false, every method does nothing.
@MainActor
final class NudgeScheduler: NSObject {
  private let isEnabled: Bool
  /// Set when the family store has loaded.
  var store: FamilyStore?
  private var isPlanQueued = false
  private var lastPlan: Task<Void, Never>?

  private nonisolated static let logger = Logger(subsystem: "nl.clearblocks.naptime", category: "Nudges")
  private nonisolated static let childIDKey = "childID"

  init(mode: AppMode) {
    isEnabled = mode.areNotificationsEnabled
    super.init()
    // Before launch finishes, so the tap that launched the app reaches the delegate.
    if isEnabled {
      UNUserNotificationCenter.current().delegate = self
    }
  }

  /// "Sleep time" and saving a sleep: shows the iPhone's prompt the first time, then plans when the parent allows.
  func requestPermission() {
    guard isEnabled else { return }
    Task {
      if await Self.requestAuthorization() { plan() }
    }
  }

  /// Makes the pending nudges match the store. Triggers that come close together run one plan, and plans run one
  /// after another.
  func plan() {
    guard isEnabled, store != nil, !isPlanQueued else { return }
    isPlanQueued = true
    let previous = lastPlan
    lastPlan = Task {
      await previous?.value
      isPlanQueued = false
      guard let store else { return }
      let nudges = NudgeSchedule.nudges(
        children: store.children, sleeps: store.sleeps, now: Date(), timeZone: .current)
      let pending = await Self.apply(nudges)
      Self.logger.info("Pending nudges: \(pending.joined(separator: ", "), privacy: .public)")
    }
  }

  /// The tap on a nudge: the home screen on the nudge's child.
  private func open(childID: Child.ID) {
    AppModel.shared.select(childID)
    AppModel.shared.tab = .today
  }

  // UserNotifications types are not Sendable, so these use them off the main actor and return Sendable values.

  private nonisolated static func requestAuthorization() async -> Bool {
    do {
      return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    } catch {
      logger.error("The notification prompt failed: \(String(describing: error), privacy: .public)")
      return false
    }
  }

  /// Applies `NudgeSync` when the parent allows notifications, and returns the pending ids after it.
  /// Without permission it adds nothing and shows no error.
  private nonisolated static func apply(_ nudges: [Nudge]) async -> [String] {
    let center = UNUserNotificationCenter.current()
    let status = await center.notificationSettings().authorizationStatus
    guard status == .authorized || status == .provisional || status == .ephemeral else { return [] }
    let sync = NudgeSync(pendingIDs: await center.pendingNotificationRequests().map(\.identifier), nudges: nudges)
    center.removePendingNotificationRequests(withIdentifiers: sync.idsToRemove)
    for nudge in sync.nudgesToAdd {
      do {
        try await center.add(request(for: nudge))
      } catch {
        logger.error("A nudge was not added: \(String(describing: error), privacy: .public)")
      }
    }
    return await center.pendingNotificationRequests().map(\.identifier).sorted()
  }

  private nonisolated static func request(for nudge: Nudge) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = nudge.title
    content.body = nudge.body
    content.sound = .default
    content.userInfo = [childIDKey: nudge.childID.uuidString]
    // The fire date is an instant: Core already chose the wall-clock time, also across a clock change.
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: max(1, nudge.fireDate.timeIntervalSinceNow), repeats: false)
    return UNNotificationRequest(identifier: nudge.id, content: content, trigger: trigger)
  }
}

extension NudgeScheduler: UNUserNotificationCenterDelegate {
  /// While the app is open, a nudge shows as a banner with sound.
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound]
  }

  /// A nudge for a deleted child opens the home screen as it is.
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    let userInfo = response.notification.request.content.userInfo
    guard let text = userInfo[Self.childIDKey] as? String, let childID = UUID(uuidString: text) else { return }
    await open(childID: childID)
  }
}
