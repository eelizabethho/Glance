import GlanceCore
import SwiftUI

enum LineID: Hashable {
  case task(TaskID)
  case draft
}

private let focusNewLine = Notification.Name("GlanceFocusAddField")

/// "[] ", "- " or "# " at the start of a line sets its kind. Returns the rest of the line.
func kindShortcut(_ text: String) -> (kind: LineKind, rest: String)? {
  for (prefix, kind) in [("[] ", LineKind.checklist), ("- ", .bullet), ("# ", .heading)]
  where text.hasPrefix(prefix) {
    return (kind, String(text.dropFirst(prefix.count)))
  }
  return nil
}

extension LineKind {
  /// The order the new-line marker cycles through.
  var next: LineKind {
    switch self {
    case .checklist: .bullet
    case .bullet: .heading
    case .heading: .checklist
    }
  }

  var title: String {
    switch self {
    case .checklist: "checklist"
    case .bullet: "bullet"
    case .heading: "heading"
    }
  }
}

/// A page shown as a document: each line is a text field you type into directly.
/// A faint draft line always ends the page.
struct NotepadView: View {
  let state: AppState
  let tasks: [GlanceTask]
  /// nil means the first page, made if missing.
  let category: String?
  @FocusState private var focus: LineID?
  @State private var draftText = ""
  @State private var draftKind = LineKind.checklist
  /// The draft sits below this task, or at the end when nil.
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
    let slot = draftAfter.flatMap { id in tasks.firstIndex { $0.id == id } }.map { $0 + 1 }
    items.insert(.draft, at: slot ?? items.endIndex)
    return items
  }

  private var doneCount: Int {
    tasks.filter { $0.kind == .checklist && $0.status.isCrossedOut }.count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(items) { item in
        switch item {
        case .task(let task):
          NotepadLine(
            state: state, task: task, focus: $focus,
            returned: { open(after: $0, kind: task.kind) }, deleted: { removed(task) })
        case .draft:
          draftLine
        }
      }
      if doneCount > 0 { clearDone }
    }
    .background {
      Button("New line") { focus = .draft }
        .keyboardShortcut(.space, modifiers: .option)
        .opacity(0).accessibilityHidden(true)
    }
    .onReceive(NotificationCenter.default.publisher(for: focusNewLine)) { _ in
      focus = .draft
    }
  }

  private var clearDone: some View {
    HStack {
      Spacer()
      Button("Clear \(doneCount) done") {
        guard let page = tasks.first?.category else { return }
        state.perform { try $0.removeCompleted(in: page) }
      }
      .buttonStyle(.plain)
      .font(.mono(11))
      .foregroundStyle(.secondary)
    }
  }

  private var draftLine: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Button {
        draftKind = draftKind.next
      } label: {
        KindGlyph(kind: draftKind, done: false)
      }
      .buttonStyle(.plain)
      .frame(width: 16)
      .foregroundStyle(.tertiary)
      .accessibilityLabel("New line type: \(draftKind.title)")
      .help("Line type: \(draftKind.title). Click to change.")
      TextField(
        "", text: $draftText,
        prompt: Text("Start typing…").foregroundStyle(.tertiary), axis: .vertical
      )
      .textFieldStyle(.plain)
      .font(.mono(13, bold: draftKind == .heading))
      .focused($focus, equals: .draft)
      .onChange(of: draftText) {
        if draftText.contains("\n") {
          draftText = draftText.replacing("\n", with: "")
          commitDraft(reopen: true)
        } else if let (kind, rest) = kindShortcut(draftText) {
          draftKind = kind
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

  private func open(after id: TaskID?, kind: LineKind) {
    draftText = ""
    draftKind = kind
    draftAfter = id
    focus = .draft
  }

  /// Saves the draft below its position. With `reopen`, starts the next draft of the same kind
  /// right below; otherwise the draft goes back to the end of the page.
  private func commitDraft(reopen: Bool) {
    let kind = draftKind
    let parsed =
      kind == .checklist
      ? parseQuickAdd(draftText, now: .now, calendar: .current)
      : (text: draftText.trimmingCharacters(in: .whitespaces), due: nil)
    guard !parsed.text.isEmpty else {
      if !reopen { draftAfter = nil }
      return
    }
    let after = draftAfter
    var added: TaskID?
    state.perform { doc in
      var id = try doc.add(parsed.text, category: category, due: parsed.due)
      if kind != .checklist { id = try doc.update(id) { $0.kind = kind } }
      let name = doc.task(id)?.category ?? ""
      let siblings = doc.categories.first { $0.name == name }?.tasks ?? []
      if let after, let index = siblings.firstIndex(where: { $0.id == after }) {
        id = try doc.move(id, to: name, at: index + 1)
      }
      added = id
    }
    guard state.lastError == nil, let added else { return }
    draftText = ""
    if reopen {
      draftAfter = added
      focus = .draft
    } else {
      draftAfter = nil
    }
  }

  private func removed(_ task: GlanceTask) {
    let index = tasks.firstIndex { $0.id == task.id }
    state.perform { try $0.remove(task.id) }
    focus = index.flatMap { $0 > 0 ? tasks[$0 - 1].id : nil }.map(LineID.task)
  }
}

/// The mark at the left of a line: a box, a bullet, or an "H".
private struct KindGlyph: View {
  let kind: LineKind
  let done: Bool

  var body: some View {
    switch kind {
    case .checklist:
      Image(systemName: done ? "checkmark.square" : "square").font(.system(size: 13))
    case .bullet:
      Text("•").font(.mono(14))
    case .heading:
      Text("H").font(.mono(11, bold: true))
    }
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
  private var done: Bool { task.kind == .checklist && task.status.isCrossedOut }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      marker
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
    .padding(.top, task.kind == .heading ? 8 : 0)
    .contextMenu {
      ForEach(LineKind.allCases.filter { $0 != task.kind }, id: \.self) { kind in
        Button("Make \(kind.title.capitalized)") { setKind(kind) }
      }
      Button("Delete", role: .destructive) { deleted() }
    }
  }

  @ViewBuilder private var marker: some View {
    switch task.kind {
    case .checklist:
      Button {
        state.perform {
          try $0.setStatus(task.id, done ? .todo : .completed, today: CalendarDay(.now))
        }
      } label: {
        KindGlyph(kind: .checklist, done: done).foregroundStyle(done ? .secondary : .primary)
      }
      .buttonStyle(.plain)
      .frame(width: 16)
      .accessibilityLabel(done ? "Restore \(task.text)" : "Cross out \(task.text)")
    case .bullet:
      KindGlyph(kind: .bullet, done: false).frame(width: 16).accessibilityHidden(true)
    case .heading:
      EmptyView()
    }
  }

  private var field: some View {
    TextField("", text: $text, axis: .vertical)
      .textFieldStyle(.plain)
      .font(.mono(13, bold: task.kind == .heading))
      .focused(focus, equals: .task(task.id))
      .onChange(of: text) {
        // A wrapping field can take a typed newline; a line in todo.md never may, so it means Return.
        if text.contains("\n") {
          text = text.replacing("\n", with: "")
          if let id = commit() { returned(id) }
          return
        }
        guard let (kind, rest) = kindShortcut(text) else { return }
        text = rest
        if kind != task.kind { setKind(kind) }
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
      .accessibilityLabel(task.kind.title.capitalized)
  }

  /// GlanceCore clears the status and due date of a line that is not a checklist item.
  private func setKind(_ kind: LineKind) {
    state.perform { try $0.update(task.id) { $0.kind = kind } }
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
