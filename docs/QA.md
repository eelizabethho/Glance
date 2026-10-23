# Manual QA checklist

## Install
- [ ] Drag `Glance.app` to /Applications
- [ ] First launch with right-click, Open
- [ ] No Dock icon

## Ball
- [ ] Appears top right on first launch
- [ ] Shows the task count
- [ ] Drag moves it and it snaps to a corner
- [ ] Relaunch keeps the corner
- [ ] Pulses when the count changes
- [ ] Tints pink when something is due
- [ ] Stays above a fullscreen app
- [ ] Shows on every Space
- [ ] Behaves on an external monitor

## Panel
- [ ] Hover opens it
- [ ] Leaving fades it, then it collapses
- [ ] Stays open while typing
- [ ] Tabs work, including custom tabs and Today
- [ ] Categories: collapse, colour, rename, reorder
- [ ] Deleting a category shows the right task count
- [ ] Tasks: check and uncheck
- [ ] Tasks: inline edit
- [ ] Tasks: context menu
- [ ] Tasks: due date
- [ ] Tasks: notes with clickable links
- [ ] Tasks: drag and drop between categories
- [ ] Add field parses `ddl 10/25` as a due date
- [ ] Suggested section: ✓ accepts, ✕ dismisses
- [ ] Quit button saves the last edit and quits
- [ ] Transparency slider: 0 is clear glass, 1 is solid

## Appearance
- [ ] Light mode
- [ ] Dark mode
- [ ] Reduce Motion
- [ ] Reduce Transparency

## Menu bar
- [ ] Show/Hide
- [ ] Open List
- [ ] ⌥Space toggles the panel
- [ ] Settings…
- [ ] Launch at Login
- [ ] Quit

## Settings
- [ ] Sliders change the fade
- [ ] Notifications toggle works
- [ ] Connect Claude Desktop (back up the config first)

## MCP
- [ ] Run `scripts/install-mcp.sh`, restart Claude Desktop
- [ ] Say "add 'book friday dinner' to my life list": it appears within 1 s
- [ ] Ask for a suggestion: it appears under Suggested

## Reminders
- [ ] A task due in 2 minutes notifies on time
- [ ] Clicking the notification opens the panel

## Fresh user account
- [ ] Repeat the Install section
