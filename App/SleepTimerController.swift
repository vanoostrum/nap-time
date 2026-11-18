import ActivityKit
import Core
import CoreData
import Foundation
import NapTimeStore
import OSLog
import UIKit

/// Requests, schedules, updates, and ends the sleep timers on this phone (ADR 0008).
///
/// The app creates it at launch, outside a view. It reconciles at launch, when the app becomes active, after each
/// save of the family store (`FamilyStore.onSave`), and on each remote change. Test mode requests no Live Activity:
/// with `AppMode.areLiveActivitiesEnabled` false, every method does nothing.
@MainActor
final class SleepTimerController {
  private let store: FamilyStore
  private let isEnabled: Bool
  private var observers: [any NSObjectProtocol] = []

  private static let logger = Logger(subsystem: "nl.clearblocks.naptime", category: "SleepTimer")
  /// The silent sound of a scheduled start, in the app bundle: Theo wants no sound at 04:00.
  static let silence = "Silence.caf"

  init(store: FamilyStore, mode: AppMode) {
    self.store = store
    self.isEnabled = mode.areLiveActivitiesEnabled
  }

  /// Starts the triggers, and reconciles once for the launch.
  func start() {
    guard isEnabled else { return }
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) {
        [weak self] _ in
        MainActor.assumeIsolated { self?.reconcile() }
      })
    observers.append(
      center.addObserver(
        forName: .NSPersistentStoreRemoteChange, object: store.container.persistentStoreCoordinator, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.remoteChange() }
      })
    reconcile()
  }

  /// "Sleep time": requests the timer of the child's running sleep. It requests none when the child already has a
  /// pending or showing timer for that sleep, so a double tap gives one timer.
  func requestTimer(for childID: Child.ID) {
    guard isEnabled, let sleep = store.sleeps(of: childID).first(where: \.isRunning),
      let index = store.children.firstIndex(where: { $0.id == childID })
    else { return }
    guard !Self.timers.contains(where: { $0.content.state.sleepID == sleep.id }) else { return }
    let attributes = SleepTimerAttributes(
      childID: childID, childName: store.children[index].name, avatarColorIndex: index,
      showsFrom: SleepTimerRule.start(for: sleep, now: Date(), timeZone: .current))
    request(attributes, state: .init(sleepID: sleep.id, start: sleep.start, kind: sleep.kind))
  }

  /// Makes the timers match the running sleeps, with the Core reconcile rule.
  func reconcile() {
    guard isEnabled else { return }
    let timers = Self.timers
    let snapshots = timers.map { activity in
      SleepTimerSnapshot(
        id: activity.id, childID: activity.attributes.childID, sleepID: activity.content.state.sleepID,
        start: activity.content.state.start, kind: activity.content.state.kind,
        showsFrom: activity.attributes.showsFrom, isShowing: activity.activityState == .active)
    }
    let changes = SleepTimerRule.changes(
      timers: snapshots, runningSleeps: store.sleeps.filter(\.isRunning), now: Date(), timeZone: .current)
    let isForeground = UIApplication.shared.applicationState == .active
    for change in changes {
      apply(change, to: timers, isForeground: isForeground)
    }
  }

  /// The store reloads its data only later, in a task. So refresh it first, then reconcile.
  private func remoteChange() {
    Task {
      await store.refresh()
      reconcile()
    }
  }

  private func apply(_ change: SleepTimerChange, to timers: [Activity<SleepTimerAttributes>], isForeground: Bool) {
    switch change {
    case .update(let id, let sleepID, let start, let kind):
      guard let activity = timers.first(where: { $0.id == id }) else { return }
      update(activity, to: .init(sleepID: sleepID, start: start, kind: kind))
    case .end(let id):
      guard let activity = timers.first(where: { $0.id == id }) else { return }
      end(activity)
    case .replace(let id, let sleepID, let start, let kind, let showsFrom):
      guard let activity = timers.first(where: { $0.id == id }) else { return }
      let state = SleepTimerAttributes.ContentState(sleepID: sleepID, start: start, kind: kind)
      // iOS lets an app request a Live Activity only in the foreground. In the background, update the timer now,
      // and the reconcile when the app becomes active replaces it.
      guard isForeground else {
        update(activity, to: state)
        return
      }
      var attributes = activity.attributes
      attributes.showsFrom = showsFrom
      end(activity)
      request(attributes, state: state)
    }
  }

  /// Requests a timer: at once, or with the iOS 26 scheduled start and a silent alert.
  private func request(_ attributes: SleepTimerAttributes, state: SleepTimerAttributes.ContentState) {
    let content = ActivityContent(state: state, staleDate: nil)
    do {
      if let showsFrom = attributes.showsFrom {
        let alert = AlertConfiguration(
          title: "\(attributes.childName) is sleeping",
          body: "Timer since \(ClockTime.text(state.start, in: .current))",
          sound: .named(Self.silence))
        _ = try Activity.request(
          attributes: attributes, content: content, pushType: nil, style: .standard, alertConfiguration: alert,
          start: showsFrom)
      } else {
        _ = try Activity.request(attributes: attributes, content: content, pushType: nil, style: .standard)
      }
    } catch {
      // Live Activities that are off for the app give no timer and no error.
      Self.logger.error("The sleep timer was not requested: \(String(describing: error), privacy: .public)")
    }
  }

  /// An update passes no alert configuration, so it is silent.
  private func update(_ activity: Activity<SleepTimerAttributes>, to state: SleepTimerAttributes.ContentState) {
    Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
  }

  private func end(_ activity: Activity<SleepTimerAttributes>) {
    Task { await activity.end(nil, dismissalPolicy: .immediate) }
  }

  /// The timers that are pending or showing. A card that the parent swiped away is `.dismissed`, so it never comes
  /// back for that sleep.
  private static var timers: [Activity<SleepTimerAttributes>] {
    Activity<SleepTimerAttributes>.activities.filter { $0.activityState == .pending || $0.activityState == .active }
  }
}
