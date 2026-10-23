import Testing

@testable import Glance

struct LineShortcutTests {
  @Test func bracketsMakeAChecklistAndDashAMakesABullet() {
    #expect(lineShortcut("[] milk")?.isNote == false)
    #expect(lineShortcut("[ ] milk")?.text == "milk")
    #expect(lineShortcut("- milk")?.isNote == true)
    #expect(lineShortcut("- milk")?.text == "milk")
  }

  @Test func plainTextAndMidLinePrefixesAreLeftAlone() {
    #expect(lineShortcut("milk") == nil)
    #expect(lineShortcut("a - b") == nil)
    #expect(lineShortcut("-milk") == nil)
  }
}
