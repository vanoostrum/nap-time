import XCTest

/// Adds, edits, ends, and deletes sleeps with the sleep form, in test mode.
final class SleepEditFlowTests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  func testAddSleepSavesAndTheTotalChanges() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.tapSleepLink("Add a sleep from earlier")
    driver.button("save").tap()
    driver.waitForFormToClose()
    driver.waitFor(driver.text("since 10:00 · 12 h 10 m slept today"))
    XCTAssertTrue(driver.text("Mila is awake").exists)
  }

  @MainActor
  func testCancelOnEachFormChangesNothing() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.tapSleepLink("Add a sleep from earlier")
    driver.button("cancel").tap()
    driver.waitForFormToClose()
    driver.waitFor(driver.text("since 06:55 · 11 h 10 m slept today"))

    driver.tapStatusLine("since 06:55 · 11 h 10 m slept today")
    driver.button("Nap").tap()
    driver.button("cancel").tap()
    driver.waitForFormToClose()
    driver.tapStatusLine("since 06:55 · 11 h 10 m slept today")
    XCTAssertTrue(driver.button("Night").isSelected)
    driver.button("cancel").tap()
    driver.waitForFormToClose()

    let sleeping = AppDriver.launch(seed: "sleeping", now: "2026-06-21T21:56:00+02:00")
    sleeping.tapSleepLink("Woke earlier? Set the time")
    sleeping.button("cancel").tap()
    sleeping.waitForFormToClose()
    sleeping.waitFor(sleeping.text("Mila is sleeping"))
    sleeping.tapStatusLine("2 h 14 m · since 19:42")
    sleeping.button("Nap").tap()
    sleeping.button("cancel").tap()
    sleeping.waitForFormToClose()
    sleeping.waitFor(sleeping.text("2 h 14 m · since 19:42"))
    // A running night follows the sun: sunset at 21:56 on 21 June.
    sleeping.waitForSky("sunset")
  }

  /// Saving Edit sleep with another type changes the sleep: it opens again as a nap.
  @MainActor
  func testEditSleepSavesAnotherType() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.tapStatusLine("since 06:55 · 11 h 10 m slept today")
    driver.button("Nap").tap()
    XCTAssertTrue(driver.button("Nap").isSelected)
    driver.button("save").tap()
    driver.waitForFormToClose()

    driver.tapStatusLine("since 06:55 · 11 h 10 m slept today")
    XCTAssertTrue(driver.button("Nap").isSelected)
    XCTAssertFalse(driver.button("Night").isSelected)
  }

  /// Deleting Mila's only sleep leaves "0 m slept today". Cancel in the confirmation keeps it.
  @MainActor
  func testDeleteTheOnlySleep() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.tapStatusLine("since 06:55 · 11 h 10 m slept today")
    driver.button("Delete this sleep").tap()
    driver.waitFor(driver.text("Delete this sleep?"))
    driver.button("confirm-cancel").tap()
    XCTAssertTrue(driver.text("Delete this sleep?").waitForNonExistence(timeout: 10))
    XCTAssertTrue(driver.button("Delete this sleep").exists)

    driver.button("Delete this sleep").tap()
    driver.button("Delete sleep").tap()
    driver.waitForFormToClose()
    driver.waitFor(driver.text("0 m slept today"))
    XCTAssertTrue(driver.text("Mila is awake").exists)
  }

  @MainActor
  func testWokeEarlierSavesAndMilaIsAwake() throws {
    let driver = AppDriver.launch(seed: "sleeping", now: "2026-06-21T21:56:00+02:00")
    driver.tapSleepLink("Woke earlier? Set the time")
    driver.button("save").tap()
    driver.waitForFormToClose()
    driver.waitFor(driver.text("Mila is awake"))
    XCTAssertTrue(driver.text("since 21:56 · 11 h 10 m slept today").exists)
    XCTAssertTrue(driver.button("Sleep time").exists)
    // At 21:56 on 21 June the sunset phase runs (sunset 22:04).
    driver.waitForSky("sunset")
  }

  @MainActor
  func testRunningStartSavesAndTheSleepStillRuns() throws {
    let driver = AppDriver.launch(seed: "sleeping", now: "2026-06-21T21:56:00+02:00")
    driver.tapStatusLine("2 h 14 m · since 19:42")
    driver.button("Nap").tap()
    driver.button("save").tap()
    driver.waitForFormToClose()
    driver.waitFor(driver.text("Mila is sleeping"))
    XCTAssertTrue(driver.text("2 h 14 m · since 19:42").exists)
    XCTAssertTrue(driver.button("Wake up").exists)
    // The type is now a nap, so the sky follows the sun: sunset at 21:56 on 21 June.
    driver.waitForSky("sunset")
  }

  /// A child with no sleeps has nothing to open: the status line does nothing.
  @MainActor
  func testTheStatusLineWithNoSleepsOpensNothing() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.waitFor(driver.button("Noah"))
    driver.button("Noah").tap()
    driver.waitFor(driver.text("Noah is awake"))
    XCTAssertFalse(driver.app.buttons["status-line"].exists)
    driver.text("0 m slept today").tap()
    XCTAssertFalse(driver.app.descendants(matching: .any)["sleep-form"].waitForExistence(timeout: 2))
  }
}
