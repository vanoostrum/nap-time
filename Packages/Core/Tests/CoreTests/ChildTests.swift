import Core
import Foundation
import Testing

@Suite struct ChildTests {
  @Test func nameIsTrimmed() {
    #expect(ChildName.validated("  Mila \n") == "Mila")
  }

  @Test func emptyNameIsRefused() {
    #expect(ChildName.validated("") == nil)
    #expect(ChildName.validated("   ") == nil)
  }

  @Test func nameHoldsAtMost30Characters() {
    let thirty = "Maximiliana Rosalind Pepperpot"
    #expect(thirty.count == 30)
    #expect(ChildName.validated(thirty) == thirty)
    #expect(ChildName.validated(thirty + "s") == nil)
    #expect(ChildName.validated("  " + thirty + "  ") == thirty)
  }

  @Test func initialIsTheFirstLetterInUpperCase() {
    #expect(child("mila").initial == "M")
  }

  @Test func selectedChildIsTheSavedChildWhenItExists() {
    let mila = child("Mila")
    let noah = child("Noah")
    #expect(SelectedChild.id(saved: noah.id, in: [mila, noah]) == noah.id)
  }

  @Test func selectedChildIsTheFirstChildWhenTheSavedChildIsGone() {
    let mila = child("Mila")
    let noah = child("Noah")
    #expect(SelectedChild.id(saved: UUID(), in: [mila, noah]) == mila.id)
    #expect(SelectedChild.id(saved: nil, in: [mila, noah]) == mila.id)
  }

  @Test func noChildrenGiveNoSelectedChild() {
    #expect(SelectedChild.id(saved: UUID(), in: []) == nil)
    #expect(SelectedChild.id(saved: nil, in: []) == nil)
  }

  private func child(_ name: String) -> Child {
    Child(id: UUID(), name: name, birthDate: day(2025, 3, 12), photo: nil)
  }
}
