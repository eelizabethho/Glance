import GlanceCore
import Testing

@testable import Glance

struct KindShortcutTests {
  @Test func prefixesAtLineStartSetTheKind() {
    #expect(kindShortcut("# work")?.kind == .heading)
    #expect(kindShortcut("# work")?.rest == "work")
    #expect(kindShortcut("- milk")?.kind == .bullet)
    #expect(kindShortcut("[] milk")?.kind == .checklist)
    #expect(kindShortcut("[] milk")?.rest == "milk")
  }

  @Test func plainTextAndMidLinePrefixesAreLeftAlone() {
    #expect(kindShortcut("work") == nil)
    #expect(kindShortcut("a # b") == nil)
    #expect(kindShortcut("#work") == nil)
    #expect(kindShortcut("-milk") == nil)
  }

  @Test func theMarkerCyclesChecklistBulletHeading() {
    #expect(LineKind.checklist.next == .bullet)
    #expect(LineKind.bullet.next == .heading)
    #expect(LineKind.heading.next == .checklist)
  }
}
