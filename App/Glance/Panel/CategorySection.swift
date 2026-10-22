import GlanceCore
import SwiftUI

/// Dot colours offered for a category. The file has no slot for colour, so it lives in prefs.
private let palette = [
  ("Pink", "#E8A0B4"), ("Blue", "#8FB8DE"), ("Green", "#9CCB9A"), ("Yellow", "#E8D08F"),
  ("Purple", "#B9A3E3"),
]

extension Color {
  init(hex: String) {
    let value = Int(hex.dropFirst(), radix: 16) ?? 0
    self.init(
      red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255)
  }
}

/// A collapsible group: marker, optional dot, bold lowercase name, then its task rows.
struct CategorySection: View {
  let state: AppState
  @Bindable var prefs: PanelPrefs
  let name: String
  let tasks: [GlanceTask]
  @State private var draft: String?
  @State private var confirmingDelete = false
  @FocusState private var fieldFocused: Bool

  private var collapsed: Bool { prefs.collapsed.contains(name) }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Button {
          if collapsed { prefs.collapsed.remove(name) } else { prefs.collapsed.insert(name) }
        } label: {
          HStack(spacing: 6) {
            Text(collapsed ? "•" : "▾").font(.mono(13)).frame(width: 10)
            if let hex = prefs.colors[name] {
              Circle().fill(Color(hex: hex)).frame(width: 7, height: 7)
            }
            if draft == nil { Text(name.lowercased()).font(.mono(13, bold: true)) }
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name), \(collapsed ? "collapsed" : "expanded")")
        .accessibilityHint("Toggles the category")
        if let draft {
          TextField(
            "Category", text: Binding(get: { draft }, set: { self.draft = $0 })
          )
          .textFieldStyle(.plain)
          .font(.mono(13, bold: true))
          .focused($fieldFocused)
          .onSubmit(rename)
          .onExitCommand { self.draft = nil }
          .onAppear { fieldFocused = true }
        }
      }
      .contextMenu { menu }
      .dropDestination(for: String.self) { items, _ in
        dropTask(items, on: state, category: name, before: nil)
      }
      .confirmationDialog(
        deleteCategoryTitle(name, in: state.document), isPresented: $confirmingDelete
      ) {
        Button("Delete", role: .destructive) { state.perform { try $0.removeCategory(name) } }
      }
      if !collapsed {
        ForEach(tasks) { TaskRow(state: state, task: $0) }.padding(.leading, 16)
      }
    }
  }

  @ViewBuilder private var menu: some View {
    Button("Rename…") { draft = name }
    Picker("Colour", selection: $prefs.colors[name]) {
      Text("None").tag(String?.none)
      ForEach(palette, id: \.1) { Text($0.0).tag(String?.some($0.1)) }
    }
    Button("Move Up") { move(by: -1) }
    Button("Move Down") { move(by: 1) }
    Divider()
    Button("Delete Category…", role: .destructive) { confirmingDelete = true }
  }

  private func rename() {
    guard let new = draft?.trimmingCharacters(in: .whitespaces), new != name else {
      draft = nil
      return
    }
    state.perform { try $0.renameCategory(name, to: new) }
    if state.lastError == nil {
      prefs.renameCategory(name, to: new)
      draft = nil
    }
  }

  /// `suggested` stays last; only regular categories swap places.
  private func move(by offset: Int) {
    let names = state.document.categories.map(\.name)
    let regular = names.filter { $0 != GlanceCore.Category.suggested }
    let order = regular.moving(name, by: offset) + names.filter { !regular.contains($0) }
    state.perform { try $0.reorderCategories(order) }
  }
}

/// Moves the dropped task into `category`: before `target`, or to the end when there is none.
func dropTask(_ items: [String], on state: AppState, category: String, before target: TaskID?)
  -> Bool
{
  let id = TaskID(rawValue: items.first ?? "")
  guard id != target, state.document.task(id) != nil else { return false }
  let index = target.flatMap { target in
    state.document.categories.first { $0.name == category }?.tasks.firstIndex { $0.id == target }
  }
  state.perform { try $0.move(id, to: category, at: index) }
  return true
}

struct TaskRow: View {
  let state: AppState
  let task: GlanceTask
  @State private var draft: String?
  @State private var editingDue = false
  @State private var showingNotes = false
  @FocusState private var fieldFocused: Bool

  private var symbol: String {
    switch task.status {
    case .todo: "square"
    case .pending: "square.lefthalf.filled"
    case .completed: "checkmark.square"
    case .cancelled: "xmark.square"
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      row
      if showingNotes { NotesArea(state: state, task: task) }
    }
    .draggable(task.id.rawValue)
    .dropDestination(for: String.self) { items, _ in
      dropTask(items, on: state, category: task.category, before: task.id)
    }
    .contextMenu {
      Button("Edit") { draft = task.text }
      Picker("Status", selection: Binding(get: { task.status }, set: { setStatus($0) })) {
        ForEach(TaskStatus.allCases, id: \.self) { Text($0.title).tag($0) }
      }
      Button(task.due == nil ? "Set Due Date…" : "Change Due Date…") { editingDue = true }
      if task.due != nil { Button("Clear Due Date") { setDue(nil) } }
      Divider()
      Button("Delete", role: .destructive) { state.perform { try $0.remove(task.id) } }
    }
    .popover(isPresented: $editingDue) { DueEditor(due: task.due, save: setDue) }
  }

  private var row: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Button {
        setStatus(task.status.toggled)
      } label: {
        Image(systemName: symbol).font(.system(size: 13))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(
        task.status == .completed ? "Mark \(task.text) to-do" : "Complete \(task.text)")
      if let draft {
        TextField("Task", text: Binding(get: { draft }, set: { self.draft = $0 }))
          .textFieldStyle(.plain)
          .font(.mono(13))
          .focused($fieldFocused)
          .onSubmit(commit)
          .onExitCommand { self.draft = nil }
          .onAppear { fieldFocused = true }
      } else {
        HStack(spacing: 4) {
          Text(dueLabel(task))
            .font(.mono(13))
            .strikethrough(task.status == .cancelled)
            .foregroundStyle(
              task.status == .todo || task.status == .pending ? .primary : .secondary
            )
            .accessibilityLabel("\(dueLabel(task)), \(task.status.title)")
          if task.notes != nil {
            Text("≡").font(.mono(13)).foregroundStyle(.secondary).accessibilityLabel("Has notes")
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { draft = task.text }
        .onTapGesture { showingNotes.toggle() }
      }
    }
  }

  private func setStatus(_ status: TaskStatus) {
    state.perform { try $0.setStatus(task.id, status, today: CalendarDay(.now)) }
  }

  private func setDue(_ due: DueDate?) {
    state.perform { try $0.update(task.id) { $0.due = due } }
  }

  private func commit() {
    if let draft, draft != task.text {
      state.perform { try $0.update(task.id) { $0.text = draft } }
      if state.lastError != nil { return }
    }
    draft = nil
  }
}

/// Notes under a row: links while reading, a small editor after the pencil or a double-click.
private struct NotesArea: View {
  let state: AppState
  let task: GlanceTask
  @State private var draft: String?
  @FocusState private var focused: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      if let draft {
        TextEditor(text: Binding(get: { draft }, set: { self.draft = $0 }))
          .font(.mono(12))
          .frame(height: 54)
          .focused($focused)
          .onAppear { focused = true }
          .onChange(of: focused) { if !focused { commit() } }
          .onKeyPress(.return, phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            commit()
            return .handled
          }
      } else {
        Text(task.notes.map { linkified($0) } ?? AttributedString("No notes"))
          .font(.mono(12))
          .foregroundStyle(task.notes == nil ? .secondary : .primary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .onTapGesture(count: 2) { draft = task.notes ?? "" }
        Button {
          draft = task.notes ?? ""
        } label: {
          Image(systemName: "pencil").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit notes")
      }
    }
    .padding(.leading, 21)
  }

  private func commit() {
    guard let text = draft else { return }
    draft = nil
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    state.perform { try $0.update(task.id) { $0.notes = trimmed.isEmpty ? nil : trimmed } }
  }
}

private struct DueEditor: View {
  let save: (DueDate?) -> Void
  @State private var date: Date
  @State private var withTime: Bool
  @Environment(\.dismiss) private var dismiss

  init(due: DueDate?, save: @escaping (DueDate?) -> Void) {
    self.save = save
    let parts = due.map {
      DateComponents(
        year: $0.day.year, month: $0.day.month, day: $0.day.day, hour: $0.time?.hour ?? 9,
        minute: $0.time?.minute ?? 0)
    }
    _date = State(initialValue: parts.flatMap(Calendar.current.date(from:)) ?? .now)
    _withTime = State(initialValue: due?.time != nil)
  }

  var body: some View {
    Form {
      DatePicker("Date", selection: $date, displayedComponents: .date)
      Toggle("Time", isOn: $withTime)
      if withTime { DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute) }
      HStack {
        Spacer()
        Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
        Button("Set") {
          save(DueDate(date, withTime: withTime))
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding()
    .frame(width: 260)
  }
}
