import Foundation
import Testing

@testable import GlanceCore

@Test func `heading lines round-trip and parse as headings`() throws {
  let text = try fixture("headings")
  let doc = MarkdownParser.parse(text)
  #expect(MarkdownSerializer.serialize(doc) == text)
  #expect(doc.tasks.map(\.isHeading) == [true, false, false, true, false])
  #expect(doc.task(named: "work")?.status == .todo)
}

@Test func `headings never count toward the ball or due`() throws {
  let doc = MarkdownParser.parse(try fixture("headings"))
  #expect(Counts.todo(doc) == 2)
  let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 23))!
  #expect(Counts.dueTodayOrOverdue(doc, now: now) == 1)
}

@Test func `a task flips between line and heading`() throws {
  var doc = MarkdownParser.parse("## a\n- [ ] x\n")
  let id = try doc.update(try #require(doc.tasks.first).id) { $0.isHeading = true }
  #expect(MarkdownSerializer.serialize(doc) == "## a\n### x\n")
  try doc.update(id) { $0.isHeading = false }
  #expect(MarkdownSerializer.serialize(doc) == "## a\n- [ ] x\n")
}
