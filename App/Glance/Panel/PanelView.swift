import GlanceCore
import SwiftUI

extension Font {
  static func mono(_ size: CGFloat, bold: Bool = false) -> Font {
    .custom(bold ? "JetBrainsMono-Bold" : "JetBrainsMono-Regular", size: size)
  }
}

private let focusAddField = Notification.Name("GlanceFocusAddField")

/// The list: date header, tabs, then the active tab's tasks grouped by category.
struct PanelView: View {
  let state: AppState
  @State private var prefs: PanelPrefs
  @State private var showingSettings = false
  @State private var newText = ""
  @FocusState private var addFocused: Bool

  init(state: AppState, prefs: PanelPrefs = PanelPrefs()) {
    self.state = state
    _prefs = State(initialValue: prefs)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      TabBar(prefs: prefs, categories: regularCategories.map(\.name))
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          let tab = prefs.currentTab
          let tasks = tab?.filter.tasks(in: state.document, now: .now) ?? []
          // The To-do tab keeps empty categories visible so they can still be managed.
          let showEmpty = tab?.isStatus == true && tab?.filter.statuses == [.todo]
          ForEach(regularCategories, id: \.name) { category in
            let rows = tasks.filter { $0.category == category.name }
            if showEmpty || !rows.isEmpty {
              CategorySection(state: state, prefs: prefs, name: category.name, tasks: rows)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      if let error = state.lastError {
        Text(String(describing: error)).font(.system(size: 11)).foregroundStyle(.red).lineLimit(2)
      }
      addField
    }
    .padding(16)
    .onReceive(NotificationCenter.default.publisher(for: focusAddField)) { _ in addFocused = true }
  }

  /// The last-used category, or the first regular one when it is gone.
  private var addCategory: String? {
    let names = regularCategories.map(\.name)
    return names.first { $0 == prefs.addCategory } ?? names.first
  }

  private var addField: some View {
    HStack(spacing: 6) {
      TextField("Add new todo", text: $newText)
        .textFieldStyle(.plain)
        .font(.mono(13))
        .focused($addFocused)
        .onSubmit { submit() }
      Menu(addCategory ?? "") {
        ForEach(regularCategories, id: \.name) { category in
          Button(category.name) { prefs.addCategory = category.name }
        }
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
      .font(.mono(12))
      .accessibilityLabel("Category for new todo")
      Button {
        submit()
      } label: {
        Image(systemName: "plus").font(.mono(13))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Add todo")
    }
  }

  private func submit() {
    let parsed = parseQuickAdd(newText, now: .now, calendar: .current)
    state.perform { try $0.add(parsed.text, category: addCategory, due: parsed.due) }
    if state.lastError == nil {
      newText = ""
      addFocused = true
    }
  }

  private var regularCategories: [GlanceCore.Category] {
    state.document.categories.filter { !$0.isSuggested }
  }

  private var header: some View {
    ZStack {
      // Redraws each minute so the date turns over at midnight.
      TimelineView(.everyMinute) { context in
        Text(headerDate(context.date)).font(.mono(12)).foregroundStyle(.secondary)
      }
      HStack {
        Spacer()
        Button {
          showingSettings = true
        } label: {
          Image(systemName: "gearshape").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        // shortcut: empty placeholder, the Settings window replaces it in #20.
        .popover(isPresented: $showingSettings) {
          Text("Settings").font(.mono(12)).padding()
        }
      }
    }
  }
}

/// Segmented control of every visible tab; the active one is a pill.
private struct TabBar: View {
  @Bindable var prefs: PanelPrefs
  let categories: [String]
  @State private var editing: PanelTab?

  private var current: PanelTab? { prefs.currentTab }

  var body: some View {
    HStack(spacing: 4) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 0) {
          ForEach(prefs.tabs.filter { !$0.isHidden }) { tab in
            let selected = tab.id == current?.id
            Button(tab.name) { prefs.selectedTab = tab.id }
              .buttonStyle(.plain)
              .font(.mono(12))
              .foregroundStyle(selected ? .primary : .secondary)
              .padding(.horizontal, 3)
              .padding(.vertical, 4)
              .background {
                if selected {
                  Capsule().fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.1), radius: 1, y: 0.5)
                }
              }
              .accessibilityAddTraits(selected ? .isSelected : [])
              .contextMenu { menu(for: tab) }
          }
        }
        .padding(2)
        .background(Capsule().fill(.quaternary))
      }
      Menu {
        if let current { menu(for: current) }
        Divider()
        Button("New Tab…") { editing = PanelTab(name: "", filter: TabFilter()) }
        ForEach(prefs.tabs.filter(\.isHidden)) { tab in
          Button("Show \(tab.name)") { update(tab.id) { $0.isHidden = false } }
        }
      } label: {
        Image(systemName: "ellipsis")
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .fixedSize()
      .accessibilityLabel("Tab options")
    }
    .popover(item: $editing) { tab in
      TabEditor(tab: tab, categories: categories) { saved in
        if prefs.tabs.contains(where: { $0.id == saved.id }) {
          update(saved.id) { $0 = saved }
        } else {
          prefs.tabs.append(saved)
          prefs.selectedTab = saved.id
        }
      }
    }
  }

  @ViewBuilder private func menu(for tab: PanelTab) -> some View {
    Button(tab.isStatus ? "Rename “\(tab.name)”…" : "Edit “\(tab.name)”…") { editing = tab }
    Button("Move Left") { prefs.tabs = prefs.tabs.moving(tab, by: -1) }
    Button("Move Right") { prefs.tabs = prefs.tabs.moving(tab, by: 1) }
    if tab.isStatus {
      Button("Hide “\(tab.name)”") { update(tab.id) { $0.isHidden = true } }
    } else {
      Button("Delete “\(tab.name)”", role: .destructive) {
        prefs.tabs.removeAll { $0.id == tab.id }
      }
    }
  }

  private func update(_ id: UUID, _ change: (inout PanelTab) -> Void) {
    guard let index = prefs.tabs.firstIndex(where: { $0.id == id }) else { return }
    change(&prefs.tabs[index])
  }
}

private struct TabEditor: View {
  @State var tab: PanelTab
  let categories: [String]
  let save: (PanelTab) -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Form {
      TextField("Name", text: $tab.name)
      if !tab.isStatus {
        Section("Categories (none means all)") {
          ForEach(categories, id: \.self) { Toggle($0, isOn: $tab.filter.categories.has($0)) }
        }
        Section("Status (none means all)") {
          ForEach(TaskStatus.allCases, id: \.self) {
            Toggle($0.title, isOn: $tab.filter.statuses.has($0))
          }
        }
        Picker("Due", selection: $tab.filter.due) {
          Text("Any").tag(TabFilter.Due?.none)
          Text("Today or overdue").tag(TabFilter.Due?.some(.todayOrOverdue))
          Text("Overdue").tag(TabFilter.Due?.some(.overdue))
        }
      }
      HStack {
        Spacer()
        Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
        Button("Save") {
          tab.name = tab.name.trimmingCharacters(in: .whitespaces)
          save(tab)
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(tab.name.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
    .padding()
    .frame(width: 280)
  }
}

extension Binding {
  /// A toggle for one member of a set.
  func has<Element: Hashable>(_ element: Element) -> Binding<Bool> where Value == Set<Element> {
    Binding<Bool>(
      get: { wrappedValue.contains(element) },
      set: { if $0 { wrappedValue.insert(element) } else { wrappedValue.remove(element) } })
  }
}
