import Core
import CoreData
import NapTimeStore
import OSLog
import SwiftUI

@main
struct NapTimeApp: App {
  private let mode: AppMode

  init() {
    do {
      mode = try LaunchArguments.parse(ProcessInfo.processInfo.arguments)
    } catch {
      // A bad launch argument would give wrong screenshots, so stop with the reason.
      fatalError(error.description)
    }
  }

  var body: some Scene {
    WindowGroup {
      RootView(mode: mode)
    }
  }
}

private struct RootView: View {
  let mode: AppMode
  @State private var store: NSPersistentCloudKitContainer?

  private static let logger = Logger(subsystem: "nl.clearblocks.naptime", category: "FamilyStore")

  var body: some View {
    HomeView()
      .task { await loadStore() }
  }

  /// Loads the family store in the background. On failure, logs the error and keeps the home screen.
  private func loadStore() async {
    do {
      let groupURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: FamilyStore.appGroupIdentifier)
      let description = try FamilyStore.storeDescription(for: mode, appGroupContainerURL: groupURL)
      store = try await FamilyStore.load(description)
    } catch {
      Self.logger.error("The family store did not load: \(String(describing: error), privacy: .public)")
    }
  }
}
