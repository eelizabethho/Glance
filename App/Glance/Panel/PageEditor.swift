import AppKit
import GlanceCore
import SwiftUI

/// Lets the page's other controls reach its text view.
final class EditorHandle {
  fileprivate weak var view: NotesTextView?

  /// Focuses the editor with the cursor at the end of the page.
  func focusEnd() {
    guard let view else { return }
    view.window?.makeFirstResponder(view)
    view.setSelectedRange(NSRange(location: (view.string as NSString).length, length: 0))
    view.scrollRangeToVisible(view.selectedRange())
  }

  func clearDone() { view?.removeDone() }
}

/// One page as an editable text view. Edits save about half a second after typing stops, and on blur.
struct PageEditor: NSViewRepresentable {
  let state: AppState
  /// nil until the first page exists; the first save makes it.
  let page: String?
  /// The page in the document, shown whenever the user isn't editing.
  let lines: [String]
  let handle: EditorHandle
  let doneCountChanged: (Int) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeNSView(context: Context) -> NotesTextView {
    let view = NotesTextView.make()
    view.load(lines: lines)
    view.onEdit = { [coordinator = context.coordinator] in coordinator.edited() }
    view.onResign = { [coordinator = context.coordinator] in coordinator.flush() }
    context.coordinator.view = view
    handle.view = view
    return view
  }

  func updateNSView(_ view: NotesTextView, context: Context) {
    handle.view = view
    view.setAccessibilityLabel("Page \(page ?? "")")
    context.coordinator.update(self)
  }

  static func dismantleNSView(_ view: NotesTextView, coordinator: Coordinator) {
    coordinator.flush()
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView view: NotesTextView, context: Context)
    -> CGSize?
  {
    let width = proposal.width ?? 300
    guard let layout = view.layoutManager, let container = view.textContainer else { return nil }
    container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
    layout.ensureLayout(for: container)
    // Tall enough that a click below the last line still lands in the editor.
    return CGSize(width: width, height: max(ceil(layout.usedRect(for: container).height), 160))
  }

  final class Coordinator {
    var parent: PageEditor
    weak var view: NotesTextView?
    private var page: String?
    private var unsaved = false
    /// The one pending save; nothing runs while idle.
    private var pending: Task<Void, Never>?

    init(_ parent: PageEditor) {
      self.parent = parent
      page = parent.page
    }

    func edited() {
      unsaved = true
      pending?.cancel()
      pending = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .milliseconds(500))
        if !Task.isCancelled { self?.flush() }
      }
      if let view { parent.doneCountChanged(view.doneCount) }
    }

    func flush() {
      pending?.cancel()
      pending = nil
      guard unsaved, let view else { return }
      unsaved = false
      save(view.lines, to: page)
    }

    func update(_ new: PageEditor) {
      parent = new
      guard let view else { return }
      if new.page != page {
        if unsaved {
          // Saving changes observed state, which a view update must not do.
          let (lines, old) = (view.lines, page)
          unsaved = false
          pending?.cancel()
          Task { @MainActor in self.save(lines, to: old) }
        }
        page = new.page
        view.load(lines: new.lines)
      } else if !unsaved, view.window?.firstResponder !== view, view.lines != new.lines {
        view.load(lines: new.lines)
      }
    }

    private func save(_ lines: [String], to page: String?) {
      let name = page ?? GlanceDocument.defaultCategory
      guard parent.state.document.bodyLines(of: name) != lines else { return }
      parent.state.perform { doc in
        if !doc.categories.contains(where: { $0.name == name }) { try doc.addCategory(name) }
        try doc.replaceBody(of: name, with: lines)
      }
    }
  }
}
