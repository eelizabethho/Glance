import Foundation
import GlanceCore
import Observation

// GlanceCore's API is frozen, so tab filters add Codable here. Drop this if GlanceCore adopts it.
// swift-format-ignore: AvoidRetroactiveConformances
extension TaskStatus: @retroactive Codable {
  /// The checkbox flips between completed and to-do.
  var toggled: TaskStatus { self == .completed ? .todo : .completed }

  var title: String {
    switch self {
    case .todo: "To-do"
    case .pending: "Pending"
    case .completed: "Completed"
    case .cancelled: "Cancelled"
    }
  }
}

/// A saved filter. An empty set matches everything.
struct TabFilter: Codable, Hashable {
  enum Due: String, Codable, CaseIterable {
    case todayOrOverdue, overdue
  }

  var categories: Set<String> = []
  var statuses: Set<TaskStatus> = []
  var due: Due?

  /// Matching tasks in file order. Suggestions never show here; they get their own section.
  func tasks(in doc: GlanceDocument, now: Date, calendar: Calendar = .current) -> [GlanceTask] {
    let today = CalendarDay(now, calendar: calendar)
    return doc.categories.filter { !$0.isSuggested }.flatMap(\.tasks).filter { task in
      (categories.isEmpty || categories.contains(task.category))
        && (statuses.isEmpty || statuses.contains(task.status))
        && {
          guard let due else { return true }
          guard let day = task.due?.day else { return false }
          return due == .overdue ? day < today : day <= today
        }()
    }
  }
}

struct PanelTab: Codable, Hashable, Identifiable {
  var id = UUID()
  var name: String
  var filter: TabFilter
  var isHidden = false
  /// Status tabs can be renamed or hidden, but not edited or deleted.
  var isStatus = false

  static let today = PanelTab(
    id: builtInID(5), name: "Today",
    filter: TabFilter(statuses: [.todo, .pending], due: .todayOrOverdue))
  /// Fixed ids, so a saved selection still matches before the tabs themselves are saved.
  static var defaults: [PanelTab] {
    TaskStatus.allCases.enumerated().map { index, status in
      PanelTab(
        id: builtInID(index + 1), name: status.title, filter: TabFilter(statuses: [status]),
        isStatus: true)
    } + [today]
  }

  private static func builtInID(_ number: Int) -> UUID {
    UUID(uuidString: "00000000-0000-0000-0000-00000000000\(number)")!
  }
}

/// Counts every task in the category, whatever the tab filter hides, since all of them are deleted.
func deleteCategoryTitle(_ name: String, in doc: GlanceDocument) -> String {
  let count = doc.categories.first { $0.name == name }?.tasks.count ?? 0
  return "Delete “\(name)” and its \(count) \(count == 1 ? "task" : "tasks")?"
}

/// `Hw 6 – ddl 10/25`, as in the reference screenshot.
func dueLabel(_ task: GlanceTask) -> String {
  guard let due = task.due else { return task.text }
  let time = due.time.map { " \($0)" } ?? ""
  return "\(task.text) – ddl \(due.day.month)/\(due.day.day)\(time)"
}

func headerDate(_ date: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
  let formatter = DateFormatter()
  formatter.locale = locale
  formatter.timeZone = timeZone
  formatter.dateFormat = "MMMM d, EEEE"
  return formatter.string(from: date)
}

extension DueDate {
  init(_ date: Date, withTime: Bool, calendar: Calendar = .current) {
    let parts = calendar.dateComponents([.hour, .minute], from: date)
    self.init(
      day: CalendarDay(date, calendar: calendar),
      time: withTime ? TimeOfDay(hour: parts.hour!, minute: parts.minute!) : nil)
  }
}

extension Array where Element: Equatable {
  /// Swaps `element` with its neighbour `offset` places away; unchanged at the ends.
  func moving(_ element: Element, by offset: Int) -> [Element] {
    guard let from = firstIndex(of: element), indices.contains(from + offset) else { return self }
    var copy = self
    copy.swapAt(from, from + offset)
    return copy
  }
}

/// Panel UI state kept in `UserDefaults`; the file has no slot for it.
@Observable final class PanelPrefs {
  var tabs: [PanelTab] { didSet { save(tabs, "glance.panel.tabs") } }
  /// Saved only on change: an Optional is already set in `init`, so its observer runs there too.
  var selectedTab: UUID? {
    didSet { if selectedTab != oldValue { save(selectedTab, "glance.panel.selectedTab") } }
  }
  var collapsed: Set<String> { didSet { save(collapsed, "glance.panel.collapsedCategories") } }
  /// Hex colour of each category's dot, keyed by name.
  var colors: [String: String] { didSet { save(colors, "glance.panel.categoryColors") } }

  /// Where the add field puts new tasks; nil until the first pick.
  var addCategory: String? {
    didSet { if addCategory != oldValue { save(addCategory, "glance.panel.addCategory") } }
  }

  @ObservationIgnored private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    func load<T: Decodable>(_ key: String) -> T? {
      defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
    tabs = load("glance.panel.tabs") ?? PanelTab.defaults
    collapsed = load("glance.panel.collapsedCategories") ?? []
    colors = load("glance.panel.categoryColors") ?? [:]
    selectedTab = load("glance.panel.selectedTab")
    addCategory = load("glance.panel.addCategory")
  }

  /// The selected tab, or the first visible one when it was hidden or deleted.
  var currentTab: PanelTab? {
    let visible = tabs.filter { !$0.isHidden }
    return visible.first { $0.id == selectedTab } ?? visible.first
  }

  private func save(_ value: some Encodable, _ key: String) {
    defaults.set(try? JSONEncoder().encode(value), forKey: key)
  }

  /// Keeps collapse state, colour, and tab filters attached to a renamed category.
  func renameCategory(_ old: String, to new: String) {
    if collapsed.remove(old) != nil { collapsed.insert(new) }
    colors[new] = colors.removeValue(forKey: old)
    for index in tabs.indices where tabs[index].filter.categories.remove(old) != nil {
      tabs[index].filter.categories.insert(new)
    }
  }
}

/// Turns URLs in `notes` into links.
func linkified(_ notes: String) -> AttributedString {
  var result = AttributedString(notes)
  let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
  for match in detector?.matches(in: notes, range: NSRange(notes.startIndex..., in: notes)) ?? [] {
    if let range = Range(match.range, in: result) { result[range].link = match.url }
  }
  return result
}

/// Strips a trailing `ddl M/D [HH:mm]` or `📅 YYYY-MM-DD [HH:mm]` and returns it as the due date.
/// A token that isn't a real date or time stays in the text.
func parseQuickAdd(_ input: String, now: Date, calendar: Calendar) -> (text: String, due: DueDate?)
{
  let today = CalendarDay(now, calendar: calendar)
  let day: CalendarDay?
  let hour: Substring?
  let minute: Substring?
  let start: String.Index
  if let hit = input.firstMatch(of: /\s+ddl (\d{1,2})\/(\d{1,2})(?: (\d{1,2}):(\d{2}))?$/) {
    let (month, dom) = (Int(hit.1) ?? 0, Int(hit.2) ?? 0)
    // Next occurrence on or after today.
    day =
      CalendarDay(year: today.year, month: month, day: dom).flatMap { $0 >= today ? $0 : nil }
      ?? CalendarDay(year: today.year + 1, month: month, day: dom)
    (hour, minute, start) = (hit.3, hit.4, hit.range.lowerBound)
  } else if let hit = input.firstMatch(of: /\s+📅 (\d{4})-(\d{2})-(\d{2})(?: (\d{1,2}):(\d{2}))?$/) {
    day = CalendarDay(year: Int(hit.1) ?? 0, month: Int(hit.2) ?? 0, day: Int(hit.3) ?? 0)
    (hour, minute, start) = (hit.4, hit.5, hit.range.lowerBound)
  } else {
    return (input, nil)
  }
  let time = hour.flatMap { hrs in
    minute.flatMap { TimeOfDay(hour: Int(hrs) ?? 0, minute: Int($0) ?? 0) }
  }
  guard let day, time != nil || hour == nil else { return (input, nil) }
  return (
    String(input[..<start]).trimmingCharacters(in: .whitespaces), DueDate(day: day, time: time)
  )
}
