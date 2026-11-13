import XCTest

/// The only UI test outside test mode. The unsigned CI build has no App Group and no iCloud,
/// so the family store fails to load. The home screen must still show.
final class NormalModeLaunchTests: XCTestCase {
  @MainActor
  func testNormalModeLaunch() throws {
    let app = XCUIApplication()
    app.launchArguments = []
    app.launch()

    XCTAssertTrue(app.descendants(matching: .any)["home"].waitForExistence(timeout: 60))
    XCTAssertEqual(app.state, .runningForeground)
  }
}
