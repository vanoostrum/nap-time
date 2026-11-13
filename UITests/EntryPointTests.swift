import SwiftUI
import XCTest

/// Saves one screenshot per entry point as an attachment named `<entry point>.png`.
/// The `Screenshots` CI job exports them into the `screenshots` artifact.
final class EntryPointTests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  func testHome() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--test-mode"]
    app.launch()

    XCTAssertTrue(app.descendants(matching: .any)["home"].waitForExistence(timeout: 30))
    XCTAssertTrue(app.staticTexts["Nap Time"].exists)
    attach(png: app.screenshot().pngRepresentation, entryPoint: "home")
  }

  /// A UI test cannot open a Live Activity, so it renders the Lock Screen view (ADR 0003).
  @MainActor
  func testLiveActivity() throws {
    let renderer = ImageRenderer(content: LiveActivityView().frame(width: 360, height: 120))
    renderer.scale = 3
    let image = try XCTUnwrap(renderer.uiImage, "ImageRenderer gave no image")
    attach(png: try XCTUnwrap(image.pngData()), entryPoint: "live-activity")
  }

  private func attach(png: Data, entryPoint: String) {
    let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
    attachment.name = "\(entryPoint).png"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
