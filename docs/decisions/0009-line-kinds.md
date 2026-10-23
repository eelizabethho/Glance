# 0009: Three line kinds

Status: accepted. Supersedes the line part of 0008; pages stay. This is a `contract-change` to the GlanceCore API frozen in PLAN §5.

## Context

0008 made every line a task, so a plain note had to be a checkbox line or a heading. The owner wants checklists, plain bullets, and headings on the same page.

## Decision

- `GlanceTask.isHeading` becomes `kind: LineKind`: `.checklist` (`- [ ] text`, the default), `.bullet` (`- text`), `.heading` (`### text`).
- Only a checklist line has a status, due date, done date, or suggestion, and only it is counted or reminded. Changing a line to another kind clears that state.
- A crossed-out checklist line is `completed` (old `cancelled` reads the same). `removeCompleted(in:)` removes them from one page in one write.
- `- [` and other bracket-led `- ` lines that are not a valid checkbox stay raw lines.
- `glance-mcp` lists `kind` instead of `isHeading`.
- The panel always ends a page with a draft line. Its marker cycles the new line's kind.

## Consequences

Existing `- text` raw lines now show as bullets. Round trips are unchanged.
