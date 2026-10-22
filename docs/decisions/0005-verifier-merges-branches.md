# 0005. Builders work on branches; a verifier agent merges

**Status:** accepted, 2026-10-22. Replaces the PR workflow in `docs/PLAN.md` §6.3.

## Context
During T0, stacked PRs slowed the work down. Each PR waited on the one below it, and merging them out of order left reviewed work off `main`. The owner asked for a team setup: each agent on its own branch, and one agent that checks the work like a test and merges it.

## Decision
- **Builders.** Each builder agent gets one issue, one branch, and one git worktree. It commits verified work and stops. It never merges.
- **Verifier.** A separate agent takes each finished branch. It rebases the branch onto `main`, runs `scripts/check.sh`, reviews the diff against the plan and the issue with `/ponytail-review`, and checks light and dark screenshots for UI. On pass, it fast-forwards `main`, pushes, and closes the issue with what it verified. On fail, it reports findings and changes no code.
- **Lead.** The lead session gives out the issues, starts a verifier for each finished branch, and sends failed branches to a fresh builder with the findings.
- **No PRs.** CI still runs on every push to `main` as a backstop.

## Consequences
- `main` gets reviewed work as soon as it passes, in any order the dependencies allow.
- The independent review now happens before code reaches `main`. Before, it was only the author's own CI.
- There is no PR page to read. The record is the issue comment plus the commit history.
