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

  /// `home`: the home screen with Mila selected. Page `home/day.html`.
  @MainActor
  func testHome() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.waitFor(driver.text("Mila is awake"))
    XCTAssertEqual(driver.avatars.count, 2)
    XCTAssertTrue(driver.button("Add a child").exists)
    driver.attachScreenshot("home", to: self)
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
