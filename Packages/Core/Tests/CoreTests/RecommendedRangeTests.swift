import Core
import Testing

@Suite struct RecommendedRangeTests {
  private let today = day(2026, 6, 21)

  @Test(arguments: [
    (day(2026, 6, 21), 14, 17),  // born today
    (day(2026, 2, 22), 14, 17),  // 1 day before 4 months
    (day(2026, 2, 21), 12, 16),  // exactly 4 months
    (day(2025, 6, 22), 12, 16),  // 1 day before the 1st birthday
    (day(2025, 6, 21), 11, 14),  // the 1st birthday
    (day(2023, 6, 22), 11, 14),  // 1 day before the 3rd birthday
    (day(2023, 6, 21), 10, 13),  // the 3rd birthday
    (day(2020, 6, 22), 10, 13),  // 1 day before the 6th birthday
    (day(2020, 6, 21), 9, 12),  // the 6th birthday
    (day(2019, 6, 20), 9, 12),  // 7 years and 1 day
  ])
  func rangeForEachBandEdge(birthDate: BirthDate, lower: Int, upper: Int) {
    let range = RecommendedRange(birthDate: birthDate, on: today)
    #expect(range.lowerHours == lower)
    #expect(range.upperHours == upper)
  }

  @Test func bornOn31OctoberMovesToTheSecondRangeOn28February() {
    let birth = day(2026, 10, 31)
    #expect(RecommendedRange(birthDate: birth, on: day(2027, 2, 27)).lowerHours == 14)
    #expect(RecommendedRange(birthDate: birth, on: day(2027, 2, 28)).lowerHours == 12)
  }

  @Test func bornOnTheLeapDayMovesOnTheLastDayOfFebruary() {
    let birth = day(2024, 2, 29)
    #expect(RecommendedRange(birthDate: birth, on: day(2025, 2, 27)).lowerHours == 12)
    #expect(RecommendedRange(birthDate: birth, on: day(2025, 2, 28)).lowerHours == 11)
    #expect(RecommendedRange(birthDate: birth, on: day(2027, 2, 27)).lowerHours == 11)
    #expect(RecommendedRange(birthDate: birth, on: day(2027, 2, 28)).lowerHours == 10)
  }

  @Test func descriptionUsesAnEnDash() {
    #expect(RecommendedRange(birthDate: day(2025, 3, 12), on: today).description == "11–14 h")
  }
}
