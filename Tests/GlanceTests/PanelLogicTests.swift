import Foundation
import GlanceCore
import Testing

@testable import Glance

private let doc = MarkdownParser.parse(
  """
  ## work
  - [ ] weekly report
  - [/] conference 📅 2026-10-20

  ## life
  - [ ] flight 📅 2026-10-22
  - [ ] dentist 📅 2026-10-28 14:30
  - [x] cases ✅ 2026-10-21

  ## study
  - [ ] Hw 6 📅 2026-10-25
  - [-] old reading 📅 2026-10-01

  ## suggested
  - [ ] dinner 📅 2026-10-22 🤖 claude 2026-10-20

  """)

private let utc: Calendar = {
  var cal = Calendar(identifier: .gregorian)
  cal.timeZone = TimeZone(identifier: "UTC")!
  return cal
}()

/// 2026-10-22 12:00 UTC, a Thursday.
private let now = Date(timeIntervalSince1970: 1_792_670_400)

struct PanelLogicTests {
  @Test func dueLabelReadsLikeTheReference() throws {
    func label(_ text: String) throws -> String {
      dueLabel(try #require(doc.tasks.first { $0.text == text }))
    }
    #expect(try label("Hw 6") == "Hw 6 – ddl 10/25")
    #expect(try label("dentist") == "dentist – ddl 10/28 14:30")
    #expect(try label("weekly report") == "weekly report")
  }

  @Test func headerDateReadsMonthDayWeekday() {
    #expect(
      headerDate(now, locale: Locale(identifier: "en_US"), timeZone: utc.timeZone)
        == "October 22, Thursday")
  }

}

struct DeleteCategoryTitleTests {
  @Test func countsEveryTaskNotJustTheVisibleOnes() {
    #expect(deleteCategoryTitle("life", in: doc) == "Delete “life” and its 3 tasks?")
  }

  @Test func countsCompletedOnlyAndSingular() {
    let done = MarkdownParser.parse("## done\n- [x] a ✅ 2026-10-21\n- [x] b ✅ 2026-10-21\n")
    #expect(deleteCategoryTitle("done", in: done) == "Delete “done” and its 2 tasks?")
    let one = MarkdownParser.parse("## one\n- [x] a ✅ 2026-10-21\n")
    #expect(deleteCategoryTitle("one", in: one) == "Delete “one” and its 1 task?")
  }
}

struct PageRowTests {
  @Test func rowShowsOnlyWithMoreThanOnePage() {
    #expect(!showsPageRow(pageCount: 0))
    #expect(!showsPageRow(pageCount: 1))
    #expect(showsPageRow(pageCount: 2))
  }
}
