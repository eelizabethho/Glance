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

private func texts(_ filter: TabFilter) -> [String] {
  filter.tasks(in: doc, now: now, calendar: utc).map(\.text)
}

struct TabFilterTests {
  @Test func statusTabShowsThatStatusAndSkipsSuggestions() {
    #expect(texts(TabFilter(statuses: [.todo])) == ["weekly report", "flight", "dentist", "Hw 6"])
    #expect(texts(TabFilter(statuses: [.completed])) == ["cases"])
  }

  @Test func todayPresetShowsOpenTasksDueTodayOrOverdue() {
    #expect(texts(PanelTab.today.filter) == ["conference", "flight"])
  }

  @Test func categoryAndOverdueCombine() {
    #expect(
      texts(TabFilter(categories: ["work", "study"], due: .overdue)) == [
        "conference", "old reading",
      ])
  }

  @Test func emptyFilterShowsEveryRegularTask() {
    #expect(texts(TabFilter()).count == 7)
  }
}

struct TaskRowLogicTests {
  @Test func dueLabelReadsLikeTheReference() throws {
    func label(_ text: String) throws -> String {
      dueLabel(try #require(doc.tasks.first { $0.text == text }))
    }
    #expect(try label("Hw 6") == "Hw 6 – ddl 10/25")
    #expect(try label("dentist") == "dentist – ddl 10/28 14:30")
    #expect(try label("weekly report") == "weekly report")
  }

  @Test func checkboxTogglesCompleted() {
    #expect(TaskStatus.todo.toggled == .completed)
    #expect(TaskStatus.pending.toggled == .completed)
    #expect(TaskStatus.cancelled.toggled == .completed)
    #expect(TaskStatus.completed.toggled == .todo)
  }

  @Test func pickerDateBecomesDueDate() throws {
    let date = try #require(
      utc.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 9, minute: 5)))
    let day = try #require(CalendarDay(year: 2026, month: 10, day: 25))
    #expect(DueDate(date, withTime: false, calendar: utc) == DueDate(day: day))
    #expect(
      DueDate(date, withTime: true, calendar: utc)
        == DueDate(day: day, time: TimeOfDay(hour: 9, minute: 5)))
  }

  @Test func headerDateReadsMonthDayWeekday() {
    #expect(
      headerDate(now, locale: Locale(identifier: "en_US"), timeZone: utc.timeZone)
        == "October 22, Thursday")
  }

  @Test func movingClampsAtTheEnds() {
    #expect(["a", "b", "c"].moving("b", by: -1) == ["b", "a", "c"])
    #expect(["a", "b", "c"].moving("c", by: 1) == ["a", "b", "c"])
    #expect(["a", "b", "c"].moving("x", by: 1) == ["a", "b", "c"])
  }
}

/// Runs `body` against a throwaway suite, never the app's real domain, and deletes it after.
private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
  let name = "glance-test-\(UUID())"
  let store = try #require(UserDefaults(suiteName: name))
  defer {
    store.removePersistentDomain(forName: name)
    try? FileManager.default.removeItem(
      at: URL.libraryDirectory.appending(path: "Preferences/\(name).plist"))
  }
  try body(store)
}

struct PanelPrefsTests {
  @Test func startsWithStatusTabsAndTodayAndPersists() throws {
    try withDefaults { store in
      let prefs = PanelPrefs(defaults: store)
      #expect(prefs.tabs.map(\.name) == ["To-do", "Pending", "Completed", "Cancelled", "Today"])
      try #require(prefs.tabs.indices.contains(1))
      prefs.tabs[1].isHidden = true
      prefs.collapsed.insert("work")
      prefs.colors["work"] = "#E8A0B4"
      let reloaded = PanelPrefs(defaults: store)
      try #require(reloaded.tabs.indices.contains(1))
      #expect(reloaded.tabs[1].isHidden)
      #expect(reloaded.collapsed == ["work"])
      #expect(reloaded.colors == ["work": "#E8A0B4"])
      #expect(reloaded.currentTab?.id == prefs.tabs.first?.id)
    }
  }

  @Test func loadingWritesNothingAndKeepsTheSelection() throws {
    try withDefaults { store in
      _ = PanelPrefs(defaults: store)
      #expect(store.dictionaryRepresentation().keys.filter { $0.hasPrefix("glance.") }.isEmpty)
      let prefs = PanelPrefs(defaults: store)
      let last = try #require(prefs.tabs.last)
      prefs.selectedTab = last.id
      #expect(PanelPrefs(defaults: store).currentTab?.name == "Today")
    }
  }

  @Test func renamingACategoryCarriesItsPrefs() throws {
    try withDefaults { store in
      let prefs = PanelPrefs(defaults: store)
      prefs.collapsed = ["work"]
      prefs.colors = ["work": "#E8A0B4"]
      prefs.tabs.append(PanelTab(name: "Work", filter: TabFilter(categories: ["work", "life"])))
      prefs.renameCategory("work", to: "job")
      #expect(prefs.collapsed == ["job"])
      #expect(prefs.colors == ["job": "#E8A0B4"])
      #expect(prefs.tabs.last?.filter.categories == ["job", "life"])
    }
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
