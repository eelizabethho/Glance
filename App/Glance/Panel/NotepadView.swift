import GlanceCore
import SwiftUI

enum LineID: Hashable {
  case task(TaskID)
  case draft
}

private let focusNewLine = Notification.Name("GlanceFocusAddField")

/// "# " at the start of a line makes it a heading. Returns the rest of the line.
func headingShortcut(_ text: String) -> String? {
  text.hasPrefix("# ") ? String(text.dropFirst(2)) : nil
}

/// A page shown as a document: each line is a text field you type into directly.
struct NotepadView: View {
  let state: AppState
  let tasks: [GlanceTask]
  /// nil means the first page, made if missing.
  let category: String?
  @FocusState private var focus: LineID?
  @State private var draftOpen = false
  @State private var draftText = ""
  @State private var draftIsHeading = false
  /// The new line sits below this task, or at the end when nil.
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
    if draftOpen {
      let slot = draftAfter.flatMap { id in tasks.firstIndex { $0.id == id } }.map { $0 + 1 }
      items.insert(.draft, at: slot ?? items.endIndex)
    }
    return items
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if tasks.isEmpty && !draftOpen {
        Text("Start typing").font(.mono(13)).foregroundStyle(.tertiary)
      }
      ForEach(items) { item in
        switch item {
        case .task(let task):
          NotepadLine(
            state: state, task: task, focus: $focus,
            returned: { open(after: $0) }, deleted: { removed(task) })
        case .draft:
          draftLine
        }
      }
      // Blank space below the last line starts a new one.
      Color.clear.frame(height: 80).contentShape(Rectangle()).onTapGesture { open(after: nil) }
    }
    .background {
      Button("New line") { open(after: nil) }
        .keyboardShortcut(.space, modifiers: .option)
        .opacity(0).accessibilityHidden(true)
    }
    .onReceive(NotificationCenter.default.publisher(for: focusNewLine)) { _ in
      open(after: nil)
    }
  }

  private var draftLine: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      if !draftIsHeading { Marker(done: false, action: nil) }
      TextField(tasks.isEmpty ? "Start typing" : "", text: $draftText, axis: .vertical)
        .textFieldStyle(.plain)
        .font(.mono(13, bold: draftIsHeading))
        .focused($focus, equals: .draft)
        .onChange(of: draftText) {
          if draftText.contains("\n") {
            draftText = draftText.replacing("\n", with: "")
            commitDraft(reopen: true)
          } else if let rest = headingShortcut(draftText) {
            draftIsHeading = true
            draftText = rest
          }
        }
        .onChange(of: focus) { old, new in
          if old == .draft, new != .draft { commitDraft(reopen: false) }
        }
        .onSubmit { commitDraft(reopen: true) }
        .onKeyPress(.delete, phases: .down) { _ in
          let above = draftAfter.flatMap { id in tasks.first { $0.id == id } } ?? tasks.last
          guard draftText.isEmpty, let above else { return .ignored }
          focus = .task(above.id)
          return .handled
        }
    }
  }

  private func open(after id: TaskID?) {
    draftOpen = true
    draftText = ""
    draftIsHeading = false
    draftAfter = id
    focus = .draft
  }

  /// Saves the draft below its position. With `reopen`, opens the next empty line there;
  /// otherwise closes the draft.
  private func commitDraft(reopen: Bool) {
    let heading = draftIsHeading
    let parsed =
      heading
      ? (text: draftText.trimmingCharacters(in: .whitespaces), due: nil)
      : parseQuickAdd(draftText, now: .now, calendar: .current)
    guard !parsed.text.isEmpty else {
      if !reopen { draftOpen = false }
      return
    }
    let after = draftAfter
    var added: TaskID?
    state.perform { doc in
      var id = try doc.add(parsed.text, category: category, due: parsed.due)
      if heading { id = try doc.update(id) { $0.isHeading = true } }
      let name = doc.task(id)?.category ?? ""
      let siblings = doc.categories.first { $0.name == name }?.tasks ?? []
      if let after, let index = siblings.firstIndex(where: { $0.id == after }) {
        id = try doc.move(id, to: name, at: index + 1)
      }
      added = id
    }
    guard state.lastError == nil, let added else { return }
    if reopen { open(after: added) } else { draftOpen = false }
  }

  private func removed(_ task: GlanceTask) {
    let index = tasks.firstIndex { $0.id == task.id }
    state.perform { try $0.remove(task.id) }
    focus = index.flatMap { $0 > 0 ? tasks[$0 - 1].id : nil }.map(LineID.task)
  }
}

/// The dot of a line; click to cross the line out or restore it.
private struct Marker: View {
  let done: Bool
  let action: (() -> Void)?

  var body: some View {
    Group {
      if let action {
        Button(action: action) { dot }.buttonStyle(.plain)
      } else {
        dot.foregroundStyle(.tertiary)
      }
    }
    .frame(width: 16)
  }

  private var dot: some View {
    Text("•").font(.mono(14)).foregroundStyle(done ? .secondary : .primary)
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

  /// A cancelled line from an old file reads as crossed out too.
  private var done: Bool { task.status == .completed || task.status == .cancelled }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      if !task.isHeading {
        Marker(done: done) {
          state.perform {
            try $0.setStatus(task.id, done ? .todo : .completed, today: CalendarDay(.now))
          }
        }
        .accessibilityLabel(done ? "Restore \(task.text)" : "Cross out \(task.text)")
      }
      if done {
        // TextField ignores strikethrough on macOS, so a crossed-out line is plain text until restored.
        Text(task.text).font(.mono(13)).strikethrough().foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        field
      }
      if let due = task.due {
        Text("\(due.day.month)/\(due.day.day)").font(.mono(11)).foregroundStyle(.secondary)
      }
    }
    // Room above a heading so each group reads as its own block.
    .padding(.top, task.isHeading ? 8 : 0)
    .contextMenu {
      Button(task.isHeading ? "Make Line" : "Make Heading") { setHeading(!task.isHeading) }
      Button("Delete", role: .destructive) { deleted() }
    }
  }

  private var field: some View {
    TextField("", text: $text, axis: .vertical)
      .textFieldStyle(.plain)
      .font(.mono(13, bold: task.isHeading))
      .focused(focus, equals: .task(task.id))
      .onChange(of: text) {
        // A wrapping field can take a typed newline; a line in todo.md never may, so it means Return.
        if text.contains("\n") {
          text = text.replacing("\n", with: "")
          if let id = commit() { returned(id) }
          return
        }
        guard let rest = headingShortcut(text) else { return }
        text = rest
        if !task.isHeading { setHeading(true) }
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
      .accessibilityLabel(task.isHeading ? "Heading" : "Line")
  }

  /// A heading has no status or due date in the file, so both are cleared.
  private func setHeading(_ isHeading: Bool) {
    state.perform {
      try $0.update(task.id) {
        $0.isHeading = isHeading
        if isHeading { ($0.status, $0.doneAt, $0.due) = (.todo, nil, nil) }
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
