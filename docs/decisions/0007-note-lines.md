# 0007: Bullet lines in `todo.md`

Status: accepted. This is a `contract-change` to the GlanceCore API frozen in PLAN §5.

## Context

The panel became a notepad: the owner types lines directly, as in Apple Notes, and some lines are plain bullets, not checklist items. The file had no way to say "this line is not a task".

## Decision

- `GlanceTask` gets `isNote: Bool`, default `false`.
- A note serialises as `- text`. A checklist item stays `- [ ] text`. Notes have status `todo`, and the due, notes, and suggestion tokens work as before.
- Notes are never counted by `Counts.todo` or `Counts.dueTodayOrOverdue`.
- Parsing: `- ` followed by a character other than `[` or whitespace is a note. Other `-` lines (`- [?] x`, `-  x`) stay raw lines, so a round trip loses nothing.
- `glance-mcp` lists `isNote` in task JSON.

## Consequences

Hand-written `- thing` lines in an existing file become notes on first parse and serialise back unchanged. A note whose text starts with `[` cannot be written as a note.
