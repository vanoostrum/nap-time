import XCTest

/// Adds, selects, edits, and deletes children through the screens, in test mode.
final class ChildFlowTests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  func testFirstLaunchAddsAChild() throws {
    let driver = AppDriver.launch(seed: "none")
    driver.typeName("   ")
    XCTAssertFalse(driver.button("Add child").isEnabled)
    driver.setBirthDate(day: 12, month: "March", year: 2025)
    XCTAssertFalse(driver.button("Add child").isEnabled, "A name of only spaces is refused")
    driver.typeName("Lou")
    driver.button("Add Lou").tap()
    driver.waitFor(driver.text("Lou is awake"))
    XCTAssertEqual(driver.avatars.count, 1)
  }

  @MainActor
  func testCancelAddsNoChild() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.waitFor(driver.text("Mila is awake"))
    driver.button("Add a child").tap()
    driver.waitFor(driver.text("Add a child"))
    driver.button("cancel").tap()
    driver.waitFor(driver.text("Mila is awake"))
    XCTAssertEqual(driver.avatars.count, 2)
  }

  @MainActor
  func testPlusAddsAndSelectsAChild() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.waitFor(driver.button("Add a child"))
    driver.button("Add a child").tap()
    driver.typeName("Lou")
    driver.setBirthDate(day: 5, month: "January", year: 2026)
    driver.button("Add Lou").tap()
    driver.waitFor(driver.text("Lou is awake"))
    XCTAssertEqual(driver.avatars.count, 3)
  }

  @MainActor
  func testTappingAnAvatarSelectsThatChild() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.waitFor(driver.text("Mila is awake"))
    driver.button("Noah").tap()
    driver.waitFor(driver.text("Noah is awake"))
    XCTAssertFalse(driver.text("Mila is awake").exists)
  }

  @MainActor
  func testCancelInEditChildDropsTheChanges() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.openEdit("Mila")
    driver.replaceName(with: "Mia")
    driver.button("cancel").tap()
    driver.waitFor(driver.text("Mila is awake"))
    XCTAssertFalse(driver.text("Mia is awake").exists)
  }

  @MainActor
  func testSaveInEditChildKeepsTheChanges() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.openEdit("Mila")
    driver.replaceName(with: "Mia")
    driver.button("Save").tap()
    driver.waitFor(driver.text("Mia is awake"))
  }

  @MainActor
  func testCancelOnTheConfirmationKeepsTheChild() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.openEdit("Mila")
    driver.button("Delete Mila").tap()
    driver.waitFor(driver.text("Delete Mila?"))
    driver.button("confirm-cancel").tap()
    XCTAssertTrue(driver.text("Delete Mila?").waitForNonExistence(timeout: 10))
    driver.button("cancel").tap()
    driver.waitFor(driver.text("Mila is awake"))
    XCTAssertEqual(driver.avatars.count, 2)
  }

  @MainActor
  func testDeletingTheSelectedChildSelectsTheFirstRemainingChild() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.openEdit("Mila")
    driver.button("Delete Mila").tap()
    driver.button("confirm-delete").tap()
    driver.waitFor(driver.text("Noah is awake"))
    XCTAssertEqual(driver.avatars.count, 1)
  }

  @MainActor
  func testDeletingTheLastChildOpensAddYourChild() throws {
    let driver = AppDriver.launch(seed: "long-name")
    driver.openEdit("Maximiliana Rosalind Pepperpot")
    driver.button("Delete Maximiliana Rosalind Pepperpot").tap()
    driver.button("confirm-delete").tap()
    driver.waitFor(driver.text("Add your child"))
  }
}
