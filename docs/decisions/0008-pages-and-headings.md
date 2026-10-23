# 0008: Pages and headings replace status tabs and bullets

Status: accepted. Supersedes 0007. This is a `contract-change` to the GlanceCore API frozen in PLAN §5.

## Context

The panel was cluttered: five status tabs, custom filter tabs, collapsible categories, checklist and bullet kinds, and an always-visible empty line. The owner wants a plain notepad with their own pages.

## Decision

- A page is a `##` category. There are no built-in pages or tabs. The first line typed into an empty file creates `## notes`.
- A line is a task. A crossed-out line is `completed`; a plain line is `todo`. The dot toggles it with `setStatus`. Old `cancelled` lines render crossed out and `pending` lines plain.
- `GlanceTask.isNote` becomes `isHeading`. A heading serialises as `### text` inside a category, with no status marker and no due, done, or suggestion tokens. Notes under it are kept.
- Headings are never counted by `Counts.todo` or `Counts.dueTodayOrOverdue`, and never get reminders (they have no due date).
- `TaskOps.defaultCategory` changes from `inbox` to `notes`.
- `glance-mcp` lists `isHeading` instead of `isNote` in task JSON.

## Consequences

`- text` bullets from 0007 become raw lines. They are preserved and no longer shown as lines. The owner's data has none. `## inbox` in an existing file stays a page named `inbox` until renamed.
