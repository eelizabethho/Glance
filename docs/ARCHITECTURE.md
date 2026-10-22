# Architecture

`docs/PLAN.md` §3 holds the diagram and the rules. This page records how the repo implements them.

## Parts

- **GlanceCore** is a Swift package library with no UI and no isolation default. It owns the `todo.md` format (`docs/PLAN.md` §5).
- **Glance.app** is an XcodeGen target that links GlanceCore. It owns the ball, the panel, reminders, and the menu-bar item. UI state lives in `UserDefaults`, never in `todo.md`.
- **glance-mcp** is a package executable that links GlanceCore and speaks MCP over stdio.

## The file is the database

Every writer, whether the app, `glance-mcp`, or a person in an editor, edits `data/todo.md` directly. GlanceCore keeps them consistent:

1. `FileStore.write(transform:)` reads the file and hashes it.
2. It applies the transform to the parsed document.
3. It re-reads the file. If the hash changed, it starts again from step 1.
4. It writes to a temporary file and swaps it in with `replaceItemAt`.

The parser keeps lines it does not understand, so a hand edit never loses content.

## Checks

`scripts/check.sh` is the one list of checks. CI runs it on the hosted `macos-26` runner, and you run it before each commit.
