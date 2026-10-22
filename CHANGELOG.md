# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] - unreleased

### Added
- GlanceCore: parse and serialize `todo.md` without losing lines, with task, category and suggestion operations and counts.
- Atomic, hash-checked file store with a change watcher.
- `glance-mcp` server with tools, an `extract_tasks` prompt and a tasks resource, embedded in `Glance.app`.
- `scripts/install-mcp.sh` and a config merge script for Claude Desktop, plus a Settings window to connect it.
- Floating ball and list as non-activating panels, with corner snapping and a hover state machine.
- Ball count in JetBrains Mono, a pulse when the count changes, a due tint and VoiceOver labels.
- List panel with header, tabs, categories, task rows, per-task notes and drag and drop between categories.
- Add field with quick due dates, a Suggested section with accept and dismiss, and a butterfly watermark.
- Menu bar extra, launch at login and a global Option-Space shortcut.

### Fixed
- Count every task in the category delete dialog, surface edit errors and fit tabs at 340pt.
- Keep due and notes when `update_task` omits them.
- Watch a missing data directory and skip deleted-file events.
- Work around a Swift 6.3 IRGen crash in the status picker.

### Other
- CI on a macOS 26 runner for lint, tests and the app build, on every branch push, with a 90% GlanceCore coverage gate.
- CI finds the test bundle under both Swift 6.3 and 6.4.
- Project scaffold: Swift package, XcodeGen app and lint config; `data/` and build output are gitignored.
- Docs: project plan, CLAUDE.md, architecture, ADRs (including skipping ChatGPT desktop), README and the frozen GlanceCore contract.
- `scripts/check.sh` also runs the MCP config merge self-test.
- App test target over `AppState`.
