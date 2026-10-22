# 0003. Keep the app and the MCP server in one Swift codebase

**Status:** accepted, 2026-10-22

## Context
The app and the MCP server both read and write `todo.md`. If they parsed it with separate code, they could disagree about the format and lose lines.

## Decision
One Swift package holds `GlanceCore`, which owns the parser, serializer, task ops, and `FileStore`. The app links `GlanceCore` through XcodeGen. `glance-mcp` is an executable target in the same package and ships inside `Glance.app/Contents/MacOS/`.

## Consequences
One language, one test suite, and one CI job. The MCP server needs the official MCP Swift SDK rather than a TypeScript or Python SDK.
