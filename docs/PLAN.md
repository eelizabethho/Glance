# Glance: Project Plan & Agent Handoff

> **Who this is for:** the Claude instance that will build this project.
> **Planning status:** v2. The owner answered the clarifying questions, and their decisions are in §2. Everything else has a default you can follow without asking.
> **App name:** Glance · **Repo:** `notes-reminder` (private) · **Local folder:** `~/workspace/notes-reminder`

---

## 0. How to use this document (read first)

1. Read the whole file once before writing any code.
2. **Run on the owner's MacBook** (Claude Code in a terminal there). This is a native macOS app, so Xcode and `xcodebuild` must be available. A Linux or cloud session can't build or run it.
3. Do **Thread 0 (Foundation)** first, in order. Then choose how to run the rest using §9.1. **That choice is yours: explain it to the owner in one paragraph, then go.**
4. Copy this file into the repo as `docs/PLAN.md` in the first commit. It's the source of truth. When a decision changes, update it in the same PR as the change.
5. When something is ambiguous, pick the simplest option that fits §1 and §2, record it as a short ADR in `docs/decisions/`, and continue. Ask the owner only about things that change scope.

---

## 1. Product spec

**Glance** is a small, always-available **to-do widget for the Mac**, and it's **fully local**. A frosted glass ball in the top-right corner shows how many tasks are left. Hovering over it opens a translucent panel with your list, and moving away fades the panel so it doesn't cover your work. The list is a plain Markdown file, so the owner's AI apps can add and suggest tasks through a local MCP server ("add 'book friday dinner' to my to-do").

### 1.1 Reference screenshots
These are in `docs/reference/`. The owner will provide them; ask if they're missing.

| Element | Detail |
|---|---|
| **Ball** | Frosted circle under the menu bar, top-right, showing the open count (e.g. `8`). Always on top. |
| **Hover → panel** | The panel (about 340×520 pt, ~18 pt corner radius) expands from the ball's corner. |
| **Header** | Date in light grey, centred (`October 20, Tuesday`). Settings gear at top-right. |
| **Tabs** | A segmented control: `To-do` · `Pending` · `Completed` · `Cancelled`. Active tab is a white pill. |
| **Categories** | Collapsible groups with a `•`/`▾` marker and a bold lowercase label (`work`, `life`, `content`, `study`). |
| **Items** | Square checkbox and monospace text. A due date reads like `Hw 6 – ddl 10/25`. |
| **Add input** | `Add new todo` field with a `+` at the bottom. |
| **Fade** | When the cursor leaves, the panel fades to low opacity, then collapses back to the ball. |
| **Decoration** | Faint line-art butterfly watermark in the bottom-right of the panel. It's optional and can be turned off. |

### 1.2 Requirements

**Must have (v1)**
- **R1 Ball.** Frosted circle showing the **To-do count only** (Pending isn't counted). Starts top-right under the menu bar. **Draggable**, snaps to the nearest corner, and remembers its position. Always on top, on every Space, and over fullscreen apps. Uses about 0% CPU when idle.
- **R2 Hover behaviour.** Hovering opens the panel. When the cursor leaves, the panel fades (default opacity 0.3 after about 600 ms), then collapses to the ball. The fade opacity and delay can be changed in Settings. While the input field has focus, the panel stays open.
- **R3 Tabs.** The four status tabs are fixed (they can be renamed or hidden). The user can also add **custom tabs**, which are saved filters by category, status, or due date (e.g. "Today", "School"). A built-in **Today** preset shows tasks due today or overdue.
- **R4 Categories.** Create, rename, reorder, collapse, and delete, each with an optional colour dot.
- **R5 Tasks.** Add, edit inline, check off, set status, drag to reorder or move between categories, and delete.
- **R6 Per-task notes.** Click a task to expand a short notes field (multi-line, links are clickable). There's no separate notes page in v1.
- **R7 Due dates and reminders.** A task can have a due date and an optional time. Glance shows a **macOS notification** when a task is due (at the set time, or 9:00 for date-only tasks). The ball gets a **soft accent tint** when something is due today or overdue. Notifications can be turned off in Settings.
- **R8 One ongoing list.** The date in the header is just today's date. Tasks stay until they're checked off, and completed tasks move to the Completed tab with their completion date.
- **R9 File is the source of truth.** The list is stored at `~/workspace/notes-reminder/data/todo.md`. Edits made outside the app (by an AI or a text editor) show up in the panel within 1 second.
- **R10 Local MCP server.** Lets Claude Desktop (and ChatGPT desktop, if it supports local MCP; see §8.3) list, add, update, complete, and **suggest** tasks. Suggestions land in a **Suggested** section with ✓ accept / ✕ dismiss buttons.
- **R11 Look and feel.** Apple **Liquid Glass** (macOS 26), **JetBrains Mono** font, **follows the system light/dark mode**.
- **R12 Mac basics.** Menu-bar icon (show/hide, settings, quit), launch at login, and a global shortcut that opens the panel and focuses the input.

**Won't have (v1):** anything that leaves the MacBook (remote MCP, cloud sync, phone or web access), Apple Reminders sync, a notes page, Windows or Linux builds, or support for macOS older than 26.

---

## 2. Owner decisions (locked)

| Topic | Decision |
|---|---|
| Name | **Glance** |
| Platform | **macOS 26 Tahoe only.** Fully local, and nothing leaves the MacBook. |
| Tech | **Native Swift / SwiftUI.** Apple's native Liquid Glass material, not a web view. |
| Font | **JetBrains Mono** (bundled, OFL licence). Weights 400 for items and 700 for category labels. |
| Ball | Frosted circle with the count. Starts top-right and can be dragged to any corner. |
| Panel opening | Hover opens it, leaving fades it, then it collapses. |
| Count | To-do tasks only. |
| Tabs | Four status tabs plus user-defined filter tabs. |
| Notes | Notes on each task only. |
| Days | One ongoing list (no daily reset). |
| Reminders | Due dates, macOS notifications, and a tinted ball when something is due. |
| Theme | Follows the Mac's light/dark setting. |
| AI | **Local MCP only**, for Claude Desktop. ChatGPT desktop is included if it supports local servers (§8.3). |
| Folder | Code and data both go in `~/workspace/notes-reminder`. Data is in `data/`, which is **gitignored**. |
| Repo | Private GitHub repo `notes-reminder`. |
| Reviews | **Claude merges its own PRs when CI is green.** The owner looks in whenever they want. |
| Threads | **The build Claude decides** using §9.1 and tells the owner which option it picked. |

---

## 3. Architecture

```
~/workspace/notes-reminder/            (git repo: notes-reminder, private)
│
├─ GlanceCore  (Swift package library, used by everything below)
│    Models · MarkdownParser · MarkdownSerializer · TaskOps · Counts
│    FileStore (atomic write, hash-checked, FSEvents/DispatchSource watcher)
│
├─ Glance.app  (SwiftUI + a little AppKit)
│    BallPanel   NSPanel, non-activating, .floating level, all Spaces,
│                fullscreen auxiliary, Liquid Glass circle, count, drag + corner snap
│    ListPanel   NSPanel with SwiftUI content, .glassEffect, hover/fade state machine
│    AppState    @Observable, subscribes to FileStore changes
│    Reminders   UserNotifications, rescheduled whenever the file changes
│    MenuBarExtra, SMAppService (launch at login), global hotkey
│
├─ glance-mcp  (Swift executable, official MCP Swift SDK, stdio)
│    Same GlanceCore and FileStore. Bundled inside Glance.app/Contents/MacOS/
│
└─ data/todo.md   ◄── read and written by the app, glance-mcp, and any editor (gitignored)
          ▲
          │ stdio (local process; no network)
   Claude Desktop  /  ChatGPT desktop (if it supports local MCP)
```

**Why one Swift codebase:** the app and the MCP server share a single parser and serializer, so the panel and the AI can never disagree about the file format. It also means one language, one test suite, and one CI job.

**Rules**
- The file is the database. Only UI state lives elsewhere (`UserDefaults`): ball position, collapsed categories, active tab, and custom tab definitions.
- Every write is **atomic** (write to a temp file, then `replaceItemAt`). Before writing, re-read the file, apply the operation to the latest content, and write only if the hash still matches. If it doesn't match, retry. The app ignores watcher events caused by its own writes.
- **Unknown lines are preserved.** A file edited by hand or by an AI must never lose content.
- **No network code at all.** No telemetry, no analytics, and no listening ports.
- **Not sandboxed:** the app is distributed outside the App Store, so it can read the fixed `data/` path. Record this in ADR 0002.

---

## 4. Visual design

- **Material:** Liquid Glass through SwiftUI's `.glassEffect(...)` on macOS 26, for both the ball and the panel. Tune the tint so light mode matches the screenshots (soft white, about 70% opaque) and dark mode uses the same glass with light text.
- **Font:** JetBrains Mono, bundled and registered via `ATSApplicationFontsPath`. Items 13 pt/400, category labels 13 pt/700 lowercase, date 12 pt/400 secondary colour, tabs 12 pt.
- **Colours:** system label colours (`.primary` / `.secondary`) so dark mode works automatically. A soft pink accent `#E8A0B4` for category dots. Due-today/overdue tint on the ball uses the same accent at about 35%.
- **Ball:** 56 pt circle with the count centred at 16 pt medium. It pulses (a scale of 1.0→1.08 that eases back) when the count changes.
- **Motion:** expand 180 ms ease-out, fade 400 ms. Respect **Reduce Motion** and **Reduce Transparency** (fall back to a solid background).
- **Apple Human Interface Guidelines:** follow them for panels, menus, and accessibility. Every control needs a VoiceOver label, and every action should be reachable from the keyboard.

---

## 5. Data format: `data/todo.md` (contract, owned by `GlanceCore`)

```markdown
---
glance: 1
---

## work
- [ ] weekly report
- [ ] traffic analysis
- [/] register for Physical AI conference
  > early-bird ends 11/01
  > https://example.com/conf

## life
- [ ] get groceries
- [ ] book flight ticket 📅 2026-10-26
- [ ] dentist 📅 2026-10-28 14:30
- [x] buy iphone duo cases ✅ 2026-10-21

## study
- [ ] Hw 6 📅 2026-10-25
- [-] old reading list

## suggested
- [ ] book friday dinner 🤖 claude-desktop 2026-10-20
```

| Marker | Status | Tab |
|---|---|---|
| `[ ]` | todo | To-do (counted on the ball) |
| `[/]` | pending | Pending |
| `[x]` | completed | Completed |
| `[-]` | cancelled | Cancelled |

- `## name` starts a category. `suggested` is reserved for AI suggestions. It isn't counted on the ball and is shown as its own section with ✓/✕.
- `📅 YYYY-MM-DD[ HH:mm]` is the due date and optional time. `✅ YYYY-MM-DD` is the completion date. `🤖 <source> <date>` marks a suggestion.
- Indented `> ` lines under a task are that task's notes.
- Task IDs are computed in memory from category, text, and occurrence index. They aren't written to the file.

**GlanceCore API (frozen at the end of Thread 0; changing it needs a PR labelled `contract-change`):**
```swift
enum TaskStatus: String { case todo = " ", pending = "/", completed = "x", cancelled = "-" }
struct CalendarDay      // year, month, day; no time zone, so dates never shift between processes
struct TimeOfDay        // hour, minute
struct DueDate { day: CalendarDay; time: TimeOfDay? }
struct Suggestion { source: String; day: CalendarDay }      // the 🤖 token
struct TaskID { rawValue: String }                          // "category/text#occurrence"
struct GlanceTask: Identifiable { id, category (read-only); text, status, due: DueDate?, doneAt: CalendarDay?,
                                  notes: String?, suggestion: Suggestion? }
struct Category { name (read-only); tasks: [GlanceTask]; isSuggested }
struct GlanceDocument { categories (read-only); tasks; task(_ id:) }   // + preserved unknown lines

MarkdownParser.parse(_ text: String) -> GlanceDocument
MarkdownSerializer.serialize(_ doc: GlanceDocument) -> String   // lossless for every line that is not a task

// Task ops are mutating methods on GlanceDocument and throw TaskOpsError.
add(_:category:due:) -> TaskID ; update(_:_ edit:) -> TaskID ; setStatus(_:_:today:) -> TaskID
move(_:to:at:) -> TaskID ; remove(_:) ; addCategory ; renameCategory(_:to:) ; removeCategory ; reorderCategories
suggest(_:due:source:today:) -> SuggestResult (.added(id) | .duplicate(of: id))   // dedupes against open tasks
acceptSuggestion(_:into:) -> TaskID ; dismissSuggestion(_:)

Counts.todo(doc) -> Int ; Counts.dueTodayOrOverdue(doc, now:, calendar:) -> Int
FileStore(url:): read() -> (GlanceDocument, hash) ; write(_ transform:) throws -> T ; changes: AsyncStream<GlanceDocument>
```
Edits change a task's `id` when they change its text or category, so every op returns the new `id`.

---

## 6. Repository & Git workflow

### 6.1 Setup (Thread 0, step 1)
- `mkdir -p ~/workspace/notes-reminder && cd ~/workspace/notes-reminder && git init -b main`
- Before the first commit, add a `.gitignore` containing at least `data/`, `.build/`, `DerivedData/`, `*.xcodeproj/xcuserdata/`, and `.DS_Store`. **The owner's to-do list must never be committed.** Run `git status` to confirm `data/` doesn't appear.
- Create the private repo and push: `gh repo create notes-reminder --private --source . --remote origin --push`.
- Set `git config user.name` and `user.email` to the owner's GitHub account email, so commits count on their profile.
- Owner tip: turn on **GitHub → Settings → Profile → "Include private contributions on my profile"** so the work shows on the contribution graph.

### 6.2 Layout
```
notes-reminder/
├─ project.yml                 # XcodeGen spec (text file; generate the .xcodeproj, don't hand-edit it)
├─ Package.swift               # GlanceCore library + glance-mcp executable + tests
├─ Sources/GlanceCore/
├─ Sources/glance-mcp/
├─ Tests/GlanceCoreTests/      # fixtures in Tests/GlanceCoreTests/Fixtures/*.md
├─ App/Glance/                 # SwiftUI app target (Ball/, Panel/, Settings/, Reminders/)
├─ App/Glance/Resources/Fonts/ # JetBrains Mono .ttf + OFL.txt
├─ data/                       # gitignored; todo.md lives here
├─ docs/PLAN.md · docs/ARCHITECTURE.md · docs/decisions/ · docs/reference/
├─ scripts/                    # build.sh, install-mcp.sh, screenshot.sh
├─ .github/workflows/ci.yml · .github/pull_request_template.md
├─ .swiftlint.yml · .swift-format
├─ CLAUDE.md
└─ README.md
```

### 6.3 Branches, PRs, merging
- `main` is protected: CI must pass, and history is linear.
- Use one branch per task: `feat/core-parser`, `feat/mcp-tools`, `feat/ball-panel`, `feat/list-ui`, `feat/reminders`, `chore/ci`, `fix/…`.
- Use one PR per GitHub issue, and keep it small (around 400 changed lines or less where possible). The description should cover what changed, how it was verified (with screenshots for UI), and `Closes #N`.
- **Claude merges its own PR once CI is green**, using **"Rebase and merge"** (enable auto-merge). This keeps each meaningful commit on `main`, and the owner doesn't need to approve.

### 6.4 Commits
- Use Conventional Commits: `feat(core): parse due time`, `fix(ball): stay above fullscreen apps`, `test(core): round-trip fixtures`, `docs: ADR 0003 non-sandboxed`.
- **Each commit is one logical change that builds and passes tests.** Commit when a unit of work is done and verified. A normal session produces several commits on its own.
- **Never make filler, empty, or backdated commits.** The history should truthfully show the work.
- Write subjects in the imperative mood, 72 characters or less, with a body explaining *why* when it isn't obvious.
- Push at least at the end of every session.

### 6.5 Tracking
Create a GitHub **Milestone** per phase (§10) and an **Issue** per checklist item in §9, labelled `thread:core|mcp|ball|ui|reminders|qa`. Track them on a GitHub Project board with columns Todo / In progress / Done.

### 6.6 CI (`.github/workflows/ci.yml`, on a macOS runner with Xcode 26)
- `swift build` and `swift test` (GlanceCore and glance-mcp)
- `swiftlint --strict` and a `swift-format lint` check
- `xcodegen generate && xcodebuild -scheme Glance -destination 'platform=macOS' build test`
- A check that fails if any file under `data/` is tracked
- If the hosted runners don't have Xcode 26 yet, run the package tests in CI, build the app locally before merging, and record that in an ADR.

---

## 7. Claude best practices for this project

1. **Write `CLAUDE.md` first.** Include the exact commands (`swift test`, `xcodegen generate`, `scripts/build.sh`, how to run the app, how to register the MCP server), the layout, the contract rule, the commit rules, "never commit `data/`", and "run lint and tests before every commit".
2. **Explore → plan → implement → verify → commit.** Use plan mode at the start of each thread, and put the plan in the GitHub issue.
3. **Write GlanceCore test-first.** Write the fixture files (every marker, notes, due times, unknown lines, empty file, messy hand edits) and the round-trip tests before the parser.
4. **Verify the UI by looking at it.** Build and run the app, take a screenshot (`screencapture -l <windowid>` or `scripts/screenshot.sh`), and compare it to `docs/reference/`. Attach before and after screenshots to UI PRs. Check light and dark mode.
5. **Use XcodeGen** so the project is a readable text file. Never hand-edit `.pbxproj`.
6. **Never mark a task done without running the checks.** Fix root causes, and never skip or disable a test.
7. **Keep context clean.** Use one task per session, and `/clear` between unrelated tasks. Use subagents for research (e.g. "NSPanel over fullscreen apps on macOS 26", "MCP Swift SDK stdio example").
8. **Use hooks and permissions.** Add a format-on-edit hook (`swift-format`) and a project allowlist for `swift`, `xcodebuild`, `xcodegen`, and read-only `git` commands.
9. **Write decisions down as short ADRs** (tech stack, non-sandboxed, data path, threads choice).
10. **Ask the owner only about scope.** For anything else, choose a default, record it, and keep going.

---

## 8. Local MCP server (`glance-mcp`)

### 8.1 Tools
Use the official MCP Swift SDK over **stdio only**. The server opens no network ports.

| Tool | Purpose |
|---|---|
| `list_tasks({ status?, category?, due? })` | Read tasks |
| `get_summary()` | Counts, plus tasks due today or overdue |
| `add_task({ text, category?, due? })` | **Only when the user explicitly asks** to add something. The tool description must say this. |
| `suggest_tasks({ tasks: [{ text, category?, due?, reason }] })` | Writes **only** to `## suggested`. Dedupes against open tasks and returns what it skipped. |
| `update_task({ id, text?, status?, category?, due?, notes? })` | Edit a task |
| `complete_task({ id })` / `cancel_task({ id })` | Shortcuts |
| `list_categories()` / `add_category({ name })` | Manage categories |

Also expose:
- **Prompt** `extract_tasks`: scan this conversation for action items, check `list_tasks`, then call `suggest_tasks`.
- **Resource** `glance://tasks`: the current list as context.

### 8.2 Setup
- The binary ships inside the app at `Glance.app/Contents/MacOS/glance-mcp`, with the file path passed as an argument.
- Settings has a **"Connect Claude Desktop"** button that adds the `mcpServers.glance` entry to `~/Library/Application Support/Claude/claude_desktop_config.json`. Back the file up first and show what will change. `scripts/install-mcp.sh` does the same from the command line.
- Put a custom-instruction snippet in the README for the owner's Claude: *"You have Glance. When I mention something I need to do, call `suggest_tasks`. Only call `add_task` when I explicitly say 'add'."*

### 8.3 ChatGPT desktop
The owner wants this if it's possible. **Check before building** whether the current ChatGPT macOS app can launch **local (stdio) MCP servers**. If it can, add a setup step for it. If it only supports remote connectors (which would need a URL reachable from the internet), **skip it**, because that breaks the local-only rule. Tell the owner in one line, and record it in an ADR.

---

## 9. Threads

### 9.1 How to run the threads (build Claude decides)
Pick one of these after Thread 0, tell the owner which one and why in one paragraph, and record it in `docs/decisions/0004-threads.md`.

| Option | How it works | When to choose it |
|---|---|---|
| **A. One session, in order** | T1 → T2 → T3 → T4 → T5, one PR at a time | **The default.** One Xcode project with shared files means parallel work tends to collide in `project.yml` and app state. |
| **B. Parallel sessions on git worktrees** | After T0, the owner opens 2–3 Claude Code sessions in `git worktree`s: e.g. T1 (MCP, which only touches the package), T2 (ball window), and T3 (list UI using a mock `AppState`) | When contracts are frozen and the threads touch separate folders. Each session works only in its own folders. Rebase before merging. |
| **C. Lead session with subagents** | One session does the integration and hands well-scoped pieces to subagents in isolated worktrees (e.g. "parser fixtures", "MCP tool tests") | For large independent pieces that are easy to review. The lead reviews and merges. |

**Don't use A2A.** Every agent is a Claude Code session in the same repo. Coordinating through contracts, worktrees, and GitHub issues and PRs is simpler and faster.

### 9.2 Order and dependencies
```
T0 Foundation ──► T1 MCP server ──┐
             ├──► T2 Ball & window ┼──► T4 Live sync & reminders ──► T5 QA & release
             └──► T3 List panel UI ┘
(T1 first: Claude can manage data/todo.md through MCP before any UI exists)
```

### T0: Foundation
- [ ] Folder, git, `.gitignore` (confirm `data/` is ignored), private repo, git identity (§6.1)
- [ ] `Package.swift`, `project.yml` (XcodeGen), an empty SwiftUI app that launches, SwiftLint and swift-format
- [ ] `CLAUDE.md`, `docs/PLAN.md`, `docs/ARCHITECTURE.md`, ADRs 0001 (SwiftUI) / 0002 (non-sandboxed, data path) / 0003 (single Swift codebase), PR template, CI
- [ ] **GlanceCore**, test-first: models, parser, serializer, ops (including suggest, dedupe, accept, dismiss), counts, FileStore with atomic writes and a watcher
- [ ] Freeze the contract (§5) and create milestones, labels, and issues

**Done when:** CI is green, GlanceCore has ≥90% coverage, and the app launches.

### T1: Local MCP server
- [ ] `glance-mcp` with the tools, prompt, and resource from §8.1. Input validation, with clear error messages.
- [ ] Tests that run against a temporary `todo.md`, plus a manual check with the MCP Inspector
- [ ] `scripts/install-mcp.sh` and the README setup steps. Check ChatGPT desktop (§8.3).

**Done when:** saying *"add 'book friday dinner' to my life list"* in Claude Desktop changes `data/todo.md` correctly.

### T2: Ball & window behaviour
- [ ] Ball `NSPanel`: non-activating, floating, `canJoinAllSpaces` and `fullScreenAuxiliary`, Liquid Glass circle, count, drag with corner snap, saved position
- [ ] List `NSPanel` anchored to the ball's corner. A hover state machine: collapsed → expanded → faded → collapsed, with enter and leave delays and a hit-area buffer. It stays open while typing.
- [ ] Pulse when the count changes, tint when something is due. Respect Reduce Motion and Reduce Transparency.
- [ ] Menu-bar extra, launch at login (`SMAppService`), global shortcut

**Done when:** the ball stays visible over fullscreen apps and across Spaces, hovering doesn't flicker, and idle CPU is about 0%.

### T3: List panel UI
- [ ] Header (date and gear), status tabs, custom filter tabs (create, edit, reorder) with a Today preset
- [ ] Categories (collapse, colour dot, rename, reorder) and task rows (check, inline edit, context menu for status, due date, and delete)
- [ ] Per-task notes that expand on click, plus drag and drop to reorder or move tasks
- [ ] Add-task field with a category picker and quick due-date entry (e.g. typing `ddl 10/25` or `📅` sets the date)
- [ ] Suggested section with ✓/✕, the butterfly watermark (toggle), and the Settings window (fade opacity and delay, notifications, launch at login, shortcut, Connect Claude Desktop)
- [ ] Light and dark screenshots compared to `docs/reference/`

**Done when:** every interaction in R3–R6 works, and screenshots are attached to the PR.

### T4: Live sync & reminders
- [ ] Connect the FileStore watcher to `AppState`, so external edits show up within 1 second. Write tests for the conflict path, where the app and the MCP server write at the same time.
- [ ] Reminders: `UserNotifications` permission, schedule a notification for each due task, reschedule whenever the file changes, cancel when a task is completed or deleted. Clicking a notification opens the panel.

**Done when:** a task added through Claude Desktop with a due time appears live and notifies on time, and no edits are lost.

### T5: QA & release
- [ ] Manual end-to-end checklist (fresh user account, light and dark mode, fullscreen, multiple Spaces, external monitor)
- [ ] `scripts/build.sh` produces a `.app` or `.dmg`. Signing and notarization are optional for personal use; document whichever you choose.
- [ ] README with screenshots, install steps, MCP setup, and the data format. `CHANGELOG.md` from conventional commits.
- [ ] Tag `v0.1.0`.

---

## 10. Milestones

| Milestone | Threads | Exit criteria |
|---|---|---|
| **M0 Bootstrap** | T0 | CI green, GlanceCore tested, contract frozen |
| **M1 AI-connected** | T1 | Claude Desktop manages `data/todo.md` |
| **M2 Usable widget** | T2 + T3 | Ball and panel usable every day |
| **M3 Live & reminding** | T4 | Live sync and due-date notifications |
| **M4 v0.1.0** | T5 | Build, docs, tag |

---

## 11. Risks & mitigations

| Risk | Mitigation |
|---|---|
| A floating panel misbehaves over fullscreen apps or Spaces | Spike it first in T2, using `NSPanel` with `.nonactivatingPanel`, `.floating` or `.statusBar` level, and the right `collectionBehavior` |
| Liquid Glass API details differ from what's expected | Spike in T0 and check the current SwiftUI docs. Fall back to `NSVisualEffectView` |
| Hosted CI lacks Xcode 26 | Run package tests in CI and build the app locally before merging (ADR) |
| The app and the MCP server write at the same time | Hash-checked atomic writes with retry, covered by tests |
| The to-do list gets committed by accident | `data/` is gitignored from the first commit. CI fails if any file under `data/` is tracked. |
| An AI adds tasks the owner didn't want | `suggest_tasks` only writes to Suggested, and `add_task` is restricted to explicit requests |
| The hover feels twitchy | Use enter and leave delays and a hit-area buffer, and tune them with the owner |

---

## 12. Kickoff prompt for the build Claude

> You are building **Glance**, a native macOS 26 SwiftUI to-do widget, by following `glance-project-plan.md` (attached). Read all of it first. You must be running on my MacBook with Xcode 26.
> Start with Thread 0: create `~/workspace/notes-reminder`, add a `.gitignore` that excludes `data/` **before the first commit**, create the private GitHub repo `notes-reminder`, copy the plan in as `docs/PLAN.md`, write `CLAUDE.md`, set up the Swift package, XcodeGen, lint, and CI, and build `GlanceCore` test-first.
> Use Conventional Commits, one logical and verified change per commit, a branch and PR per task, and "rebase and merge". Merge your own PRs once CI is green. Push at the end of every session. Never make filler commits.
> After T0, choose a threads option from §9.1, tell me which one in one paragraph, record it as an ADR, and continue with T1 (MCP) next. Use plan mode at the start of each thread. Never mark a task done without running lint and tests, and for UI work, without screenshots in light and dark mode. Only ask me about things that change scope; otherwise choose a default and record an ADR.

---

## 13. Remaining open items (defaults in bold, so nothing blocks)
1. Global shortcut: **⌥Space**. Change it if it conflicts with another app.
2. Default categories in a new list: **work, life, content, study** (from the screenshots).
3. Reminder time for date-only tasks: **9:00**.
4. Keep the butterfly watermark: **yes, toggleable in Settings**.
