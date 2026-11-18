import XCTest

/// Settings and sharing the family through the screens, in test mode. Test mode has no CloudKit, so the iCloud
/// sharing sheet never opens: invite and manage show their failure alerts.
final class SharingFlowTests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  func testTheGearOpensSettingsAndDoneClosesIt() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.openSettings()
    driver.button("Done").tap()
    driver.waitFor(driver.text("Mila is awake"))
    XCTAssertTrue(driver.app.descendants(matching: .any)["settings"].waitForNonExistence(timeout: 10))
  }

  @MainActor
  func testAChildRowOpensEditChild() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.openSettings()
    driver.openChildRow("Mila")
    XCTAssertEqual(driver.app.textFields["name"].value as? String, "Mila")
    driver.button("cancel").tap()
    driver.waitFor(driver.text("Not shared yet"))
  }

  @MainActor
  func testAddAChildFromSettingsAndCancel() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.openSettings()
    driver.app.buttons["settings-add-child"].tap()
    driver.waitFor(driver.text("Add a child"))
    driver.button("cancel").tap()
    driver.waitFor(driver.text("Not shared yet"))
    XCTAssertEqual(driver.childRows, ["Mila", "Noah"])
  }

  @MainActor
  func testAChildAddedFromSettingsIsListed() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.openSettings()
    driver.app.buttons["settings-add-child"].tap()
    driver.typeName("Lou")
    driver.setBirthDate(day: 5, month: "January", year: 2026)
    driver.button("Add Lou").tap()
    driver.waitFor(driver.text("Not shared yet"))
    XCTAssertEqual(driver.childRows, ["Mila", "Noah", "Lou"])
  }

  @MainActor
  func testInviteWithoutCloudKitShowsTheInviteAlert() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.openSettings()
    driver.button("Invite your partner").tap()
    driver.waitForAlert("Could not start the invite")
    XCTAssertTrue(driver.app.alerts.staticTexts["Check your connection and try again."].exists)
    driver.app.alerts.buttons["OK"].tap()
    driver.waitFor(driver.text("Not shared yet"))
  }

  @MainActor
  func testManageSharingWithoutCloudKitShowsTheSharingAlert() throws {
    let driver = AppDriver.launch(seed: "shared")
    driver.openSettings()
    driver.button("Manage sharing").tap()
    driver.waitForAlert("Could not open sharing")
    driver.app.alerts.buttons["OK"].tap()
    driver.waitFor(driver.text("Shared with Sam"))
  }

  @MainActor
  func testThePartnerDeletesLouOnlyOnThisPhone() throws {
    let driver = AppDriver.launch(seed: "partner")
    driver.openSettings()
    XCTAssertEqual(driver.childRows, ["Mila", "Noah", "Lou"])
    XCTAssertFalse(driver.button("Invite your partner").exists)
    driver.openChildRow("Lou")
    driver.button("Delete Lou").tap()
    driver.waitFor(driver.text("Delete Lou?"))
    XCTAssertTrue(driver.text("This deletes Lou and all of Lou's sleeps, on this phone. You cannot undo this.").exists)
  }

  @MainActor
  func testDeletingTheOnlyChildFromSettingsOpensAddYourChild() throws {
    let driver = AppDriver.launch(seed: "long-name")
    driver.openSettings()
    driver.openChildRow("Maximiliana Rosalind Pepperpot")
    driver.button("Delete Maximiliana Rosalind Pepperpot").tap()
    driver.app.buttons["confirm-delete"].tap()
    driver.waitFor(driver.text("Add your child"))
  }

  @MainActor
  func testWithoutICloudAChildStillSaves() throws {
    let driver = AppDriver.launch(seed: "no-icloud")
    driver.openSettings()
    XCTAssertFalse(driver.app.buttons["share-button"].exists)
    driver.app.buttons["settings-add-child"].tap()
    driver.typeName("Lou")
    driver.setBirthDate(day: 5, month: "January", year: 2026)
    driver.button("Add Lou").tap()
    driver.waitFor(driver.text("Not shared yet"))
    driver.button("Done").tap()
    driver.waitFor(driver.text("Lou is awake"))
  }

  @MainActor
  func testStartOpensTheHomeScreen() throws {
    let driver = AppDriver.launch(seed: "joined")
    driver.waitFor(driver.text("You joined the family"))
    driver.button("Start").tap()
    driver.waitFor(driver.text("Mila is awake"))
  }
}
