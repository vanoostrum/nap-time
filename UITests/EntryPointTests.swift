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

  /// `home`: the home screen with Mila selected and awake, with the gear. Page `home/day.html`.
  @MainActor
  func testHome() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.waitFor(driver.text("Mila is awake"))
    XCTAssertEqual(driver.avatars.count, 2)
    XCTAssertTrue(driver.button("Add a child").exists)
    XCTAssertTrue(driver.text("since 06:55 · 11 h 10 m slept today").exists)
    XCTAssertTrue(driver.button("Sleep time").exists)
    XCTAssertTrue(driver.button("Add a sleep from earlier").exists)
    XCTAssertTrue(driver.button("Settings").exists)
    XCTAssertTrue(driver.button("Today").isSelected)
    XCTAssertTrue(driver.button("Charts").exists)
    driver.waitForSky("day")
    driver.attachScreenshot("home", to: self)
  }

  /// `settings`: Settings with Mila and Noah, not shared yet. Page `settings/default.html`.
  @MainActor
  func testSettings() throws {
    let driver = AppDriver.launch(seed: "family")
    driver.openSettings()
    XCTAssertEqual(driver.childRows, ["Mila", "Noah"])
    XCTAssertEqual(driver.childRowValues, ["1 year · 11–14 h", "4 years · 10–13 h"])
    XCTAssertTrue(driver.app.buttons["settings-add-child"].exists)
    XCTAssertTrue(driver.text("Not shared yet").exists)
    XCTAssertTrue(driver.text("Your partner sees and logs the same children and sleeps.").exists)
    XCTAssertTrue(driver.button("Invite your partner").exists)
    driver.attachScreenshot("settings", to: self)
  }

  /// `settings-shared`: Settings shared with Sam. Page `settings/shared.html`.
  @MainActor
  func testSettingsShared() throws {
    let driver = AppDriver.launch(seed: "shared")
    driver.openSettings()
    driver.waitFor(driver.text("Shared with Sam"))
    XCTAssertTrue(driver.text("You both see and log the same children and sleeps.").exists)
    XCTAssertTrue(driver.button("Manage sharing").exists)
    XCTAssertFalse(driver.button("Invite your partner").exists)
    driver.attachScreenshot("settings-shared", to: self)
  }

  /// `settings-invited`: Settings with an invite sent. Page `settings/invited.html`.
  @MainActor
  func testSettingsInvited() throws {
    let driver = AppDriver.launch(seed: "invited")
    driver.openSettings()
    driver.waitFor(driver.text("Invite sent"))
    XCTAssertTrue(driver.text("Waiting for your partner to open the link.").exists)
    XCTAssertTrue(driver.button("Manage sharing").exists)
    driver.attachScreenshot("settings-invited", to: self)
  }

  /// `settings-partner`: the partner's Settings, with Lou only on this phone. Page `settings/partner.html`.
  @MainActor
  func testSettingsPartner() throws {
    let driver = AppDriver.launch(seed: "partner")
    driver.openSettings()
    driver.waitFor(driver.text("Shared with you by Alex"))
    XCTAssertEqual(driver.childRows, ["Mila", "Noah", "Lou"])
    XCTAssertEqual(
      driver.childRowValues, ["1 year · 11–14 h", "4 years · 10–13 h", "2 years · 11–14 h, Only on this phone"])
    XCTAssertTrue(driver.button("Manage sharing").exists)
    XCTAssertFalse(driver.button("Invite your partner").exists)
    driver.attachScreenshot("settings-partner", to: self)
  }

  /// `settings-no-icloud`: Settings without an iCloud account. Page `settings/no-icloud.html`.
  @MainActor
  func testSettingsNoICloud() throws {
    let driver = AppDriver.launch(seed: "no-icloud")
    driver.openSettings()
    driver.waitFor(driver.text("Sign in to iCloud in the iPhone Settings to share with your partner."))
    XCTAssertTrue(driver.text("Not shared yet").exists)
    XCTAssertFalse(driver.app.buttons["share-button"].exists)
    driver.attachScreenshot("settings-no-icloud", to: self)
  }

  /// `joining`: "Joining the family…" before a shared child arrives. Page `family/joining.html`.
  @MainActor
  func testJoining() throws {
    let driver = AppDriver.launch(seed: "joining")
    driver.waitFor(driver.text("Joining the family…"))
    XCTAssertTrue(driver.text("This takes a few seconds.").exists)
    XCTAssertFalse(driver.text("Add your child").exists)
    driver.attachScreenshot("joining", to: self)
  }

  /// `joined`: "You joined the family" with Mila and Noah. Page `family/joined.html`.
  @MainActor
  func testJoined() throws {
    let driver = AppDriver.launch(seed: "joined")
    driver.waitFor(driver.text("You joined the family"))
    XCTAssertTrue(driver.text("You now see and log Mila and Noah, together with your partner.").exists)
    XCTAssertTrue(driver.button("Start").exists)
    driver.attachScreenshot("joined", to: self)
  }

  /// `home-sleeping`: Mila sleeps a night since 19:42, at 23:30, so the night sky shows. Page `home/night.html`.
  @MainActor
  func testHomeSleeping() throws {
    let driver = AppDriver.launch(seed: "sleeping", now: "2026-06-21T23:30:00+02:00")
    driver.waitFor(driver.text("Mila is sleeping"))
    XCTAssertTrue(driver.text("3 h 48 m · since 19:42").exists)
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

  /// `home-sunset`: Mila awake at 22:05 on 21 June, just after sunset. Page `home/sunset.html`.
  @MainActor
  func testHomeSunset() throws {
    try awakeAtHome(
      "home-sunset", seed: "evening", now: "2026-06-21T22:05:00+02:00",
      line: "since 15:10 · 12 h 05 m slept today", sky: "sunset")
  }

  /// `home-night-awake`: Mila awake at 23:30 on 21 June. Page `home/night-awake.html`.
  @MainActor
  func testHomeNightAwake() throws {
    try awakeAtHome(
      "home-night-awake", seed: "evening", now: "2026-06-21T23:30:00+02:00",
      line: "since 15:10 · 12 h 05 m slept today", sky: "night")
  }

  /// `home-sunrise`: Mila awake at 08:00 on 15 November, at sunrise. Page `home/sunrise.html`.
  @MainActor
  func testHomeSunrise() throws {
    try awakeAtHome(
      "home-sunrise", seed: "winter-morning", now: "2026-11-15T08:00:00+01:00",
      line: "since 06:40 · 10 h 52 m slept today", sky: "sunrise")
  }

  /// The home screen with Mila awake, checked and saved as an entry point.
  @MainActor
  private func awakeAtHome(_ entryPoint: String, seed: String, now: String, line: String, sky: String) throws {
    let driver = AppDriver.launch(seed: seed, now: now)
    driver.waitFor(driver.text("Mila is awake"))
    XCTAssertEqual(driver.avatars.count, 2)
    XCTAssertTrue(driver.text(line).exists)
    XCTAssertTrue(driver.button("Sleep time").exists)
    XCTAssertTrue(driver.button("Add a sleep from earlier").exists)
    XCTAssertTrue(driver.button("Today").isSelected)
    XCTAssertTrue(driver.button("Charts").exists)
    driver.waitForSky(sky)
    driver.attachScreenshot(entryPoint, to: self)
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

  /// `charts`: Mila's whole week on Sunday 8 November at 19:30. Page `charts/week.html`, without "When Mila slept".
  @MainActor
  func testCharts() throws {
    let driver = AppDriver.launch(seed: "week", now: "2026-11-08T19:30:00+01:00")
    driver.openCharts()
    driver.waitFor(driver.text("Mila's week"))
    XCTAssertTrue(driver.text("Mon 2 – Sun 8 Nov").exists)
    XCTAssertTrue(driver.text("12 h 09 m").exists)
    XCTAssertTrue(driver.text("range 11–14 h").exists)
    XCTAssertTrue(driver.text("4 of 7 days").exists)
    XCTAssertTrue(driver.text("bed ~19:45 · up ~06:30").exists)
    XCTAssertEqual(driver.bars.count, 7)
    XCTAssertEqual(
      driver.barValues, ["in range", "too little", "in range", "in range", "too little", "in range", "too much"])
    XCTAssertEqual(driver.bars.element(boundBy: 0).label, "Monday 2 Nov, 12 h 36 m")
    XCTAssertEqual(driver.bars.element(boundBy: 6).label, "Sunday 8 Nov, 14 h 24 m")
    XCTAssertFalse(driver.text("so far").exists)
    XCTAssertTrue(driver.button("Previous week").isEnabled)
    XCTAssertTrue(driver.button("Next week").isEnabled)
    XCTAssertTrue(driver.button("Charts").isSelected)
    XCTAssertTrue(driver.text("When Mila slept").exists)
    XCTAssertEqual(driver.rows.count, 7)
    XCTAssertEqual(driver.rows.element(boundBy: 0).label, "Monday 2 Nov details")
    XCTAssertEqual(driver.rows.element(boundBy: 6).label, "Sunday 8 Nov details")
    driver.attachScreenshot("charts", to: self)
  }

  /// `charts-today`: Mila's current week on Wednesday 11 November at 10:00. Page `charts/week-today.html`,
  /// without "When Mila slept".
  @MainActor
  func testChartsToday() throws {
    let driver = AppDriver.launch(seed: "week-today", now: "2026-11-11T10:00:00+01:00")
    driver.openCharts()
    driver.waitFor(driver.text("Mon 9 – Sun 15 Nov"))
    XCTAssertTrue(driver.text("11 h 27 m").exists)
    XCTAssertTrue(driver.text("1 of 2 days").exists)
    XCTAssertTrue(driver.text("bed ~19:50 · up ~06:30").exists)
    XCTAssertEqual(driver.barValues, ["in range", "too little", "so far"])
    XCTAssertEqual(driver.bars.element(boundBy: 2).label, "Wednesday 11 Nov, 10 h 50 m so far")
    XCTAssertTrue(driver.text("so far").exists)
    XCTAssertTrue(driver.button("Previous week").isEnabled)
    XCTAssertFalse(driver.button("Next week").isEnabled)
    XCTAssertTrue(driver.text("When Mila slept").exists)
    XCTAssertEqual(
      (0..<driver.rows.count).map { driver.rows.element(boundBy: $0).label },
      ["Monday 9 Nov details", "Tuesday 10 Nov details", "Wednesday 11 Nov details"])
    driver.attachScreenshot("charts-today", to: self)
  }

  /// `charts-empty`: Noah's current week, with no sleeps. Page `charts/empty.html`.
  @MainActor
  func testChartsEmpty() throws {
    let driver = AppDriver.launch(seed: "week", now: "2026-11-11T10:00:00+01:00")
    driver.button("Noah").tap()
    driver.waitFor(driver.text("Noah is awake"))
    driver.openCharts()
    driver.waitFor(driver.text("Noah's week"))
    XCTAssertTrue(driver.text("Mon 9 – Sun 15 Nov").exists)
    XCTAssertEqual(driver.app.staticTexts.matching(NSPredicate(format: "label == %@", "–")).count, 2)
    XCTAssertTrue(driver.text("range 10–13 h").exists)
    XCTAssertTrue(driver.text("no sleeps yet").exists)
    XCTAssertTrue(driver.text("No sleeps this week").exists)
    XCTAssertTrue(driver.text("Log Noah's sleeps on the Today tab, or add one from earlier.").exists)
    XCTAssertTrue(driver.button("Add a sleep").exists)
    XCTAssertEqual(driver.bars.count, 0)
    XCTAssertFalse(driver.whatToTry.exists)
    XCTAssertTrue(driver.button("Previous week").isEnabled)
    XCTAssertFalse(driver.button("Next week").isEnabled)
    driver.attachScreenshot("charts-empty", to: self)
  }

  /// `live-activity`: the night card of the sleep timer for the seed `sleeping`, at 04:10:14. A UI test cannot open a
  /// Live Activity, so it renders the card's view (ADR 0003). Page `live-activity/lock-screen.html`.
  @MainActor
  func testLiveActivity() throws {
    let face = try SleepTimerRender.face(seed: .sleeping, pauseTime: "2026-06-22T04:10:14+02:00")
    XCTAssertEqual(face.heading, "Mila is sleeping")
    XCTAssertEqual(face.since, "since 19:42")
    XCTAssertEqual(face.kind, .night)
    try SleepTimerRender.attach(SleepTimerRender.card(face), as: "live-activity", to: self)
  }

  /// `live-activity-nap`: the nap card of the sleep timer for the seed `napping`, at 13:50:12.
  /// Page `live-activity/nap.html`.
  @MainActor
  func testLiveActivityNap() throws {
    let face = try SleepTimerRender.face(seed: .napping, pauseTime: "2026-06-21T13:50:12+02:00")
    XCTAssertEqual(face.heading, "Mila is sleeping")
    XCTAssertEqual(face.since, "since 13:05")
    XCTAssertEqual(face.kind, .nap)
    try SleepTimerRender.attach(SleepTimerRender.card(face), as: "live-activity-nap", to: self)
  }

  /// `dynamic-island`: the compact, minimal, and expanded Dynamic Island for the seed `sleeping`, at 04:10:14.
  /// Page `live-activity/dynamic-island.html`.
  @MainActor
  func testDynamicIsland() throws {
    let face = try SleepTimerRender.face(seed: .sleeping, pauseTime: "2026-06-22T04:10:14+02:00")
    try SleepTimerRender.attach(SleepTimerRender.island(face), as: "dynamic-island", to: self)
  }

  /// Criterion 3: the sheet of a counted day, from Tuesday's bar.
  @MainActor
  func testDaySheet() throws {
    let driver = AppDriver.launch(seed: "week", now: "2026-11-08T19:30:00+01:00")
    driver.openCharts()
    driver.openDaySheet(bar: 1, title: "Tuesday 3 Nov")
    XCTAssertTrue(driver.text("10 h 12 m slept in total").exists)
    XCTAssertTrue(driver.text("Too little").exists)
    XCTAssertTrue(driver.text("20:54 → 06:12").exists)
    XCTAssertTrue(driver.text("9 h 18 m").exists)
    XCTAssertTrue(driver.text("13:30 → 14:24").exists)
    XCTAssertTrue(driver.text("54 m").exists)
    XCTAssertTrue(driver.button("Edit night").exists)
    XCTAssertTrue(driver.button("Edit nap").exists)
    XCTAssertTrue(driver.button("+ Add a sleep to this day").exists)
    driver.attachScreenshot("day-sheet", to: self)
  }

  /// Criterion 4: the sheet of the current day, from Wednesday's striped bar.
  @MainActor
  func testDaySheetToday() throws {
    let driver = AppDriver.launch(seed: "week-today", now: "2026-11-11T10:00:00+01:00")
    driver.openCharts()
    driver.openDaySheet(bar: 2, title: "Wednesday 11 Nov")
    XCTAssertTrue(driver.text("10 h 50 m slept so far").exists)
    XCTAssertTrue(driver.text("So far").exists)
    XCTAssertTrue(driver.text("19:50 → 06:40").exists)
    XCTAssertTrue(driver.button("+ Add a sleep to this day").exists)
    driver.attachScreenshot("day-sheet-today", to: self)
  }

  /// Criterion 5: the sheet of a past day with no sleeps, from Noah's Monday row.
  @MainActor
  func testDaySheetEmpty() throws {
    let driver = AppDriver.launch(seed: "week", now: "2026-11-08T19:30:00+01:00")
    driver.button("Noah").tap()
    driver.waitFor(driver.text("Noah is awake"))
    driver.openCharts()
    driver.waitFor(driver.text("When Noah slept"))
    XCTAssertEqual(driver.rows.count, 7)
    driver.openDaySheet(row: "Monday 2 Nov details", title: "Monday 2 Nov")
    XCTAssertTrue(driver.text("No sleeps logged").exists)
    XCTAssertFalse(driver.text("So far").exists)
    XCTAssertTrue(driver.button("+ Add a sleep to this day").exists)
    driver.attachScreenshot("day-sheet-empty", to: self)
  }

  /// `what-to-try`: the Charts tab of a whole past week, scrolled to the end. Page `charts/what-to-try.html`.
  @MainActor
  func testWhatToTry() throws {
    let driver = AppDriver.launch(seed: "week", now: "2026-11-08T19:30:00+01:00")
    driver.openCharts()
    driver.scrollToWhatToTry()
    XCTAssertTrue(driver.text("What to try").exists)
    XCTAssertEqual(
      driver.tip.label,
      "Mila's bedtime moved around by about 40 minutes this week. Try a fixed bedtime between 19:10 and 19:40.")
    assertGeneralTipsAndDoctorLine(driver)
    XCTAssertFalse(driver.button("Add a sleep from earlier").exists)
    driver.attachScreenshot("what-to-try", to: self)
  }

  /// `what-to-try-keep-logging`: the Charts tab of the current week with 2 counted days, scrolled to the end.
  /// Page `charts/keep-logging.html`. Then "Add a sleep from earlier" opens Add sleep from now (criterion 3).
  @MainActor
  func testWhatToTryKeepLogging() throws {
    let driver = AppDriver.launch(seed: "week-today", now: "2026-11-11T10:00:00+01:00")
    driver.openCharts()
    driver.scrollToWhatToTry()
    XCTAssertEqual(
      driver.tip.label,
      "Keep logging. With sleeps on 4 days of the week, Nap Time shows what to try for Mila. 2 of 4 days so far.")
    assertGeneralTipsAndDoctorLine(driver)
    XCTAssertTrue(driver.button("Add a sleep from earlier").isHittable)
    driver.attachScreenshot("what-to-try-keep-logging", to: self)

    driver.button("Add a sleep from earlier").tap()
    driver.waitFor(driver.app.descendants(matching: .any)["sleep-form"])
    XCTAssertEqual(driver.button("fell-asleep").label, "Wed 11 Nov · 09:00")
    XCTAssertEqual(driver.button("woke-up").label, "Wed 11 Nov · 10:00")
    XCTAssertTrue(driver.button("Nap").isSelected)
  }

  @MainActor
  private func assertGeneralTipsAndDoctorLine(
    _ driver: AppDriver, file: StaticString = #filePath, line: UInt = #line
  ) {
    for text in [
      "Start a calm wind-down 30 minutes before bed.",
      "Keep the same wake-up time, also at the weekend.",
      "End the last nap at least 3 hours before bedtime.",
      "These are general tips. If you are worried about Mila's sleep, ask your doctor.",
    ] {
      XCTAssertTrue(driver.text(text).exists, "Not found: \(text)", file: file, line: line)
    }
  }
}
