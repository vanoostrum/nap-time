import XCTest

/// Starts the app in test mode and drives the child screens.
@MainActor
struct AppDriver {
  let app = XCUIApplication()

  /// Starts the app with `--test-mode --seed <seed>`, and `--now <now>` when given,
  /// else the default test time.
  @discardableResult
  static func launch(seed: String, now: String? = nil) -> AppDriver {
    let driver = AppDriver()
    driver.app.launchArguments = ["--test-mode", "--seed", seed] + (now.map { ["--now", $0] } ?? [])
    driver.app.launch()
    return driver
  }

  /// The sky behind the home screen. Its value is "day" or "night".
  var sky: XCUIElement { app.descendants(matching: .any)["sky"] }

  /// Waits until the sky has this value, and fails the test when it does not.
  func waitForSky(_ value: String, file: StaticString = #filePath, line: UInt = #line) {
    waitFor(sky, file: file, line: line)
    let matches = NSPredicate(format: "value == %@", value)
    let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: matches, object: sky)], timeout: 10)
    XCTAssertEqual(result, .completed, "The sky is \(sky.value ?? "nil"), not \(value)", file: file, line: line)
  }

  func text(_ label: String) -> XCUIElement { app.staticTexts[label] }

  func button(_ label: String) -> XCUIElement { app.buttons[label] }

  var avatars: XCUIElementQuery { app.descendants(matching: .any).matching(identifier: "avatar") }

  /// Waits for an element and fails the test when it does not show.
  func waitFor(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(element.waitForExistence(timeout: 30), "Not found: \(element)", file: file, line: line)
  }

  /// Types into the name field and closes the keyboard.
  func typeName(_ name: String) {
    let field = app.textFields["name"]
    waitFor(field)
    field.tap()
    field.typeText(name + "\n")
  }

  /// Replaces the text in the name field and closes the keyboard.
  func replaceName(with name: String) {
    let field = app.textFields["name"]
    waitFor(field)
    field.tap()
    let old = (field.value as? String) ?? ""
    field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count + 2) + name + "\n")
  }

  /// Opens the birthdate sheet, sets the wheels, and taps Done.
  func setBirthDate(day: Int, month: String, year: Int) {
    button("birthdate").tap()
    let wheels = app.pickerWheels
    waitFor(wheels.firstMatch)
    XCTAssertEqual(wheels.count, 3)
    // Find each wheel by its value, since the order depends on the locale.
    var yearWheel: XCUIElement?
    var monthWheel: XCUIElement?
    var dayWheel: XCUIElement?
    for index in 0..<wheels.count {
      let wheel = wheels.element(boundBy: index)
      let value = (wheel.value as? String) ?? ""
      if let number = Int(value) {
        if number > 31 { yearWheel = wheel } else { dayWheel = wheel }
      } else {
        monthWheel = wheel
      }
    }
    yearWheel?.adjust(toPickerWheelValue: String(year))
    monthWheel?.adjust(toPickerWheelValue: month)
    dayWheel?.adjust(toPickerWheelValue: String(day))
    button("Done").tap()
    XCTAssertTrue(wheels.firstMatch.waitForNonExistence(timeout: 10))
  }

  /// Touches and holds a child's avatar, which opens Edit child.
  func openEdit(_ name: String) {
    let avatar = button(name)
    waitFor(avatar)
    avatar.press(forDuration: 1.2)
    waitFor(text("Edit child"))
  }

  func attachScreenshot(_ entryPoint: String, to testCase: XCTestCase) {
    let attachment = XCTAttachment(
      data: app.screenshot().pngRepresentation, uniformTypeIdentifier: "public.png")
    attachment.name = "\(entryPoint).png"
    attachment.lifetime = .keepAlways
    testCase.add(attachment)
  }
}
