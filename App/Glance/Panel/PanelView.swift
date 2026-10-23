import GlanceCore
import SwiftUI

extension Font {
  static func mono(_ size: CGFloat, bold: Bool = false) -> Font {
    .custom(bold ? "JetBrainsMono-Bold" : "JetBrainsMono-Regular", size: size)
  }
}

/// The page row shows once there is more than one page.
func showsPageRow(pageCount: Int) -> Bool { pageCount > 1 }

/// The panel: date header, an optional row of pages, then the current page as a notepad.
struct PanelView: View {
  let state: AppState
  @Environment(\.openSettings) private var openSettings
  @AppStorage("selectedPage") private var selectedPage = ""
  @AppStorage("showButterfly") private var showButterfly = true
  @AppStorage("clearGlass") private var clearGlass = false
  /// nil when closed; `old` is nil when adding a page and the page's name when renaming it.
  @State private var naming: (old: String?, name: String)?
  @State private var deleting: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      if showsPageRow(pageCount: pages.count) { pageRow }
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          NotepadView(
            state: state, category: current, lines: state.document.bodyLines(of: current ?? ""))
          let suggestions = state.document.categories.first { $0.isSuggested }?.tasks ?? []
          if !suggestions.isEmpty {
            SuggestedSection(
              state: state, tasks: suggestions, defaultCategory: current, categories: pages)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      if let error = state.lastError, error as? TaskOpsError != .emptyText {
        Text(String(describing: error)).font(.system(size: 11)).foregroundStyle(.red).lineLimit(2)
      }
    }
    .padding(.horizontal, 22)
    .padding(.vertical, 18)
    .background(alignment: .bottomTrailing) {
      if showButterfly {
        Butterfly().stroke(.primary, lineWidth: 1).opacity(0.07).frame(width: 70, height: 55)
          .padding(12).allowsHitTesting(false)
      }
    }
    .alert(naming?.old == nil ? "New Page" : "Rename Page", isPresented: isNaming) {
      TextField("Name", text: Binding(get: { naming?.name ?? "" }, set: { naming?.name = $0 }))
      Button("Cancel", role: .cancel) {}
      Button(naming?.old == nil ? "Add" : "Rename") { saveName() }
    }
    .confirmationDialog(
      deleting.map { deleteCategoryTitle($0, in: state.document) } ?? "",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    ) {
      Button("Delete", role: .destructive) { deleting.map(deletePage) }
    }
  }

  private var pages: [String] {
    state.document.categories.filter { !$0.isSuggested }.map(\.name)
  }

  /// The selected page, or the first one when it is gone; nil until the first line makes one.
  private var current: String? { pages.first { $0 == selectedPage } ?? pages.first }

  private var isNaming: Binding<Bool> {
    Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })
  }

  private var addPage: some View {
    Button {
      naming = (nil, "")
    } label: {
      Image(systemName: "plus").foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Add page")
    .help("New page")
  }

  private func saveName() {
    guard let (old, typed) = naming else { return }
    let name = typed.trimmingCharacters(in: .whitespaces)
    state.perform { doc in
      if let old { try doc.renameCategory(old, to: name) } else { try doc.addCategory(name) }
    }
    if state.lastError == nil { selectedPage = name }
  }

  private func deletePage(_ name: String) {
    state.perform { try $0.removeCategory(name) }
  }

  /// An empty page goes without asking.
  private func requestDelete(_ page: String) {
    if state.document.categories.first(where: { $0.name == page })?.tasks.isEmpty == true {
      deletePage(page)
    } else {
      deleting = page
    }
  }

  private var header: some View {
    ZStack {
      // Redraws each minute so the date turns over at midnight.
      TimelineView(.everyMinute) { context in
        Text(headerDate(context.date)).font(.mono(12)).foregroundStyle(.secondary)
      }
      HStack(spacing: 10) {
        Spacer()
        if !showsPageRow(pageCount: pages.count) { addPage }
        Button {
          clearGlass.toggle()
        } label: {
          Image(systemName: "circle.lefthalf.filled").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(clearGlass ? "Use frosted glass" : "Use clear glass")
        Button {
          NSApp.activate()
          openSettings()
        } label: {
          Image(systemName: "gearshape").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
      }
    }
  }

  /// A capsule per page; the selected one is a white pill. Right-click to rename or delete.
  private var pageRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        HStack(spacing: 0) {
          ForEach(pages, id: \.self) { page in
            let selected = page == current
            Button(page) { selectedPage = page }
              .buttonStyle(.plain)
              .font(.mono(11))
              .lineLimit(1)
              // The selected pill is white in both modes, so its text stays black.
              .foregroundStyle(selected ? Color.black : Color.secondary)
              .padding(.horizontal, 8)
              .padding(.vertical, 5)
              .background {
                if selected {
                  Capsule().fill(Color.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.1), radius: 1, y: 0.5)
                }
              }
              .accessibilityAddTraits(selected ? .isSelected : [])
              .contextMenu {
                Button("Rename…") { naming = (page, page) }
                Button("Delete…", role: .destructive) { requestDelete(page) }
              }
          }
        }
        .padding(2)
        .background(Capsule().fill(.quaternary))
        addPage
      }
    }
  }
}
