import XCTest

/// Moves between weeks on the Charts tab, and adds a sleep from an empty week, in test mode.
final class ChartsFlowTests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  func testThePreviousArrowAndASwipeMoveOneWeek() throws {
    let driver = AppDriver.launch(seed: "week-today", now: "2026-11-11T10:00:00+01:00")
    driver.openCharts()
    driver.waitFor(driver.text("Mon 9 – Sun 15 Nov"))
    driver.button("Previous week").tap()
    driver.waitFor(driver.text("Mon 2 – Sun 8 Nov"))
    XCTAssertTrue(driver.text("12 h 09 m").exists)
    XCTAssertTrue(driver.button("Next week").isEnabled)
    driver.app.swipeLeft()
    driver.waitFor(driver.text("Mon 9 – Sun 15 Nov"))
    driver.app.swipeRight()
    driver.waitFor(driver.text("Mon 2 – Sun 8 Nov"))
  }

  /// "Add a sleep" on the current empty week starts from now.
  @MainActor
  func testAddASleepOnTheCurrentWeekOpensTheSleepForm() throws {
    let driver = AppDriver.launch(seed: "week", now: "2026-11-11T10:00:00+01:00")
    driver.button("Noah").tap()
    driver.waitFor(driver.text("Noah is awake"))
    driver.openCharts()
    driver.button("Add a sleep").tap()
    driver.waitFor(driver.app.descendants(matching: .any)["sleep-form"])
    XCTAssertEqual(driver.button("fell-asleep").label, "Wed 11 Nov · 09:00")
    XCTAssertEqual(driver.button("woke-up").label, "Wed 11 Nov · 10:00")
  }

  /// "Add a sleep" on an earlier empty week starts inside that week's Sunday sleep day.
  @MainActor
  func testAddASleepOnAnEarlierWeekStartsOnItsSunday() throws {
    let driver = AppDriver.launch(seed: "week", now: "2026-11-11T10:00:00+01:00")
    driver.openCharts()
    driver.waitFor(driver.text("Mon 9 – Sun 15 Nov"))
    driver.button("Previous week").tap()
    driver.waitFor(driver.text("Mon 2 – Sun 8 Nov"))
    driver.button("Previous week").tap()
    driver.waitFor(driver.text("Mon 26 Oct – Sun 1 Nov"))
    driver.waitFor(driver.text("No sleeps this week"))
    driver.button("Add a sleep").tap()
    driver.waitFor(driver.app.descendants(matching: .any)["sleep-form"])
    XCTAssertEqual(driver.button("fell-asleep").label, "Sun 1 Nov · 09:00")
    XCTAssertEqual(driver.button("woke-up").label, "Sun 1 Nov · 10:00")
    driver.button("save").tap()
    driver.waitForFormToClose()
    driver.waitFor(driver.text("Mon 26 Oct – Sun 1 Nov"))
    XCTAssertEqual(driver.barValues, ["too little"])
  }

  /// Review focus 5: Charts opens on the selected child's current week, not the week the parent last looked at.
  @MainActor
  func testChartsOpensOnTheCurrentWeekOfTheSelectedChild() throws {
    let driver = AppDriver.launch(seed: "week-today", now: "2026-11-11T10:00:00+01:00")
    driver.openCharts()
    driver.waitFor(driver.text("Mila's week"))
    driver.button("Previous week").tap()
    driver.waitFor(driver.text("Mon 2 – Sun 8 Nov"))
    driver.openToday()
    driver.button("Noah").tap()
    driver.waitFor(driver.text("Noah is awake"))
    driver.openCharts()
    driver.waitFor(driver.text("Noah's week"))
    XCTAssertTrue(driver.text("Mon 9 – Sun 15 Nov").exists)
    driver.button("Previous week").tap()
    driver.waitFor(driver.text("Mon 2 – Sun 8 Nov"))
    driver.openToday()
    driver.openCharts()
    driver.waitFor(driver.text("Mon 9 – Sun 15 Nov"))
  }
}
