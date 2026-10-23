import Testing

@testable import Glance

struct HeadingShortcutTests {
  @Test func hashAtLineStartMakesAHeading() {
    #expect(headingShortcut("# work") == "work")
  }

  @Test func plainTextAndMidLinePrefixesAreLeftAlone() {
    #expect(headingShortcut("work") == nil)
    #expect(headingShortcut("a # b") == nil)
    #expect(headingShortcut("#work") == nil)
  }
}
