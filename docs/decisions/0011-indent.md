# 0011: Lines indent by two spaces per level

Status: accepted. Adds `GlanceTask.indent` to the GlanceCore API in PLAN §5, a `contract-change`.

## Context

The owner wants Tab and Shift-Tab to nest a line, as in Apple Notes.

## Decision

- `- [ ] `, `- [x] ` and `- ` lines may start with up to four pairs of spaces. The count is `indent` (0...4) and serializes back as two spaces per level. Headings never indent.
- Any other leading spacing (an odd count, more than four pairs, a heading, plain text) stays a raw line. Raw lines already round-trip, so nothing is lost.
- A note line needs `>` after its spaces and a task line needs `-`, so the two never collide.
- The editor shows indent as paragraph indent through a `.glanceIndent` attribute, not as visible spaces. `PageText` converts between the two.
- Counts, reminders and MCP are unchanged. MCP task JSON gains an `indent` field.

## Consequences

- A task's id and its notes do not depend on indent, so moving a line between levels keeps both.
- Indent is presentation only: a task with a different indent is still the same task.
