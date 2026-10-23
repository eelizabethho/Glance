import GlanceCore
import SwiftUI

enum LineID: Hashable {
  case task(TaskID)
  case draft
}

/// "[] " at the start of a line makes a checklist item and "- " a bullet. Returns the kind and the rest.
func lineShortcut(_ text: String) -> (isNote: Bool, text: String)? {
  for (prefix, isNote) in [("[] ", false), ("[ ] ", false), ("- ", true)]
  where text.hasPrefix(prefix) {
    return (isNote, String(text.dropFirst(prefix.count)))
  }
  return nil
}

extension GlanceTask {
  var checkSymbol: String {
    switch status {
    case .todo: "square"
    case .pending: "square.lefthalf.filled"
    case .completed: "checkmark.square"
    case .cancelled: "xmark.square"
    }
  }
}

/// A single-category list shown as a document: each line is a text field you type into directly.
struct NotepadView: View {
  let state: AppState
  let tasks: [GlanceTask]
  /// False hides the trailing empty line. `category` nil means the first one, made if missing.
  let canAdd: Bool
  let category: String?
  let focus: FocusState<LineID?>.Binding
  @Binding var draftIsNote: Bool
  @State private var draftText = ""
  /// The empty line sits below this task, or at the end when nil.
  @State private var draftAfter: TaskID?

  private enum Item: Identifiable {
    case task(GlanceTask)
    case draft
    var id: LineID {
      switch self {
      case .task(let task): .task(task.id)
      case .draft: .draft
      }
    }
  }

  private var items: [Item] {
    var items = tasks.map(Item.task)
    if canAdd {
      let slot = draftAfter.flatMap { id in tasks.firstIndex { $0.id == id } }.map { $0 + 1 }
      items.insert(.draft, at: slot ?? items.endIndex)
    }
    return items
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(items) { item in
        switch item {
        case .task(let task):
          NotepadLine(
            state: state, task: task, focus: focus,
            returned: { newline(after: $0, isNote: task.isNote) }, deleted: { removed(task) })
        case .draft:
          draftLine
        }
      }
      if canAdd {
        Color.clear.frame(height: 80).contentShape(Rectangle()).onTapGesture {
          focus.wrappedValue = .draft
        }
      }
    }
  }

  private var draftLine: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Marker(isNote: draftIsNote, symbol: "square", action: nil)
      TextField(tasks.isEmpty ? "Start typing" : "", text: $draftText, axis: .vertical)
        .textFieldStyle(.plain)
        .font(.mono(13))
        .focused(focus, equals: .draft)
        .onChange(of: draftText) {
          if draftText.contains("\n") {
            draftText = draftText.replacing("\n", with: "")
            commitDraft()
          } else if let shortcut = lineShortcut(draftText) {
            draftIsNote = shortcut.isNote
            draftText = shortcut.text
          }
        }
        .onSubmit(commitDraft)
        .onKeyPress(.delete, phases: .down) { _ in
          let above = draftAfter.flatMap { id in tasks.first { $0.id == id } } ?? tasks.last
          guard draftText.isEmpty, let above else { return .ignored }
          draftAfter = nil
          focus.wrappedValue = .task(above.id)
          return .handled
        }
    }
  }

  /// Saves the draft below its position, then opens the next empty line there.
  private func commitDraft() {
    let parsed = parseQuickAdd(draftText, now: .now, calendar: .current)
    guard canAdd, !parsed.text.isEmpty else { return }
    let after = draftAfter
    let isNote = draftIsNote
    var added: TaskID?
    state.perform { doc in
      var id = try doc.add(parsed.text, category: category, due: parsed.due)
      id = try doc.update(id) { $0.isNote = isNote }
      let name = doc.task(id)?.category ?? ""
      let siblings = doc.categories.first { $0.name == name }?.tasks ?? []
      if let after, let index = siblings.firstIndex(where: { $0.id == after }) {
        id = try doc.move(id, to: name, at: index + 1)
      }
      added = id
    }
    guard state.lastError == nil, let added else { return }
    draftText = ""
    draftAfter = added
    focus.wrappedValue = .draft
  }

  private func newline(after id: TaskID, isNote: Bool) {
    draftText = ""
    draftAfter = id
    draftIsNote = isNote
    focus.wrappedValue = .draft
  }

  private func removed(_ task: GlanceTask) {
    let index = tasks.firstIndex { $0.id == task.id }
    state.perform { try $0.remove(task.id) }
    focus.wrappedValue =
      index.flatMap { $0 > 0 ? tasks[$0 - 1].id : nil }.map(LineID.task) ?? .draft
  }
}

/// The checkbox of a checklist line, or the bullet of a note.
private struct Marker: View {
  let isNote: Bool
  let symbol: String
  let action: (() -> Void)?

  var body: some View {
    Group {
      if isNote {
        Text("•").font(.mono(14))
      } else if let action {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 14)) }
          .buttonStyle(.plain)
      } else {
        Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(.tertiary)
      }
    }
    .frame(width: 16)
  }
}

private struct NotepadLine: View {
  let state: AppState
  let task: GlanceTask
  let focus: FocusState<LineID?>.Binding
  let returned: (TaskID) -> Void
  let deleted: () -> Void
  @State private var text: String

  init(
    state: AppState, task: GlanceTask, focus: FocusState<LineID?>.Binding,
    returned: @escaping (TaskID) -> Void, deleted: @escaping () -> Void
  ) {
    self.state = state
    self.task = task
    self.focus = focus
    self.returned = returned
    self.deleted = deleted
    _text = State(initialValue: task.text)
  }

  private var done: Bool { task.status == .completed || task.status == .cancelled }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Marker(isNote: task.isNote, symbol: task.checkSymbol) {
        state.perform { try $0.setStatus(task.id, task.status.toggled, today: CalendarDay(.now)) }
      }
      .accessibilityLabel(
        task.status == .completed ? "Mark \(task.text) to-do" : "Complete \(task.text)")
      if done {
        // TextField ignores strikethrough on macOS, so a checked line is plain text until unchecked.
        Text(task.text).font(.mono(13)).strikethrough().foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        field
      }
      if let due = task.due {
        Text("\(due.day.month)/\(due.day.day)").font(.mono(11)).foregroundStyle(.secondary)
      }
    }
    .contextMenu {
      Button(task.isNote ? "Make Checklist Item" : "Make Bullet") { setKind(!task.isNote) }
      Button("Delete", role: .destructive) { deleted() }
    }
  }

  private var field: some View {
    TextField("", text: $text, axis: .vertical)
      .textFieldStyle(.plain)
      .font(.mono(13))
      .focused(focus, equals: .task(task.id))
      .onChange(of: text) {
        // A wrapping field can take a typed newline; a line in todo.md never may, so it means Return.
        if text.contains("\n") {
          text = text.replacing("\n", with: "")
          if let id = commit() { returned(id) }
          return
        }
        guard let shortcut = lineShortcut(text) else { return }
        text = shortcut.text
        if shortcut.isNote != task.isNote { setKind(shortcut.isNote) }
      }
      .onChange(of: focus.wrappedValue) { old, _ in
        if old == .task(task.id), focus.wrappedValue != old { blurred() }
      }
      .onSubmit { if let id = commit() { returned(id) } }
      .onKeyPress(.delete, phases: .down) { _ in
        guard text.isEmpty else { return .ignored }
        deleted()
        return .handled
      }
      .accessibilityLabel(task.isNote ? "Bullet" : "Checklist item")
  }

  private func setKind(_ isNote: Bool) {
    state.perform {
      try $0.update(task.id) {
        $0.isNote = isNote
        if isNote { ($0.status, $0.doneAt) = (.todo, nil) }
      }
    }
  }

  /// Saves an edited, non-empty line and returns its id, which a new text changes.
  @discardableResult private func commit() -> TaskID? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    guard trimmed != task.text else { return task.id }
    var id = task.id
    state.perform { id = try $0.update(task.id) { $0.text = trimmed } }
    return state.lastError == nil ? id : nil
  }

  /// A line left empty is deleted, as in Notes; otherwise edits are saved.
  private func blurred() {
    if text.trimmingCharacters(in: .whitespaces).isEmpty {
      state.perform { try $0.remove(task.id) }
    } else {
      commit()
    }
  }
}
