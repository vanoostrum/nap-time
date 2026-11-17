import SwiftUI
import XCTest

/// Saves one screenshot per entry point as an attachment named `<entry point>.png`.
/// The `Screenshots` CI job exports them into the `screenshots` artifact and the `screenshots/<branch>` branch.
final class EntryPointTests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// `add-child`: "Add your child" as the app opens, empty. Page `child/add-empty.html`.
  @MainActor
  func testAddChild() throws {
    let driver = AppDriver.launch(seed: "none")
    driver.waitFor(driver.text("Add your child"))
    XCTAssertTrue(driver.text("Choose a date").exists)
    XCTAssertFalse(driver.button("Add child").isEnabled)
    XCTAssertTrue(
      driver.text("Does your partner already use Nap Time? Open the invite link from your partner instead.").exists)
    driver.attachScreenshot("add-child", to: self)
  }

  /// `add-child-filled`: "Add your child" filled in for Mila. Page `child/add.html`.
  @MainActor
  func testAddChildFilled() throws {
    let driver = AppDriver.launch(seed: "none")
    driver.typeName("Mila")
    driver.setBirthDate(day: 12, month: "March", year: 2025)
    driver.waitFor(driver.text("12 March 2025"))
    XCTAssertTrue(driver.text("Mila is 1 year old. The range is 11–14 h of sleep a day.").exists)
    XCTAssertTrue(driver.button("Add Mila").isEnabled)
    driver.attachScreenshot("add-child-filled", to: self)
  }

  /// `home`: the home screen with Mila selected and awake. Page `home/day.html`.
  @MainActor
  func testHome() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.waitFor(driver.text("Mila is awake"))
    XCTAssertEqual(driver.avatars.count, 2)
    XCTAssertTrue(driver.button("Add a child").exists)
    XCTAssertTrue(driver.text("since 06:55 · 11 h 10 m slept today").exists)
    XCTAssertTrue(driver.button("Sleep time").exists)
    XCTAssertTrue(driver.button("Add a sleep from earlier").exists)
    XCTAssertFalse(driver.app.buttons["Settings"].exists)
    XCTAssertFalse(driver.app.buttons["Charts"].exists)
    driver.waitForSky("day")
    driver.attachScreenshot("home", to: self)
  }

  /// `home-sleeping`: Mila sleeps a night since 19:42, at 21:56. Page `home/night.html`.
  @MainActor
  func testHomeSleeping() throws {
    let driver = AppDriver.launch(seed: "sleeping", now: "2026-06-21T21:56:00+02:00")
    driver.waitFor(driver.text("Mila is sleeping"))
    XCTAssertTrue(driver.text("2 h 14 m · since 19:42").exists)
    XCTAssertTrue(driver.button("Wake up").exists)
    XCTAssertTrue(driver.button("Woke earlier? Set the time").exists)
    driver.waitForSky("night")
    driver.attachScreenshot("home-sleeping", to: self)
  }

  /// `home-napping`: Mila naps since 13:05, at 13:50. Page `home/nap.html`.
  @MainActor
  func testHomeNapping() throws {
    let driver = AppDriver.launch(seed: "napping", now: "2026-06-21T13:50:00+02:00")
    driver.waitFor(driver.text("Mila is sleeping"))
    XCTAssertTrue(driver.text("45 m · since 13:05").exists)
    XCTAssertTrue(driver.button("Wake up").exists)
    XCTAssertTrue(driver.button("Woke earlier? Set the time").exists)
    driver.waitForSky("day")
    driver.attachScreenshot("home-napping", to: self)
  }

  /// `add-another-child`: "Add a child" from "+", filled in for Noah. Page `child/add-another.html`.
  @MainActor
  func testAddAnotherChild() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.waitFor(driver.button("Add a child"))
    driver.button("Add a child").tap()
    driver.waitFor(driver.text("Add a child"))
    driver.typeName("Noah")
    driver.setBirthDate(day: 10, month: "February", year: 2022)
    driver.waitFor(driver.text("10 February 2022"))
    XCTAssertTrue(driver.text("Noah is 4 years old. The range is 10–13 h of sleep a day.").exists)
    XCTAssertTrue(driver.button("Add Noah").isEnabled)
    driver.attachScreenshot("add-another-child", to: self)
  }

  /// `edit-child`: Edit child for Mila. Page `child/edit.html`.
  @MainActor
  func testEditChild() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.openEdit("Mila")
    XCTAssertTrue(driver.text("12 March 2025").exists)
    XCTAssertTrue(driver.button("Save").exists)
    XCTAssertTrue(driver.button("Delete Mila").exists)
    driver.attachScreenshot("edit-child", to: self)
  }

  /// `delete-child`: the delete confirmation for Mila. Page `child/delete.html`.
  @MainActor
  func testDeleteChild() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.openEdit("Mila")
    driver.button("Delete Mila").tap()
    driver.waitFor(driver.text("Delete Mila?"))
    XCTAssertTrue(
      driver.text("This deletes Mila and all of Mila's sleeps, on both phones. You cannot undo this.").exists)
    driver.attachScreenshot("delete-child", to: self)
  }

  /// `new-sleep`: "Add a sleep from earlier" at 10:00. Page `sleep/new.html`.
  @MainActor
  func testNewSleep() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.tapSleepLink("Add a sleep from earlier")
    driver.waitFor(driver.text("Add a sleep"))
    XCTAssertTrue(driver.button("Nap").isSelected)
    XCTAssertFalse(driver.button("Night").isSelected)
    XCTAssertEqual(driver.button("fell-asleep").label, "Sun 21 Jun · 09:00")
    XCTAssertEqual(driver.button("woke-up").label, "Sun 21 Jun · 10:00")
    XCTAssertTrue(driver.text("1 h 00 m of sleep").exists)
    XCTAssertEqual(driver.button("save").label, "Add sleep")
    XCTAssertTrue(driver.button("save").isEnabled)
    XCTAssertFalse(driver.button("Delete this sleep").exists)
    driver.attachScreenshot("new-sleep", to: self)
  }

  /// `edit-sleep`: Edit sleep for Mila's last night, from the awake status line. Page `sleep/edit.html`.
  @MainActor
  func testEditSleep() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.tapStatusLine("since 06:55 · 11 h 10 m slept today")
    driver.waitFor(driver.text("Edit sleep"))
    XCTAssertTrue(driver.button("Night").isSelected)
    XCTAssertEqual(driver.button("fell-asleep").label, "Sat 20 Jun · 19:45")
    XCTAssertEqual(driver.button("woke-up").label, "Sun 21 Jun · 06:55")
    XCTAssertTrue(driver.text("11 h 10 m of sleep").exists)
    XCTAssertEqual(driver.button("save").label, "Save")
    XCTAssertTrue(driver.button("Delete this sleep").exists)
    driver.attachScreenshot("edit-sleep", to: self)
  }

  /// `woke-earlier`: "Woke earlier? Set the time" for Mila's running night at 21:56. Page `sleep/running.html`.
  @MainActor
  func testWokeEarlier() throws {
    let driver = AppDriver.launch(seed: "sleeping", now: "2026-06-21T21:56:00+02:00")
    driver.tapSleepLink("Woke earlier? Set the time")
    driver.waitFor(driver.text("Woke earlier?"))
    XCTAssertTrue(driver.button("Night").isSelected)
    XCTAssertEqual(driver.button("fell-asleep").label, "Sun 21 Jun · 19:42")
    XCTAssertEqual(driver.button("woke-up").label, "Sun 21 Jun · 21:56")
    XCTAssertTrue(driver.text("2 h 14 m of sleep. Mila is awake after you save.").exists)
    XCTAssertEqual(driver.button("save").label, "Save")
    XCTAssertFalse(driver.button("Delete this sleep").exists)
    driver.attachScreenshot("woke-earlier", to: self)
  }

  /// `edit-running-sleep`: Edit sleep for Mila's running night, from the status line. Page `sleep/running-start.html`.
  @MainActor
  func testEditRunningSleep() throws {
    let driver = AppDriver.launch(seed: "sleeping", now: "2026-06-21T21:56:00+02:00")
    driver.tapStatusLine("2 h 14 m · since 19:42")
    driver.waitFor(driver.text("Edit sleep"))
    XCTAssertEqual(driver.button("fell-asleep").label, "Sun 21 Jun · 19:42")
    XCTAssertTrue(driver.text("Saving keeps the sleep running.").exists)
    XCTAssertTrue(driver.text("Still asleep").exists)
    XCTAssertTrue(driver.text("2 h 14 m so far").exists)
    XCTAssertFalse(driver.button("woke-up").exists)
    XCTAssertFalse(driver.button("Delete this sleep").exists)
    driver.attachScreenshot("edit-running-sleep", to: self)
  }

  /// `sleep-overlap`: Add a sleep at 07:30, which overlaps Mila's night. Page `sleep/overlap.html`.
  @MainActor
  func testSleepOverlap() throws {
    let driver = AppDriver.launch(seed: "family", now: "2026-06-21T07:30:00+02:00")
    driver.tapSleepLink("Add a sleep from earlier")
    driver.waitFor(driver.text("This overlaps Mila's night from 19:45 to 06:55."))
    XCTAssertEqual(driver.button("fell-asleep").label, "Sun 21 Jun · 06:30")
    XCTAssertEqual(driver.button("woke-up").label, "Sun 21 Jun · 07:30")
    let add = driver.button("save")
    XCTAssertEqual(add.label, "Add sleep")
    XCTAssertFalse(add.isEnabled)
    driver.attachScreenshot("sleep-overlap", to: self)
    add.tap()
    XCTAssertTrue(driver.app.descendants(matching: .any)["sleep-form"].exists)
  }

  /// `delete-sleep`: the delete confirmation for Mila's last night. Page `sleep/delete.html`.
  @MainActor
  func testDeleteSleep() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.tapStatusLine("since 06:55 · 11 h 10 m slept today")
    driver.button("Delete this sleep").tap()
    driver.waitFor(driver.text("Delete this sleep?"))
    XCTAssertTrue(
      driver.text("This deletes Mila's night from 19:45 to 06:55, on both phones. You cannot undo this.").exists)
    XCTAssertTrue(driver.button("Delete sleep").exists)
    driver.attachScreenshot("delete-sleep", to: self)
  }

  /// `home-long-name`: the home screen with a name of 30 characters. No gallery page.
  @MainActor
  func testHomeLongName() throws {
    let driver = AppDriver.launch(seed: "long-name")
    driver.waitFor(driver.text("Maximiliana Rosalind Pepperpot is awake"))
    driver.attachScreenshot("home-long-name", to: self)
  }

  /// `delete-child-long-name`: the delete confirmation with a name of 30 characters. No gallery page.
  @MainActor
  func testDeleteChildLongName() throws {
    let driver = AppDriver.launch(seed: "long-name")
    driver.openEdit("Maximiliana Rosalind Pepperpot")
    driver.button("Delete Maximiliana Rosalind Pepperpot").tap()
    driver.waitFor(driver.text("Delete Maximiliana Rosalind Pepperpot?"))
    driver.attachScreenshot("delete-child-long-name", to: self)
  }

  /// A UI test cannot open a Live Activity, so it renders the Lock Screen view (ADR 0003).
  @MainActor
  func testLiveActivity() throws {
    let renderer = ImageRenderer(content: LiveActivityView().frame(width: 360, height: 120))
    renderer.scale = 3
    let image = try XCTUnwrap(renderer.uiImage, "ImageRenderer gave no image")
    let attachment = XCTAttachment(data: try XCTUnwrap(image.pngData()), uniformTypeIdentifier: "public.png")
    attachment.name = "live-activity.png"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
