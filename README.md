# Glance

Glance is a native macOS to-do widget: a floating ball that opens a list of your tasks. The list is a plain Markdown file, so you, a text editor, and an AI assistant (through a local MCP server) all see the same data. Nothing leaves your Mac.

## Build

```sh
xcodegen generate
xcodebuild -scheme Glance -destination 'platform=macOS,arch=arm64' -derivedDataPath DerivedData build
```

The build embeds `glance-mcp` in `Glance.app/Contents/MacOS/`.

## Data

Your list is `~/workspace/notes-reminder/data/todo.md`. `data/` is gitignored and never committed.

## MCP setup (Claude Desktop)

Copy `Glance.app` to `/Applications`, run `scripts/install-mcp.sh`, review the diff, confirm, then restart Claude Desktop. The script backs up your old config first.

Add this to your Claude custom instructions:

> You have Glance. When I mention something I need to do, call `suggest_tasks`. Only call `add_task` when I explicitly say 'add'.

## ChatGPT desktop

Not supported: see [ADR 0006](docs/decisions/0006-chatgpt-desktop.md).
