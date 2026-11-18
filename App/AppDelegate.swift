import AppIntents
import CloudKit
import Core
import CoreData
import NapTimeStore
import OSLog
import Observation
import UIKit

/// Gives each window scene the scene delegate, so the app gets the invites that the partner opens.
final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    configuration.delegateClass = SceneDelegate.self
    return configuration
  }
}

/// Hands each opened invite to `OpenedInvites`: while the app runs, and on a cold launch from the link.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let metadata = connectionOptions.cloudKitShareMetadata {
      OpenedInvites.shared.metadata = metadata
    }
  }

  func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
    OpenedInvites.shared.metadata = metadata
  }
}

/// The invite that the partner opened, held until the family store has loaded and the app handles it.
@MainActor @Observable
final class OpenedInvites {
  static let shared = OpenedInvites()

  var metadata: CKShare.Metadata?
}

/// The one owner of the family store, created at launch outside a view, so a background launch has the store too.
///
/// It loads the store, holds the selected child and the tab, creates the sleep timer controller and the nudge
/// scheduler, runs their triggers, and registers the store for `EndSleepIntent`. `RootView` reads it.
@MainActor @Observable
final class AppModel {
  static let shared = AppModel()

  enum Phase {
    case loading
    case failed
    case ready(FamilyStore)
  }

  private(set) var phase = Phase.loading
  /// The child chosen on this phone. `SelectedChild` decides which child the home screen shows.
  private(set) var selectedID: Child.ID?
  var tab = AppTab.today
  /// The app accepted a share, and the partner has not tapped "Start" yet. Held in memory only.
  var pendingJoin = false
  private(set) var mode = AppMode.normal

  @ObservationIgnored private var load: Task<FamilyStore?, Never>?
  @ObservationIgnored private(set) var sleepTimers: SleepTimerController?
  @ObservationIgnored private(set) var nudges: NudgeScheduler?
  @ObservationIgnored private var observers: [any NSObjectProtocol] = []

  private static let logger = Logger(subsystem: "nl.clearblocks.naptime", category: "FamilyStore")
  private static let selectedChildKey = "selectedChildID"

  /// Starts the load of the family store once, at launch.
  func launch(_ mode: AppMode) {
    guard load == nil else { return }
    self.mode = mode
    // Here, not after the load, so the tap on a nudge that launched the app reaches its delegate.
    nudges = NudgeScheduler(mode: mode)
    AppDependencyManager.shared.add(dependency: FamilyStoreAccess { await AppModel.shared.loadedStore() })
    load = Task { await loadStore() }
  }

  /// The family store once it has loaded, or `nil` when it did not load.
  func loadedStore() async -> FamilyStore? {
    await load?.value
  }

  func select(_ id: Child.ID) {
    selectedID = id
    // Test mode does not read or write user defaults, so every run starts the same.
    if mode == .normal {
      UserDefaults.standard.set(id.uuidString, forKey: Self.selectedChildKey)
    }
  }

  /// Loads the family store. In test mode the store adds the children and the sleeps of the seed first.
  /// On failure, it logs the error and keeps the home screen with the sky.
  private func loadStore() async -> FamilyStore? {
    do {
      let groupURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: FamilyStore.appGroupIdentifier)
      let store = try await FamilyStore.load(
        mode, appGroupContainerURL: groupURL, seedPhoto: { $0.drawsPhoto ? SeedPhoto.pngData() : nil })
      if case .test(let environment) = mode {
        pendingJoin = environment.seed.startsWithPendingJoin
      } else {
        selectedID = UserDefaults.standard.string(forKey: Self.selectedChildKey).flatMap(UUID.init(uuidString:))
      }
      let timers = SleepTimerController(store: store, mode: mode)
      sleepTimers = timers
      nudges?.store = store
      // One closure for every save and every change of `sharing`: it reconciles the sleep timers and plans the nudges.
      store.onSave = { [weak self] in self?.storeChanged() }
      timers.start()
      nudges?.plan()
      observe(store)
      phase = .ready(store)
      return store
    } catch {
      Self.logger.error("The family store did not load: \(String(describing: error), privacy: .public)")
      phase = .failed
      return nil
    }
  }

  /// The timers and the nudges follow the store.
  private func storeChanged() {
    sleepTimers?.reconcile()
    nudges?.plan()
  }

  /// In the normal mode: when the app becomes active, and on a remote change after one refresh of the store.
  /// Test mode has no timers and no nudges, so it observes nothing.
  private func observe(_ store: FamilyStore) {
    guard mode == .normal else { return }
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) {
        [weak self] _ in
        MainActor.assumeIsolated { self?.storeChanged() }
      })
    observers.append(
      center.addObserver(
        forName: .NSPersistentStoreRemoteChange, object: store.container.persistentStoreCoordinator, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          // The store reloads its data only later, in a task. So refresh it first.
          Task {
            await store.refresh()
            self?.storeChanged()
          }
        }
      })
  }
}
