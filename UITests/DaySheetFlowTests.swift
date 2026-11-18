import XCTest

/// Opens, closes, and changes sleeps through the day sheet on the Charts tab, in test mode.
final class DaySheetFlowTests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// Criteria 3 and 10: a row opens the sheet, and a swipe down closes it.
  @MainActor
  func testARowOpensTheSheetAndASwipeDownClosesIt() throws {
    let driver = AppDriver.launch(seed: "week", now: "2026-11-08T19:30:00+01:00")
    driver.openCharts()
    driver.openDaySheet(row: "Tuesday 3 Nov details", title: "Tuesday 3 Nov")
    XCTAssertTrue(driver.text("10 h 12 m slept in total").exists)
    driver.daySheet.swipeDown()
    driver.waitForDaySheetToClose()
    XCTAssertTrue(driver.text("When Mila slept").exists)
  }

  /// Criteria 4 and 10: the striped bar's row opens the current day's sheet, and a tap on the dimmed charts closes it.
  @MainActor
  func testATapOnTheDimmedChartsClosesTheSheet() throws {
    let driver = AppDriver.launch(seed: "week-today", now: "2026-11-11T10:00:00+01:00")
    driver.openCharts()
    driver.openDaySheet(row: "Wednesday 11 Nov details", title: "Wednesday 11 Nov")
    XCTAssertTrue(driver.text("10 h 50 m slept so far").exists)
    driver.tapDimmedCharts()
    driver.waitForDaySheetToClose()
  }

  /// Criterion 7: a pencil opens Edit sleep, and the sheet shows the saved change.
  @MainActor
  func testEditingASleepFromTheSheetUpdatesTheSheet() throws {
    let driver = AppDriver.launch(seed: "week", now: "2026-11-08T19:30:00+01:00")
    driver.openCharts()
    driver.openDaySheet(bar: 1, title: "Tuesday 3 Nov")
    driver.button("Edit nap").tap()
    driver.waitFor(driver.app.descendants(matching: .any)["sleep-form"])
    XCTAssertEqual(driver.button("fell-asleep").label, "Tue 3 Nov · 13:30")
    XCTAssertEqual(driver.button("woke-up").label, "Tue 3 Nov · 14:24")
    driver.button("Night").tap()
    driver.button("save").tap()
    driver.waitForFormToClose()
    driver.waitFor(driver.daySheet)
    XCTAssertTrue(driver.text("Tuesday 3 Nov").exists)
    XCTAssertFalse(driver.button("Edit nap").exists)
    XCTAssertEqual(driver.app.buttons.matching(NSPredicate(format: "label == %@", "Edit night")).count, 2)
    XCTAssertTrue(driver.text("13:30 → 14:24").exists)
  }

  /// Criterion 8 and review focus 2: deleting Noah's only nap empties the sheet, the bar, and the stat cards.
  @MainActor
  func testDeletingTheOnlySleepOfADay() throws {
    let driver = AppDriver.launch(seed: "week", now: "2026-11-08T19:30:00+01:00")
    driver.button("Noah").tap()
    driver.waitFor(driver.text("Noah is awake"))
    driver.openCharts()
    driver.waitFor(driver.text("Mon 2 – Sun 8 Nov"))
    XCTAssertEqual(driver.bars.count, 1)
    XCTAssertEqual(driver.bars.element(boundBy: 0).label, "Tuesday 3 Nov, 1 h 30 m")
    XCTAssertTrue(driver.text("1 h 30 m").exists)
    XCTAssertTrue(driver.text("0 of 1 day").exists)

    driver.openDaySheet(bar: 0, title: "Tuesday 3 Nov")
    XCTAssertTrue(driver.text("13:00 → 14:30").exists)
    driver.button("Edit nap").tap()
    driver.waitFor(driver.app.descendants(matching: .any)["sleep-form"])
    driver.button("Delete this sleep").tap()
    driver.button("Delete sleep").tap()
    driver.waitForFormToClose()
    driver.waitFor(driver.daySheet)
    driver.waitFor(driver.text("No sleeps logged"))
    XCTAssertTrue(driver.text("Tuesday 3 Nov").exists)

    driver.tapDimmedCharts()
    driver.waitForDaySheetToClose()
    driver.waitFor(driver.text("No sleeps this week"))
    XCTAssertEqual(driver.bars.count, 0)
    XCTAssertEqual(driver.app.staticTexts.matching(NSPredicate(format: "label == %@", "–")).count, 2)
    XCTAssertTrue(driver.text("Mon 2 – Sun 8 Nov").exists)
    XCTAssertTrue(driver.text("Log Noah's sleeps on the Today tab, or add one from earlier.").exists)
    XCTAssertTrue(driver.button("Add a sleep").exists)
    XCTAssertFalse(driver.button("Previous week").isEnabled)
    XCTAssertTrue(driver.button("Next week").isEnabled)
  }

  /// Criterion 6 and review focus 4: the running night on the current day's sheet opens the running-sleep form.
  @MainActor
  func testARunningSleepOnTheSheetOpensTheRunningSleepForm() throws {
    let driver = AppDriver.launch(seed: "sleeping", now: "2026-06-21T21:56:00+02:00")
    driver.openCharts()
    driver.waitFor(driver.text("Mon 15 – Sun 21 Jun"))
    driver.button("Next week").tap()
    driver.waitFor(driver.text("Mon 22 – Sun 28 Jun"))
    driver.openDaySheet(row: "Monday 22 Jun details", title: "Monday 22 Jun")
    XCTAssertTrue(driver.text("19:42 → now").exists)
    XCTAssertTrue(driver.text("2 h 14 m").exists)
    XCTAssertTrue(driver.text("So far").exists)
    driver.button("Edit night").tap()
    driver.waitFor(driver.app.descendants(matching: .any)["sleep-form"])
    XCTAssertTrue(driver.text("Still asleep").exists)
    XCTAssertFalse(driver.button("Delete this sleep").exists)
  }

  /// Criterion 9: "+ Add a sleep to this day" on a past empty day starts inside that day, and the saved sleep shows.
  @MainActor
  func testAddingASleepFromAnEmptyDayShowsItOnTheSheet() throws {
    let driver = AppDriver.launch(seed: "week", now: "2026-11-08T19:30:00+01:00")
    driver.button("Noah").tap()
    driver.waitFor(driver.text("Noah is awake"))
    driver.openCharts()
    driver.openDaySheet(row: "Monday 2 Nov details", title: "Monday 2 Nov")
    driver.button("+ Add a sleep to this day").tap()
    driver.waitFor(driver.app.descendants(matching: .any)["sleep-form"])
    // 19:30 is on the evening before Monday 2 Nov, 1 November.
    XCTAssertEqual(driver.button("fell-asleep").label, "Sun 1 Nov · 18:30")
    XCTAssertEqual(driver.button("woke-up").label, "Sun 1 Nov · 19:30")
    driver.button("save").tap()
    driver.waitForFormToClose()
    driver.waitFor(driver.daySheet)
    driver.waitFor(driver.text("18:30 → 19:30"))
    XCTAssertTrue(driver.text("1 h 00 m slept in total").exists)
    XCTAssertEqual(driver.bars.count, 2)
  }
}
