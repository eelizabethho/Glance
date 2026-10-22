import Foundation
import GlanceCore
import Testing

@testable import Glance

private func tempFile(_ text: String) throws -> URL {
  let dir = FileManager.default.temporaryDirectory.appending(path: "glance-\(UUID())")
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  let url = dir.appending(path: "todo.md")
  try text.write(to: url, atomically: true, encoding: .utf8)
  return url
}

private let sample = """
  ## work
  - [ ] report 📅 \(CalendarDay(.now))
  - [/] call
  - [x] done

  ## suggested
  - [ ] idea 🤖 claude 2026-10-20

  """

struct AppStateTests {
  @Test func loadsCountsFromAnExistingFile() throws {
    let state = AppState(url: try tempFile(sample))
    #expect(state.todoCount == 1)
    #expect(state.dueCount == 1)
    #expect(state.document.categories.map(\.name) == ["work", "suggested"])
  }

  @Test func performWritesTheFileAndUpdatesCounts() throws {
    let url = try tempFile(sample)
    let state = AppState(url: url)
    state.perform { _ = try $0.add("groceries", category: "work") }
    #expect(state.todoCount == 2)
    #expect(state.lastError == nil)
    #expect(try String(contentsOf: url, encoding: .utf8).contains("- [ ] groceries"))
  }

  @Test func failedEditLeavesTheFileAloneAndSetsLastError() throws {
    let url = try tempFile(sample)
    let state = AppState(url: url)
    state.perform { _ = try $0.add("", category: "work") }
    #expect(state.lastError != nil)
    #expect(state.todoCount == 1)
    #expect(try String(contentsOf: url, encoding: .utf8) == sample)
  }
}
