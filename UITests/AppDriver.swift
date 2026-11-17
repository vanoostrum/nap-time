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

  /// The sky behind the home screen. Its value is "day", "sunset", "night", or "sunrise".
  var sky: XCUIElement { app.descendants(matching: .any)["sky"] }

  /// Waits until the sky has this value, and fails the test when it does not.
  func waitForSky(_ value: String, file: StaticString = #filePath, line: UInt = #line) {
    waitFor(sky, file: file, line: line)
    if (sky.value as? String) == value { return }
    let matches = NSPredicate(format: "value == %@", value)
    let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: matches, object: sky)], timeout: 10)
    XCTAssertEqual(result, .completed, "The sky is \(sky.value ?? "nil"), not \(value)", file: file, line: line)
  }

  /// An element with this label: a text, or a button whose label is that text, such as the status line.
  func text(_ label: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
  }

  func button(_ label: String) -> XCUIElement { app.buttons[label] }

  var avatars: XCUIElementQuery { app.descendants(matching: .any).matching(identifier: "avatar") }

  /// Waits for an element and fails the test when it does not show.
  func waitFor(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(element.appears(within: 30), "Not found: \(element)", file: file, line: line)
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
    XCTAssertTrue(wheels.firstMatch.disappears(within: 10))
  }

  /// Touches and holds a child's avatar, which opens Edit child.
  func openEdit(_ name: String) {
    let avatar = button(name)
    waitFor(avatar)
    avatar.press(forDuration: 1.2)
    // A busy CI simulator sometimes drops the synthesized press (seen in CRAFT-43 and CRAFT-44 runs),
    // so press once more. The test still fails when Edit child does not open.
    if !text("Edit child").appears(within: 10) {
      avatar.press(forDuration: 1.2)
    }
    waitFor(text("Edit child"))
  }

  /// Taps Delete on the delete confirmation of Edit child, after it shows and can take a tap.
  /// Every UI test that deletes a child uses this: a tap before the confirmation shows fails on a busy simulator.
  func confirmDeleteChild(file: StaticString = #filePath, line: UInt = #line) {
    let confirm = app.buttons["confirm-delete"]
    waitFor(confirm, file: file, line: line)
    if confirm.isHittable {
      confirm.tap()
      return
    }
    let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: confirm)
    XCTAssertEqual(
      XCTWaiter().wait(for: [hittable], timeout: 10), .completed, "confirm-delete cannot take a tap", file: file,
      line: line)
    confirm.tap()
  }

  /// Taps the home screen's status line, which opens the running sleep or the last sleep.
  func tapStatusLine(_ line: String) {
    let status = app.buttons["status-line"]
    waitFor(status)
    XCTAssertEqual(status.label, line)
    status.tap()
    waitFor(app.descendants(matching: .any)["sleep-form"])
  }

  /// Taps "Add a sleep from earlier" or "Woke earlier? Set the time" below the main button.
  func tapSleepLink(_ label: String) {
    let link = button(label)
    waitFor(link)
    link.tap()
    waitFor(app.descendants(matching: .any)["sleep-form"])
  }

  /// Waits until the sleep form has closed.
  func waitForFormToClose(file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(
      app.descendants(matching: .any)["sleep-form"].disappears(within: 10), "The sleep form is still open",
      file: file,
      line: line)
  }

  func attachScreenshot(_ entryPoint: String, to testCase: XCTestCase) {
    let attachment = XCTAttachment(
      data: app.screenshot().pngRepresentation, uniformTypeIdentifier: "public.png")
    attachment.name = "\(entryPoint).png"
    attachment.lifetime = .keepAlways
    testCase.add(attachment)
  }
}

@MainActor
extension XCUIElement {
  /// True when the element shows within the timeout. Checks at once first: `waitForExistence`
  /// checks only after one second, even when the element is already there, and the UI tests wait often.
  func appears(within timeout: TimeInterval) -> Bool {
    exists || waitForExistence(timeout: timeout)
  }

  /// True when the element is gone within the timeout. Checks at once first, as `appears(within:)` does.
  func disappears(within timeout: TimeInterval) -> Bool {
    !exists || waitForNonExistence(timeout: timeout)
  }
}
