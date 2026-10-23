import GlanceCore
import AppKit
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
  @State private var kind = NoteKind.plain

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      PageEditor(
        state: state, page: category, lines: lines, handle: handle,
        doneCountChanged: { doneCount = $0 })
      formatBar
    }
    .onReceive(NotificationCenter.default.publisher(for: NSTextView.didChangeSelectionNotification)) { _ in
      kind = handle.kind
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

  private var formatBar: some View {
    HStack(spacing: 4) {
      formatButton("☐", .checklist, label: "Checklist")
      formatButton("•", .bullet, label: "Bullet")
      formatButton("H", .heading, label: "Heading")
      Spacer()
      if doneCount > 0 {
        Button("Clear \(doneCount) done") { handle.clearDone() }
          .buttonStyle(.plain)
          .font(.mono(11))
          .foregroundStyle(.secondary)
      }
    }
  }

  private func formatButton(_ glyph: String, _ target: NoteKind, label: String) -> some View {
    let active = kind == target
    return Button { handle.setKind(target) } label: {
      Text(glyph).font(.mono(12, bold: true)).frame(width: 24, height: 22)
        .foregroundStyle(active ? Color.primary : Color.secondary)
        .background(active ? Color.primary.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .accessibilityAddTraits(active ? .isSelected : [])
    .help(label)
  }
}
