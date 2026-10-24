# 0012: Completed is a view; the file keeps done lines in place

Status: accepted. No GlanceCore API change.

## Context

Crossed-out lines cluttered each page, and "Clear N done" deleted them for good. The owner wants them out of sight but recoverable.

## Decision

- A crossed-out line stays in its page of `todo.md` as `- [x] … ✅ date`. Nothing moves between `##` sections.
- The page editor shows only lines that aren't crossed out. A line just crossed out stays struck through for about 2 s, so a mis-click can be undone, then the editor drops it. The hide is a one-shot task, so idle CPU stays 0.
- A save merges the editor's lines with the file as it is at write time (`PageEditor.merged`). A line the editor never showed goes back after the line that preceded it, so a crossed-out line is never lost by a save, an indent, or an MCP write, and unchecking restores it at its original place.
- **Completed** is a built-in tab at the end of the page row, not a `##` category. It lists every crossed-out checklist line on every page, newest done first, with its page name. Unchecking restores the line. Right-click → Delete removes one, "Clear all" removes all in one write.
- Hovering the tab shows a ✕ that only hides it. Settings "Show Completed tab" (`showCompleted`, default on) brings it back.
- The ball count is unchanged: crossed-out lines don't count.

## Consequences

- "Clear N done" is gone from the format bar.
- With one page, the row shows that page and Completed.
