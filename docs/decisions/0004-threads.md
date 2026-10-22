# 0004. Run T1–T3 as a lead session with subagents in worktrees

**Status:** accepted, 2026-10-22

## Context
`docs/PLAN.md` §9.1 offers three ways to run the threads after T0: A (one session, in order), B (parallel sessions the owner opens), and C (a lead session with subagents in isolated worktrees). The owner asked for speed and parallel work. T0 already used option C for `FileStore` and the GitHub tracking setup, and both came back clean.

## Decision
Option C.

- **T1 (MCP)** goes to a subagent right away. It touches only `Sources/glance-mcp/`, its tests, and `scripts/install-mcp.sh`. GlanceCore is frozen, so nothing it needs can move under it.
- **T2 (ball and window) and T3 (list panel)** both live in `App/Glance/` and share `AppState`. The lead first lands a small app-skeleton PR that defines `AppState` and the folder split (`Ball/`, `Panel/`, `Settings/`). After that, T2 and T3 run as two subagents. Each one edits only its own folder.
- **T4 (live sync and reminders)** wires `FileStore.changes` into `AppState`, so it touches both halves. The lead does it after T2 and T3 merge.
- A verifier agent reviews and merges each branch in dependency order (ADR 0005).
- No A2A. §9.1 rules it out, and git branches plus PRs already coordinate the agents.

## Consequences
- XcodeGen picks up new files by folder, so parallel threads rarely touch `project.yml`. When they do, the conflict is a few lines of YAML.
- Builders never wait on each other's PRs. The verifier merges each branch to `main` as soon as it passes.
