# 0001. Build Glance in native Swift and SwiftUI

**Status:** accepted, 2026-10-22

## Context
Glance needs Apple's Liquid Glass material, a floating panel over fullscreen apps, and close to 0% idle CPU. The owner locked native Swift and SwiftUI in `docs/PLAN.md` §2.

## Decision
- SwiftUI for views, with AppKit `NSPanel` where SwiftUI has no floating-panel API.
- Deployment target macOS 26.0. Liquid Glass comes from `.glassEffect(.regular, in: .circle)`. The T0 scaffold confirmed it compiles and renders.
- The owner's Mac has Xcode 27.0 (Swift 6.4, macOS 27 SDK), not Xcode 26. The newer SDK builds for a macOS 26 deployment target, so the plan's macOS 26 requirement holds.
- The app target uses Approachable Concurrency and main-actor default isolation. GlanceCore stays `nonisolated` because both the app and `glance-mcp` call it.
- Tests use Swift Testing.

## Consequences
APIs newer than macOS 26 need an `if #available` check. CI uses the hosted `macos-26` image. See ADR 0004 if that ever changes.
