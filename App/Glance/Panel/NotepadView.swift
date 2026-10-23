import GlanceCore
import SwiftUI

private let focusNewLine = Notification.Name("GlanceFocusAddField")

/// A page shown as a document: one editable text view, with "Clear N done" below it.
struct NotepadView: View {
  let state: AppState
  /// nil means the first page, made on the first save.
  let category: String?
  let lines: [String]
  @State private var handle = EditorHandle()
  @State private var doneCount = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      PageEditor(
        state: state, page: category, lines: lines, handle: handle,
        doneCountChanged: { doneCount = $0 })
      if doneCount > 0 { clearDone }
    }
    .onChange(of: lines, initial: true) { doneCount = PageText.doneCount(lines: lines) }
    .background {
      Button("Focus page") { handle.focusEnd() }
        .keyboardShortcut(.space, modifiers: .option)
        .opacity(0).accessibilityHidden(true)
    }
    .onReceive(NotificationCenter.default.publisher(for: focusNewLine)) { _ in
      handle.focusEnd()
    }
  }

  private var clearDone: some View {
    HStack {
      Spacer()
      Button("Clear \(doneCount) done") { handle.clearDone() }
        .buttonStyle(.plain)
        .font(.mono(11))
        .foregroundStyle(.secondary)
    }
  }
}
