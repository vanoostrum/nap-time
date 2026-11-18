import XCTest

/// The "What to try" card at the end of the Charts tab.
final class WhatToTryFlowTests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  private let threeDaysSoFar =
    "Keep logging. With sleeps on 4 days of the week, Nap Time shows what to try for Mila. 3 of 4 days so far."

  /// Review focus 5 and criterion 11: a sleep added to a fourth day shows a tip at once,
  /// and its delete turns the card back into the keep-logging card at once.
  @MainActor
  func testAddingAndDeletingASleepSwitchesBetweenATipAndKeepLogging() throws {
    let driver = AppDriver.launch(seed: "week-today", now: "2026-11-12T19:30:00+01:00")
    driver.openCharts()
    driver.waitFor(driver.text("Mon 9 – Sun 15 Nov"))
    driver.scrollToWhatToTry()
    XCTAssertEqual(driver.tip.label, threeDaysSoFar)

    driver.scrollChartsToTop()
    driver.openDaySheet(row: "Thursday 12 Nov details", title: "Thursday 12 Nov")
    driver.button("+ Add a sleep to this day").tap()
    driver.waitFor(driver.app.descendants(matching: .any)["sleep-form"])
    XCTAssertEqual(driver.button("fell-asleep").label, "Wed 11 Nov · 18:30")
    XCTAssertEqual(driver.button("woke-up").label, "Wed 11 Nov · 19:30")
    driver.button("save").tap()
    driver.waitForFormToClose()
    driver.waitFor(driver.text("18:30 → 19:30"))
    driver.tapDimmedCharts()
    driver.waitForDaySheetToClose()
    driver.scrollToWhatToTry()
    XCTAssertFalse(driver.tip.label.hasPrefix("Keep logging"), driver.tip.label)
    XCTAssertFalse(driver.button("Add a sleep from earlier").exists)

    driver.scrollChartsToTop()
    driver.openDaySheet(row: "Thursday 12 Nov details", title: "Thursday 12 Nov")
    driver.button("Edit night").tap()
    driver.waitFor(driver.app.descendants(matching: .any)["sleep-form"])
    driver.button("Delete this sleep").tap()
    driver.button("Delete sleep").tap()
    driver.waitForFormToClose()
    driver.waitFor(driver.text("No sleeps logged"))
    driver.tapDimmedCharts()
    driver.waitForDaySheetToClose()
    driver.scrollToWhatToTry()
    XCTAssertEqual(driver.tip.label, threeDaysSoFar)
    XCTAssertTrue(driver.button("Add a sleep from earlier").exists)
  }

  /// Criterion 3 on an earlier week: "Add a sleep from earlier" starts inside that week's Sunday sleep day.
  @MainActor
  func testAddASleepFromEarlierOnAnEarlierWeek() throws {
    let driver = AppDriver.launch(seed: "family", now: "2026-06-21T19:30:00+02:00")
    driver.openCharts()
    driver.waitFor(driver.text("Mon 15 – Sun 21 Jun"))
    driver.scrollToWhatToTry()
    XCTAssertEqual(
      driver.tip.label,
      "Keep logging. With sleeps on 4 days of the week, Nap Time shows what to try for Mila. 1 of 4 days logged.")
    driver.button("Add a sleep from earlier").tap()
    driver.waitFor(driver.app.descendants(matching: .any)["sleep-form"])
    XCTAssertEqual(driver.button("fell-asleep").label, "Sat 20 Jun · 18:30")
    XCTAssertEqual(driver.button("woke-up").label, "Sat 20 Jun · 19:30")
  }
}
