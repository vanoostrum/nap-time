import Core
import CoreData
import Foundation
import NapTimeStore
import Testing

@Suite struct FamilyStoreTests {
  private let testMode = AppMode.test(.standard)

  @Test @MainActor func testModeStoreLoadsInMemoryWithoutCloudKit() async throws {
    let description = try FamilyStore.storeDescription(for: testMode, appGroupContainerURL: nil)
    #expect(description.cloudKitContainerOptions == nil)

    let container = try await FamilyStore.load(description)

    let stores = container.persistentStoreCoordinator.persistentStores
    #expect(stores.count == 1)
    #expect(stores.first?.type == NSInMemoryStoreType)
    #expect(container.persistentStoreDescriptions.first?.cloudKitContainerOptions == nil)
  }

  @Test func normalModePutsTheStoreUnderTheAppGroupContainer() throws {
    let groupURL = URL(filePath: "/tmp/group.nl.clearblocks.naptime-test", directoryHint: .isDirectory)

    let description = try FamilyStore.storeDescription(for: .normal, appGroupContainerURL: groupURL)

    let storeURL = try #require(description.url)
    #expect(storeURL.standardizedFileURL.path().hasPrefix(groupURL.standardizedFileURL.path()))
    #expect(storeURL.lastPathComponent == "NapTime.sqlite")
    #expect(description.type == NSSQLiteStoreType)
    #expect(description.cloudKitContainerOptions?.containerIdentifier == "iCloud.nl.clearblocks.naptime")
  }

  @Test func normalModeWithoutAppGroupContainerNamesTheGroup() {
    #expect(throws: FamilyStoreError.noAppGroupContainer(groupIdentifier: "group.nl.clearblocks.naptime")) {
      try FamilyStore.storeDescription(for: .normal, appGroupContainerURL: nil)
    }
    let error = FamilyStoreError.noAppGroupContainer(groupIdentifier: FamilyStore.appGroupIdentifier)
    #expect(error.description.contains("group.nl.clearblocks.naptime"))
  }
}
