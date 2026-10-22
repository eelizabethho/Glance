# 0006. Skip ChatGPT desktop setup

**Status:** accepted, 2026-10-22

## Context
PLAN §8.3 asks whether the ChatGPT macOS app can launch local (stdio) MCP servers. Custom MCP connectors in ChatGPT need a remote URL, which breaks the local-only rule in §2.

## Decision
- Add no ChatGPT setup step and ship no tunnel or remote endpoint.
- OpenAI documents custom MCP connections as remote: ChatGPT "connects to remote MCP servers", and a local server needs a Secure MCP Tunnel or a public HTTPS URL. The docs show no stdio entry in the macOS app's config.
- Desktop plugins can bundle "local MCP apps" that run on the computer. The docs do not say whether a plain stdio server like `glance-mcp` can be wrapped this way, so we do not rely on it.

Sources (read 2026-10-22):
- https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt
- https://help.openai.com/en/articles/20001256-plugins-in-chatgpt
- https://platform.openai.com/docs/guides/tools-connectors-mcp

## Consequences
Glance works with Claude Desktop only. Revisit if OpenAI documents stdio servers in the macOS app, or if the plugin route is confirmed to wrap `glance-mcp` without a network listener.
