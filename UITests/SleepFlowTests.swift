import XCTest

/// Logs sleeps with the main button ("Nap time" by day, "Sleep time" by night) and "Wake up" on the home screen,
/// in test mode.
final class SleepFlowTests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// At 10:00 the main button says "Nap time", and a tap starts a nap. The test clock is fixed, so this nap
  /// lasts 0 minutes and "Wake up" keeps no sleep.
  @MainActor
  func testNapTimeThenWakeUpAtOnceKeepsNoSleep() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.waitFor(driver.button("Nap time"))
    XCTAssertFalse(driver.button("Sleep time").exists)
    driver.button("Nap time").tap()
    driver.waitFor(driver.text("Mila is sleeping"))
    XCTAssertTrue(driver.text("0 m · since 10:00").exists)
    XCTAssertTrue(driver.button("Wake up").exists)
    XCTAssertFalse(driver.app.buttons["Adjust"].exists)
    XCTAssertFalse(driver.text("Saved").exists)

    // The running sleep is a nap.
    driver.tapStatusLine("0 m · since 10:00")
    XCTAssertTrue(driver.button("Nap").isSelected)
    driver.button("cancel").tap()
    driver.waitForFormToClose()

    driver.button("Wake up").tap()
    driver.waitFor(driver.text("Mila is awake"))
    XCTAssertTrue(driver.text("since 06:55 · 11 h 10 m slept today").exists)
    XCTAssertTrue(driver.button("Nap time").exists)
  }

  /// The main button's identifier is its visible text, and VoiceOver says "Mila fell asleep" by day and by night.
  @MainActor
  func testTheMainButtonSaysMilaFellAsleepForBothTitles() throws {
    let day = AppDriver.launch(seed: "family")
    day.waitFor(day.button("Nap time"))
    XCTAssertEqual(day.button("Nap time").label, "Mila fell asleep")

    let evening = AppDriver.launch(seed: "evening", now: "2026-06-21T22:05:00+02:00")
    evening.waitFor(evening.button("Sleep time"))
    XCTAssertFalse(evening.button("Nap time").exists)
    XCTAssertEqual(evening.button("Sleep time").label, "Mila fell asleep")
  }

  /// Review focus 3: two fast taps make one running sleep. The second tap must not hit "Wake up".
  @MainActor
  func testADoubleTapOnNapTimeStartsOneSleep() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.waitFor(driver.button("Nap time"))
    driver.button("Nap time").doubleTap()
    driver.waitFor(driver.text("Mila is sleeping"))
    // Wait past the time in which a tap is ignored, then check that the sleep still runs.
    Thread.sleep(forTimeInterval: 2)
    XCTAssertTrue(driver.text("Mila is sleeping").exists)
    XCTAssertTrue(driver.text("0 m · since 10:00").exists)
    XCTAssertTrue(driver.button("Wake up").exists)
  }

  @MainActor
  func testWakeUpFromANapKeepsTheNap() throws {
    let driver = AppDriver.launch(seed: "napping", now: "2026-06-21T13:50:00+02:00")
    driver.waitFor(driver.button("Wake up"))
    driver.button("Wake up").tap()
    driver.waitFor(driver.text("Mila is awake"))
    XCTAssertTrue(driver.text("since 13:50 · 11 h 55 m slept today").exists)
    driver.waitForSky("day")
  }

  /// Review focus 5: by day, Noah is awake while Mila naps, so Noah's button says "Nap time".
  @MainActor
  func testNoahShowsNapTimeWhileMilaNaps() throws {
    let driver = AppDriver.launch(seed: "napping", now: "2026-06-21T13:50:00+02:00")
    driver.waitFor(driver.button("Wake up"))
    XCTAssertTrue(driver.text("Mila is sleeping").exists)

    driver.button("Noah").tap()
    driver.waitFor(driver.text("Noah is awake"))
    XCTAssertTrue(driver.button("Nap time").exists)
    XCTAssertFalse(driver.button("Wake up").exists)
  }

  /// At 21:56 on 21 June the sunset phase runs (sunset 22:04). Mila's running night, Noah, and Mila right after
  /// "Wake up" all show the sunset sky: a running sleep follows the sun (CRAFT-82).
  @MainActor
  func testEachChildHasTheirOwnSleepAndSky() throws {
    let driver = AppDriver.launch(seed: "sleeping", now: "2026-06-21T21:56:00+02:00")
    driver.waitFor(driver.text("Mila is sleeping"))
    driver.waitForSky("sunset")

    driver.button("Noah").tap()
    driver.waitFor(driver.text("Noah is awake"))
    XCTAssertTrue(driver.button("Sleep time").exists)
    driver.waitForSky("sunset")

    driver.button("Mila").tap()
    driver.waitFor(driver.text("Mila is sleeping"))
    driver.waitForSky("sunset")
    driver.button("Wake up").tap()
    driver.waitFor(driver.text("Mila is awake"))
    // The night that just ended counts for the next sleep day, so the evening shows today's total.
    XCTAssertTrue(driver.text("since 21:56 · 11 h 10 m slept today").exists)
    driver.waitForSky("sunset")
  }
}
