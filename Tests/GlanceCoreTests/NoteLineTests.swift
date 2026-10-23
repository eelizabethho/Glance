import Foundation
import Testing

@testable import GlanceCore

@Test func `note lines round-trip and parse as notes`() throws {
  let text = try fixture("notes")
  let doc = MarkdownParser.parse(text)
  #expect(MarkdownSerializer.serialize(doc) == text)
  #expect(doc.tasks.map(\.isNote) == [false, true, false, true])
  #expect(doc.task(named: "ideas for the weekend")?.status == .todo)
  #expect(doc.task(named: "bullet due soon")?.notes == "a note under a bullet")
}

@Test func `notes never count toward the ball`() throws {
  let doc = MarkdownParser.parse(try fixture("notes"))
  #expect(Counts.todo(doc) == 1)
  let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 23))!
  #expect(Counts.dueTodayOrOverdue(doc, now: now) == 0)
}

@Test func `a task flips between checklist and note`() throws {
  var doc = MarkdownParser.parse("## a\n- [ ] x\n")
  let id = try doc.update(try #require(doc.tasks.first).id) { $0.isNote = true }
  #expect(MarkdownSerializer.serialize(doc) == "## a\n- x\n")
  try doc.update(id) { $0.isNote = false }
  #expect(MarkdownSerializer.serialize(doc) == "## a\n- [ ] x\n")
}
