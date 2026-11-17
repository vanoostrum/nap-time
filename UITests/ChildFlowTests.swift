import XCTest

/// Adds, selects, edits, and deletes children through the screens, in test mode.
/// Each test is a journey that launches the app once, because a launch costs CI time.
final class ChildFlowTests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// With no child: a name of only spaces is refused, the first child is added, "+" adds and selects
  /// a second child, tapping an avatar selects that child, and Cancel adds no child.
  @MainActor
  func testAddAndSelectChildren() throws {
    let driver = AppDriver.launch(seed: "none")
    driver.typeName("   ")
    XCTAssertFalse(driver.button("Add child").isEnabled)
    driver.setBirthDate(day: 12, month: "March", year: 2025)
    XCTAssertFalse(driver.button("Add child").isEnabled, "A name of only spaces is refused")
    driver.typeName("Lou")
    driver.button("Add Lou").tap()
    driver.waitFor(driver.text("Lou is awake"))
    XCTAssertEqual(driver.avatars.count, 1, "The first child is added")

    // "+" adds and selects a child.
    driver.button("Add a child").tap()
    driver.typeName("Noa")
    driver.setBirthDate(day: 5, month: "January", year: 2026)
    driver.button("Add Noa").tap()
    driver.waitFor(driver.text("Noa is awake"))
    XCTAssertEqual(driver.avatars.count, 2)

    // Tapping an avatar selects that child.
    driver.button("Lou").tap()
    driver.waitFor(driver.text("Lou is awake"))
    XCTAssertFalse(driver.text("Noa is awake").exists)

    // Cancel adds no child.
    driver.button("Add a child").tap()
    driver.waitFor(driver.text("Add a child"))
    driver.button("cancel").tap()
    driver.waitFor(driver.text("Lou is awake"))
    XCTAssertEqual(driver.avatars.count, 2, "Cancel adds no child")
  }

  /// Cancel in Edit child drops the changes, and Save keeps them.
  @MainActor
  func testEditChild() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.openEdit("Mila")
    driver.replaceName(with: "Mia")
    driver.button("cancel").tap()
    driver.waitFor(driver.text("Mila is awake"))
    XCTAssertFalse(driver.text("Mia is awake").exists, "Cancel drops the changes")

    driver.openEdit("Mila")
    driver.replaceName(with: "Mia")
    driver.button("Save").tap()
    driver.waitFor(driver.text("Mia is awake"))
  }

  /// Cancel on the confirmation keeps the child, deleting the selected child selects the first
  /// remaining child, and deleting the last child opens "Add your child".
  @MainActor
  func testDeleteChildren() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.openEdit("Mila")
    driver.button("Delete Mila").tap()
    driver.waitFor(driver.text("Delete Mila?"))
    driver.button("confirm-cancel").tap()
    XCTAssertTrue(driver.text("Delete Mila?").waitForNonExistence(timeout: 10))
    driver.button("cancel").tap()
    driver.waitFor(driver.text("Mila is awake"))
    XCTAssertEqual(driver.avatars.count, 2, "Cancel on the confirmation keeps the child")

    // Mila is selected. Deleting her selects Noah, the first remaining child.
    driver.openEdit("Mila")
    driver.button("Delete Mila").tap()
    driver.confirmDeleteChild()
    driver.waitFor(driver.text("Noah is awake"))
    XCTAssertEqual(driver.avatars.count, 1)

    // Deleting the last child opens "Add your child".
    driver.openEdit("Noah")
    driver.button("Delete Noah").tap()
    driver.confirmDeleteChild()
    driver.waitFor(driver.text("Add your child"))
  }
}
