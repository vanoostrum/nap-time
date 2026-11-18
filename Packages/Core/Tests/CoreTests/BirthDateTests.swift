import Core
import Foundation
import Testing

@Suite struct BirthDateTests {
  @Test func refusesDatesThatDoNotExist() {
    #expect(BirthDate(year: 2025, month: 2, day: 29) == nil)
    #expect(BirthDate(year: 2024, month: 2, day: 29) != nil)
    #expect(BirthDate(year: 2025, month: 4, day: 31) == nil)
    #expect(BirthDate(year: 2025, month: 13, day: 1) == nil)
    #expect(BirthDate(year: 2025, month: 1, day: 0) == nil)
  }

  @Test func showsTheDayTheMonthAndTheYear() {
    #expect(day(2025, 3, 12).description == "12 March 2025")
    #expect(day(2022, 2, 10).description == "10 February 2022")
  }

  @Test func ordersByDate() {
    #expect(day(2025, 3, 12) < day(2025, 3, 13))
    #expect(day(2024, 12, 31) < day(2025, 1, 1))
  }

  @Test func addsDaysOverMonthsAndYears() {
    #expect(day(2025, 2, 28).adding(days: 1) == day(2025, 3, 1))
    #expect(day(2024, 2, 28).adding(days: 1) == day(2024, 2, 29))
    #expect(day(2025, 12, 31).adding(days: 1) == day(2026, 1, 1))
    #expect(day(2026, 1, 1).adding(days: -1) == day(2025, 12, 31))
  }

  @Test func subtractingYearsFromTheLeapDayGivesTheLastDayOfFebruary() {
    #expect(day(2028, 2, 29).subtracting(years: 7) == day(2021, 2, 28))
    #expect(day(2026, 6, 21).subtracting(years: 7) == day(2019, 6, 21))
  }

  @Test func readsTheCalendarDateOfAnInstantInTheTimeZone() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "Europe/Amsterdam"))
    // 2026-06-20T23:30:00Z is already 21 June in Amsterdam.
    let instant = Date(timeIntervalSince1970: 1_781_998_200)
    #expect(BirthDate(instant, in: calendar) == day(2026, 6, 21))
    #expect(BirthDate(day(2025, 3, 12).date(in: calendar), in: calendar) == day(2025, 3, 12))
  }

  // MARK: Age text

  @Test(arguments: [
    (day(2026, 6, 21), "Mila is 0 days old"),
    (day(2026, 6, 20), "Mila is 1 day old"),
    (day(2026, 6, 15), "Mila is 6 days old"),
    (day(2026, 6, 14), "Mila is 1 week old"),
    (day(2026, 5, 22), "Mila is 4 weeks old"),
    (day(2026, 5, 21), "Mila is 1 month old"),
    (day(2025, 6, 22), "Mila is 11 months old"),
    (day(2025, 6, 21), "Mila is 1 year old"),
    (day(2025, 3, 12), "Mila is 1 year old"),
    (day(2022, 2, 10), "Mila is 4 years old"),
  ])
  func ageText(birthDate: BirthDate, expected: String) {
    #expect(Age(of: birthDate, on: day(2026, 6, 21)).sentence(name: "Mila") == expected)
  }

  @Test func reachesAMonthOnTheLastDayOfAShorterMonth() {
    // Born on 31 October, 4 months old on 28 February, or on 29 February in a leap year.
    #expect(Age(of: day(2026, 10, 31), on: day(2027, 2, 27)).months == 3)
    #expect(Age(of: day(2026, 10, 31), on: day(2027, 2, 28)).months == 4)
    #expect(Age(of: day(2027, 10, 31), on: day(2028, 2, 28)).months == 3)
    #expect(Age(of: day(2027, 10, 31), on: day(2028, 2, 29)).months == 4)
  }

  @Test func aLeapDayChildTurnsOneOnTheLastDayOfFebruary() {
    #expect(Age(of: day(2024, 2, 29), on: day(2025, 2, 27)).years == 0)
    #expect(Age(of: day(2024, 2, 29), on: day(2025, 2, 28)).years == 1)
  }

  @Test func hintGivesTheAgeAndTheRange() {
    #expect(
      ChildHint.text(name: "Mila", birthDate: day(2025, 3, 12), today: day(2026, 6, 21))
        == "Mila is 1 year old. The range is 11–14 h of sleep a day.")
    #expect(
      ChildHint.text(name: "Noah", birthDate: day(2022, 2, 10), today: day(2026, 6, 21))
        == "Noah is 4 years old. The range is 10–13 h of sleep a day.")
  }

  // MARK: Limits

  @Test func addAllowsTheDayAfterTheDateSevenYearsAgoUpToToday() {
    let limits = BirthDateLimits.forAdding(today: day(2026, 6, 21))
    #expect(limits.lowerBound == day(2019, 6, 22))
    #expect(limits.upperBound == day(2026, 6, 21))
    #expect(!limits.contains(day(2019, 6, 21)))
    #expect(limits.contains(day(2019, 6, 22)))
    #expect(!limits.contains(day(2026, 6, 22)))
  }

  @Test func onTheLeapDayTheEarliestDateIsTheFirstOfMarch() {
    let limits = BirthDateLimits.forAdding(today: day(2028, 2, 29))
    #expect(limits.lowerBound == day(2021, 3, 1))
    #expect(!limits.contains(day(2021, 2, 28)))
  }

  @Test func editKeepsASavedBirthdateOlderThanSevenYears() {
    let saved = day(2019, 6, 20)  // 7 years and 1 day before 21 June 2026
    let limits = BirthDateLimits.forEditing(saved: saved, today: day(2026, 6, 21))
    #expect(limits.lowerBound == saved)
    #expect(limits.upperBound == day(2026, 6, 21))
  }

  @Test func editWithAYoungChildUsesTheAddLimits() {
    let limits = BirthDateLimits.forEditing(saved: day(2024, 6, 21), today: day(2026, 6, 21))
    #expect(limits.lowerBound == day(2019, 6, 22))
    #expect(limits.upperBound == day(2026, 6, 21))
  }
}

func day(_ year: Int, _ month: Int, _ day: Int) -> BirthDate {
  BirthDate(year: year, month: month, day: day)!
}
