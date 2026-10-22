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

struct TaskRow: View {
  let state: AppState
  let task: GlanceTask
  @State private var draft: String?
  @State private var editingDue = false
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
        Text(dueLabel(task))
          .font(.mono(13))
          .strikethrough(task.status == .cancelled)
          .foregroundStyle(task.status == .todo || task.status == .pending ? .primary : .secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
          .onTapGesture(count: 2) { draft = task.text }
          .accessibilityLabel("\(dueLabel(task)), \(task.status.title)")
      }
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
