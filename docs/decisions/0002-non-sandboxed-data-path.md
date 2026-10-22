# 0002. Ship unsandboxed and read a fixed data path

**Status:** accepted, 2026-10-22

## Context
The list lives at `~/workspace/notes-reminder/data/todo.md` so the owner, a text editor, and the MCP server all see one file. A sandboxed app could reach that path only through a user-granted bookmark. Glance is distributed outside the App Store.

## Decision
- The app and `glance-mcp` run without the App Sandbox.
- The default data path is `~/workspace/notes-reminder/data/todo.md`. `glance-mcp` takes the path as an argument.
- `data/` is gitignored from the first commit. `scripts/check.sh` fails CI if any file under `data/` is tracked.
- Hardened runtime stays on.

## Consequences
Glance can never ship on the Mac App Store without a bookmark-based redesign. Owner data stays out of git by two independent guards.
