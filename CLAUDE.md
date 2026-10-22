# Glance

Native macOS 26 SwiftUI to-do widget. `docs/PLAN.md` is the source of truth. Read it before starting a thread. When a decision changes, update `docs/PLAN.md` in the same PR.

## Commands

| Task | Command |
|---|---|
| Run every check (CI runs the same script) | `scripts/check.sh` |
| Package build and tests | `swift build`, `swift test` |
| Generate the Xcode project | `xcodegen generate` |
| Build the app | `xcodebuild -scheme Glance -destination 'platform=macOS,arch=arm64' -derivedDataPath DerivedData build` |
| Run the app | `open DerivedData/Build/Products/Debug/Glance.app` |
| Lint | `swiftlint --strict` and `swift format lint --strict -r Sources Tests App Package.swift` |
| Format | `swift format -i -r Sources Tests App Package.swift` |
| Coverage | `swift test --enable-code-coverage`, then `xcrun llvm-cov report` on the path from `swift test --show-codecov-path` |
| Register the MCP server | `scripts/install-mcp.sh` (arrives in T1) |

## Layout

- `Sources/GlanceCore/` holds the models, parser, serializer, task ops, counts, and `FileStore`. The app and `glance-mcp` both use it.
- `Sources/glance-mcp/` is the stdio MCP server. Its tool logic lives in `Sources/GlanceMCP/` so tests can call it without a transport.
- `Tests/GlanceCoreTests/` holds Swift Testing tests. Fixtures live in `Fixtures/*.md`. `Tests/GlanceMCPTests/` tests the MCP tools against a temp `todo.md`.
- `App/Glance/` is the SwiftUI app target.
- `project.yml` defines the Xcode project. The `.xcodeproj` and `App/Glance/Info.plist` are generated and ignored. Never hand-edit them.
- `data/todo.md` is the owner's list. `data/` is gitignored.
- `docs/decisions/` holds the ADRs.

## Rules

- Never commit anything under `data/`. `scripts/check.sh` fails if you do.
- Run `scripts/check.sh` before every commit. Never skip or disable a test.
- The GlanceCore API in `docs/PLAN.md` §5 is frozen after T0. A change to it needs a PR labelled `contract-change`.
- Unknown lines in `todo.md` are preserved. A parse and serialize round trip never loses content.
- No network code: no telemetry, no analytics, no listening ports.
- Every write to `todo.md` goes through `FileStore.write(transform:)`, which is atomic and hash-checked.

## Git

- No pull requests. Each builder agent works on its own branch in its own worktree: `feat/…`, `fix/…`, `chore/…`, `docs/…`. One branch per issue, near 400 changed lines or fewer.
- A verifier agent merges, never the builder. It rebases the branch onto `main`, runs `scripts/check.sh`, reviews the diff with `/ponytail-review` (plus light and dark screenshots for UI), then fast-forwards `main`, pushes, and closes the issue. See ADR 0005.
- Conventional Commits, imperative subject of 72 characters or fewer. Each commit is one logical change that builds and passes tests. No filler, empty, or backdated commits.
- Commit messages and issue comments carry no AI attribution lines. The owner is the sole author.

## Skills

Use the `ponytail` and `pstack` plugins on every thread.

- **ponytail** is always on at level full: the smallest change that fully solves the task. The verifier runs `/ponytail-review` on each branch before it merges. Run `/ponytail-debt` at the end of each thread to list `shortcut:` comments.
- **pstack** is the working method. Most pstack skills refuse the Skill tool, so read `~/.claude/plugins/cache/cursor-plugins/pstack/<version>/skills/<name>/SKILL.md` and follow it. Read `docs/harness/claude-code.md` in that folder once per session first.
  - `poteto-mode` for the overall style and playbooks: Feature for each thread, Bug fix for defects, Opening a PR at the end.
  - `tdd` for GlanceCore and glance-mcp. Fixtures and failing tests come first.
  - `principle-model-the-domain` and `principle-type-system-discipline` for models and state machines, such as the hover state machine in T2.
  - `principle-separate-before-serializing-shared-state` and `principle-make-operations-idempotent` for `FileStore` and the T4 concurrent-write path.
  - `technical-writing` for docs, ADRs, PR descriptions, and commit messages.
  - `principle-prove-it-works` before you mark anything done.
- If a skill conflicts with `docs/PLAN.md` §2, §2 wins. Tell the owner about the conflict.
- pstack's shipping playbook wants an independent review before merge. The verifier agent is that review.
