import AppKit
import Testing

@testable import Glance

struct PageTextTests {
  @Test func markdownLinesSurviveAToAttributedAndBack() {
    let lines = [
      "### work", "- [ ] weekly report 📅 2026-10-26", "- [x] buy cases",
      "- a bullet", "just a plain line", "", "- [", "- ",
    ]
    #expect(PageText.lines(from: PageText.attributed(from: lines)) == lines)
  }

  @Test func theDoneStampIsHiddenOnScreen() {
    #expect(PageText.attributed(from: ["- [x] b ✅ 2026-10-21"]).string == "☑ b")
    #expect(PageText.shown(["- [x] b ✅ 2026-10-21"]) == ["- [x] b"])
  }

  @Test func markersShowAsGlyphsAndHeadingsAreMarked() {
    let text = PageText.attributed(from: ["### h", "- [ ] a", "- [x] b", "- c"])
    #expect(text.string == "h\n☐ a\n☑ b\n• c")
    #expect(text.attribute(.glanceHeading, at: 0, effectiveRange: nil) != nil)
  }

  @Test func aDoneLineIsStruckThroughAndADueTokenIsDimmed() {
    let text = PageText.attributed(from: ["- [x] b", "- [ ] c 📅 2026-10-26"])
    #expect(text.attribute(.strikethroughStyle, at: 3, effectiveRange: nil) != nil)
    #expect(text.attribute(.strikethroughStyle, at: 10, effectiveRange: nil) == nil)
    let token = (text.string as NSString).range(of: "📅").location
    #expect(
      text.attribute(.foregroundColor, at: token, effectiveRange: nil) as? NSColor
        == .secondaryLabelColor)
  }

  @Test func noTextIsNoLines() {
    #expect(PageText.lines(from: NSAttributedString()).isEmpty)
    #expect(PageText.attributed(from: []).length == 0)
  }
}

/// Drives the text view in code, the way keystrokes reach it.
struct NotesTextViewTests {
  private func editor(_ lines: [String], cursor: Int? = nil) -> NotesTextView {
    let view = NotesTextView.make()
    view.load(lines: lines)
    view.setSelectedRange(NSRange(location: cursor ?? view.string.utf16.count, length: 0))
    return view
  }

  private func type(_ text: String, into view: NotesTextView) {
    for character in text {
      view.insertText(String(character), replacementRange: NSRange(location: NSNotFound, length: 0))
    }
  }

  @Test func undoIsOn() {
    #expect(editor([]).allowsUndo)
  }

  @Test func backspaceOnAnEmptyLineDeletesItAndLandsAtTheEndOfTheLineAbove() {
    let view = editor(["abc", "", "def"], cursor: 4)
    view.deleteBackward(nil)
    #expect(view.string == "abc\ndef")
    #expect(view.selectedRange() == NSRange(location: 3, length: 0))
  }

  @Test func backspaceAfterAMarkerRemovesTheMarker() {
    let view = editor(["- [ ] a", "- b"], cursor: 2)
    view.deleteBackward(nil)
    #expect(view.string == "a\n• b")
    #expect(view.selectedRange() == NSRange(location: 0, length: 0))
    view.setSelectedRange(NSRange(location: 4, length: 0))
    view.deleteBackward(nil)
    #expect(view.string == "a\nb")
  }

  @Test func backspaceElsewhereJoinsLinesNatively() {
    let view = editor(["abc", "def"], cursor: 4)
    view.deleteBackward(nil)
    #expect(view.string == "abcdef")
  }

  @Test func returnInAChecklistLineStartsAnUncheckedOne() {
    let view = editor(["- [x] a"])
    view.insertNewline(nil)
    #expect(view.string == "☑ a\n☐ ")
    #expect(view.selectedRange() == NSRange(location: 6, length: 0))
  }

  @Test func returnInABulletContinuesTheBullet() {
    let view = editor(["- a"])
    view.insertNewline(nil)
    #expect(view.string == "• a\n• ")
  }

  @Test func returnOnAMarkerOnlyLineRemovesTheMarker() {
    let view = editor(["- [ ] a", "- [ ] "])
    view.insertNewline(nil)
    #expect(view.string == "☐ a\n")
    #expect(view.selectedRange() == NSRange(location: 4, length: 0))
  }

  @Test func returnOnAPlainLineIsAPlainNewline() {
    let view = editor(["abc"])
    view.insertNewline(nil)
    #expect(view.string == "abc\n")
  }

  @Test func returnAfterAHeadingStartsAPlainLine() {
    let view = editor(["### h"])
    view.insertNewline(nil)
    type("x", into: view)
    #expect(PageText.lines(from: view.attributedString()) == ["### h", "x"])
  }

  @Test func typingBracketsAndASpaceMakesAChecklist() {
    let view = editor([])
    type("[] milk", into: view)
    #expect(view.string == "☐ milk")
    #expect(PageText.lines(from: view.attributedString()) == ["- [ ] milk"])
  }

  @Test func typingADashAndASpaceMakesABullet() {
    let view = editor(["a"])
    view.insertNewline(nil)
    type("- milk", into: view)
    #expect(view.string == "a\n• milk")
  }

  @Test func typingAHashAndASpaceMakesAHeading() {
    let view = editor([])
    type("# Work", into: view)
    #expect(view.string == "Work")
    #expect(PageText.lines(from: view.attributedString()) == ["### Work"])
  }

  @Test func midLinePrefixesAreLeftAlone() {
    let view = editor([])
    type("a - b", into: view)
    #expect(view.string == "a - b")
  }

  @Test func togglingAMarkerStrikesTheLineThroughAndBack() {
    let view = editor(["- [ ] a"], cursor: 3)
    view.toggleChecklist(at: 0)
    #expect(view.string == "☑ a")
    #expect(view.textStorage?.attribute(.strikethroughStyle, at: 2, effectiveRange: nil) != nil)
    #expect(view.selectedRange() == NSRange(location: 3, length: 0))
    view.toggleChecklist(at: 0)
    #expect(view.string == "☐ a")
    #expect(view.textStorage?.attribute(.strikethroughStyle, at: 2, effectiveRange: nil) == nil)
  }

  @Test func convertingALineChangesItsMarker() {
    let view = editor(["- [ ] a", "b"], cursor: 5)
    view.convertParagraph(to: .bullet)
    #expect(view.string == "☐ a\n• b")
    view.convertParagraph(to: .plain)
    #expect(view.string == "☐ a\nb")
  }

  @Test func clearingDoneRemovesCrossedOutLines() {
    let view = editor(["- [x] a", "- [ ] b", "- [x] c"])
    #expect(view.doneCount == 2)
    view.removeDone()
    #expect(view.string == "☐ b")
  }
}

struct PageEditorMergeTests {
  @Test func linesAnotherWriterAddedSurviveASave() {
    let added = PageEditor.added(
      current: ["- [ ] a", "- [ ] from claude"], base: ["- [ ] a"], edited: ["- [ ] a", "- [ ] b"])
    #expect(added == ["- [ ] from claude"])
  }

  @Test func nothingIsAddedBackWhenOnlyTheEditorChanged() {
    #expect(PageEditor.added(current: ["- [ ] a"], base: ["- [ ] a"], edited: []).isEmpty)
  }
}

struct HiddenDoneTests {
  private let file = ["### h", "- [ ] a", "- [x] done1", "  - [x] done2", "- [ ] b", "- [x] done1"]

  private func save(_ edited: [String]) -> [String] {
    PageEditor.merged(current: file, base: PageText.visible(file), edited: edited)
  }

  @Test func theEditorShowsOnlyLinesThatAreNotCrossedOut() {
    #expect(PageText.visible(file) == ["### h", "- [ ] a", "- [ ] b"])
  }

  @Test func aSaveKeepsEveryHiddenLineInPlace() {
    #expect(save(PageText.visible(file)) == file)
  }

  @Test func editsAroundHiddenLinesKeepThem() {
    let out = save(["### h", "- [ ] a2", "- [ ] b", "- [ ] new"])
    #expect(out.filter { $0 == "- [x] done1" }.count == 2)
    #expect(out.contains("  - [x] done2"))
  }

  @Test func indentingAVisibleLineKeepsHiddenLines() {
    let out = save(["### h", "  - [ ] a", "- [ ] b"])
    #expect(
      out == ["### h", "  - [ ] a", "- [x] done1", "  - [x] done2", "- [ ] b", "- [x] done1"])
  }

  @Test func emptyingTheEditorKeepsHiddenLines() {
    #expect(save([]) == ["- [x] done1", "  - [x] done2", "- [x] done1"])
  }

  @Test func aLineMcpAddedAndHiddenLinesBothSurvive() {
    let current = file + ["- [ ] from claude"]
    let out = PageEditor.merged(
      current: current, base: PageText.visible(file), edited: PageText.visible(file))
    #expect(out == current)
  }

  @Test func aCrossedOutLineStillShownCanBeDeletedByTheUser() {
    let shown = ["- [ ] a", "- [x] mis"]
    #expect(PageEditor.merged(current: shown, base: shown, edited: ["- [ ] a"]) == ["- [ ] a"])
  }

  @Test func uncheckingAShownLineKeepsItAsATodo() {
    let out = PageEditor.merged(
      current: ["- [ ] a", "- [x] mis", "- [x] old"], base: ["- [ ] a", "- [x] mis"],
      edited: ["- [ ] a", "- [ ] mis"])
    #expect(out == ["- [ ] a", "- [ ] mis", "- [x] old"])
  }
}

struct IndentedDoneTests {
  @Test func indentedCrossedOutLinesCountAsDone() {
    #expect(PageText.doneCount(lines: ["- [x] a", "  - [x] b", "    - [ ] c", "  - d"]) == 2)
  }
}

@MainActor struct RemoveDoneCursorTests {
  @Test func theCursorStaysOnItsLineWhenDoneLinesVanish() {
    let view = NotesTextView.make()
    view.load(lines: ["- [x] a", "- [ ] typing here", "- [x] b"])
    let line = (view.string as NSString).range(of: "typing")
    view.setSelectedRange(NSRange(location: line.location + 3, length: 0))
    view.removeDone()
    #expect(view.string == "☐ typing here")
    #expect(
      view.selectedRange()
        == NSRange(location: (view.string as NSString).range(of: "typing").location + 3, length: 0))
  }
}
