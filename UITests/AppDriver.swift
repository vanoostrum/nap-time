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
    // A busy CI simulator sometimes drops the synthesized press (seen in CRAFT-43 and CRAFT-44 runs),
    // so press once more. The test still fails when Edit child does not open.
    if !text("Edit child").waitForExistence(timeout: 10) {
      avatar.press(forDuration: 1.2)
    }
    waitFor(text("Edit child"))
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
      app.descendants(matching: .any)["sleep-form"].waitForNonExistence(timeout: 10), "The sleep form is still open",
      file: file,
      line: line)
  }

  /// Taps the Charts tab and waits for the Charts screen.
  func openCharts() {
    let tab = button("Charts")
    waitFor(tab)
    tab.tap()
    waitFor(app.descendants(matching: .any)["charts"])
  }

  /// Taps the Today tab and waits for the home screen.
  func openToday() {
    let tab = button("Today")
    waitFor(tab)
    tab.tap()
    waitFor(app.descendants(matching: .any)["home"])
  }

  /// The bars of "Hours per day", Monday first. Each label is "<weekday> <day> <month>, <duration>".
  var bars: XCUIElementQuery { app.descendants(matching: .any).matching(identifier: "bar") }

  /// The value of each bar: "in range", "too little", "too much", or "so far".
  var barValues: [String] {
    (0..<bars.count).map { (bars.element(boundBy: $0).value as? String) ?? "" }
  }

  /// The rows of the timeline "When <name> slept", Monday first. Each label is "<weekday> <day> <month> details".
  var rows: XCUIElementQuery { app.descendants(matching: .any).matching(identifier: "row") }

  /// The open day sheet.
  var daySheet: XCUIElement { app.descendants(matching: .any)["day-sheet"] }

  /// Taps a timeline row, such as "Tuesday 3 Nov details", and waits for the day sheet with that day's title.
  func openDaySheet(row label: String, title: String, file: StaticString = #filePath, line: UInt = #line) {
    let row = rows.matching(NSPredicate(format: "label == %@", label)).firstMatch
    waitFor(row, file: file, line: line)
    row.tap()
    waitFor(daySheet, file: file, line: line)
    waitFor(text(title), file: file, line: line)
  }

  /// Taps a bar of "Hours per day", Monday first, and waits for the day sheet with that day's title.
  func openDaySheet(bar index: Int, title: String, file: StaticString = #filePath, line: UInt = #line) {
    let bar = bars.element(boundBy: index)
    waitFor(bar, file: file, line: line)
    bar.tap()
    waitFor(daySheet, file: file, line: line)
    waitFor(text(title), file: file, line: line)
  }

  /// Waits until the day sheet has closed.
  func waitForDaySheetToClose(file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(daySheet.waitForNonExistence(timeout: 10), "The day sheet is still open", file: file, line: line)
  }

  /// Taps the dimmed charts above the day sheet.
  func tapDimmedCharts() {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
  }

  /// Taps the gear on the home screen and waits for Settings.
  func openSettings() {
    let gear = button("Settings")
    waitFor(gear)
    gear.tap()
    waitFor(app.descendants(matching: .any)["settings"])
  }

  /// The child rows in Settings, by name, top first.
  var childRows: [String] {
    let rows = app.descendants(matching: .any).matching(identifier: "child-row")
    return (0..<rows.count).map { rows.element(boundBy: $0).label }
  }

  /// The second line of each child row in Settings, top first, such as "1 year · 11–14 h", with
  /// ", Only on this phone" for a child only on this phone.
  var childRowValues: [String] {
    let rows = app.descendants(matching: .any).matching(identifier: "child-row")
    return (0..<rows.count).map { (rows.element(boundBy: $0).value as? String) ?? "" }
  }

  /// Taps a child's row in Settings and waits for Edit child.
  func openChildRow(_ name: String) {
    let row = app.descendants(matching: .any).matching(identifier: "child-row")
      .matching(NSPredicate(format: "label == %@", name)).firstMatch
    waitFor(row)
    row.tap()
    waitFor(text("Edit child"))
  }

  /// Waits for an alert with this title, and fails the test when it does not show.
  func waitForAlert(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
    waitFor(app.alerts[title], file: file, line: line)
  }

  func attachScreenshot(_ entryPoint: String, to testCase: XCTestCase) {
    let attachment = XCTAttachment(
      data: app.screenshot().pngRepresentation, uniformTypeIdentifier: "public.png")
    attachment.name = "\(entryPoint).png"
    attachment.lifetime = .keepAlways
    testCase.add(attachment)
  }
}
