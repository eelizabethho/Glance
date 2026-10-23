# 0010: A page is one native text view

Status: accepted. Replaces the per-line fields of 0009; line kinds stay. This is a `contract-change` to the GlanceCore API frozen in PLAN §5.

## Context

Each line was its own `TextField`. Backspace on an empty line moved focus up and macOS selected the whole line above, so the next Backspace wiped it. There was also no cross-line selection, arrow-key movement, undo, or drag to reorder. The owner wants it to behave like Apple Notes.

## Decision

- A page is one `NSTextView` (`NotesTextView`). Every paragraph is a line. The leading marker shows its kind: `☐ `, `☑ ` (struck through), `• `, a bold paragraph for a heading, or plain text. Cursor, selection, arrows, undo and drag-to-move are AppKit's.
- `NotesTextView` adds the Notes list behaviours: Return continues or ends a list, Backspace removes a marker or deletes an empty line, `[] `, `- ` and `# ` convert a line, clicking a box toggles it, and ⇧⌘L toggles a checklist.
- `PageText` converts between markdown lines and the attributed text. Every line round-trips. Plain lines are raw entries in the file.
- GlanceCore gains `replaceBody(of:with:)` and `bodyLines(of:)`. `replaceBody` parses the lines, and a task that keeps its kind and text keeps its id, notes and suggestion.
- Edits save through `AppState.perform` about 0.5 s after typing stops, and when the editor loses focus. The editor reloads from the file only while it is not focused and has no unsaved edits, so a later save wins over an outside change through the same hash-checked write.

## Consequences

- Natural-language due dates in quick add (`parseQuickAdd`) no longer run. A due date is typed as `📅 2026-10-26`.
- A plain line that looks like a note (`  > x`) reads back as a note on the line above.
- Plain lines are ignored by counts, reminders and MCP.
