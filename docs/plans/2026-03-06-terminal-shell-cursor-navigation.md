# Terminal Shell Cursor Navigation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add shell-focused cursor navigation in the terminal via left/right arrows, single-click cursor repositioning, and `command+left/right` shortcuts without affecting TUI mouse behavior.

**Architecture:** Keep shell editing owned by the PTY peer. Keyboard shortcuts and mouse clicks are translated into relative cursor movement sequences and sent through the existing `onInput` path. `TerminalView` decides when click-to-move is safe; `TerminalInputMapper` remains the source of keyboard sequence mapping.

**Tech Stack:** Swift, AppKit, Swift Testing, existing `TerminalView` / `TerminalInputMapper` / `ScreenBuffer` infrastructure.

---

### Task 1: Document the feature boundary

**Files:**
- Create: `docs/plans/2026-03-06-terminal-shell-cursor-navigation-design.md`

**Step 1: Write the design doc**

Cover:
- supported interactions
- non-goals for TUI apps
- keyboard mapping choices
- click-to-move relative navigation strategy

**Step 2: Commit**

```bash
git add docs/plans/2026-03-06-terminal-shell-cursor-navigation-design.md
git commit -m "docs: add terminal shell cursor navigation design"
```

### Task 2: Add failing keyboard mapping tests

**Files:**
- Modify: `Tests/RemoraTerminalTests/TerminalInputTests.swift`
- Modify: `Sources/RemoraTerminal/Input/TerminalInputMapper.swift`

**Step 1: Write the failing tests**

Add tests asserting:
- `#selector(NSResponder.moveToBeginningOfLine(_:))` maps to `Ctrl-A`
- `#selector(NSResponder.moveToEndOfLine(_:))` maps to `Ctrl-E`
- command-modified left/right key events map to the same shell-friendly sequences

**Step 2: Run the targeted tests to verify failure**

Run: `swift test --filter 'TerminalInputTests'`

Expected: new tests fail because command-modified left/right keys still use xterm modifier sequences.

**Step 3: Write minimal implementation**

Update `TerminalInputMapper.mapNavigation(event:)` so:
- `command+left` returns `Data([0x01])`
- `command+right` returns `Data([0x05])`
- ordinary left/right behavior remains unchanged

**Step 4: Run the targeted tests to verify pass**

Run: `swift test --filter 'TerminalInputTests'`

Expected: new keyboard tests pass.

**Step 5: Commit**

```bash
git add Tests/RemoraTerminalTests/TerminalInputTests.swift Sources/RemoraTerminal/Input/TerminalInputMapper.swift
git commit -m "feat: add shell line navigation shortcuts"
```

### Task 3: Add failing click-to-move tests

**Files:**
- Modify: `Tests/RemoraTerminalTests/TerminalInputTests.swift`
- Modify: `Sources/RemoraTerminal/View/TerminalView.swift`

**Step 1: Write the failing tests**

Add tests covering:
- single click left of the cursor sends repeated left-arrow input
- single click right of the cursor sends repeated right-arrow input
- mouse-reporting mode prevents local click-to-move behavior

Use `TerminalView.onInput` capture and feed screen data that leaves the cursor on a known cell before simulating a click.

**Step 2: Run the targeted tests to verify failure**

Run: `swift test --filter 'TerminalInputTests'`

Expected: new click tests fail because `mouseDown` currently only starts selection.

**Step 3: Write minimal implementation**

In `TerminalView`:
- detect when a single click should be interpreted as shell cursor repositioning
- compute delta from current cursor column to clicked column
- emit repeated left/right sequences via `onInput`
- skip this path when PTY mouse reporting is enabled or when modifier-based hyperlink behavior is active
- preserve double/triple click and drag selection behavior

**Step 4: Run the targeted tests to verify pass**

Run: `swift test --filter 'TerminalInputTests'`

Expected: click tests pass.

**Step 5: Commit**

```bash
git add Tests/RemoraTerminalTests/TerminalInputTests.swift Sources/RemoraTerminal/View/TerminalView.swift
git commit -m "feat: support shell cursor reposition clicks"
```

### Task 4: Run focused regression coverage

**Files:**
- Test only

**Step 1: Run terminal-focused regression commands**

Run:

```bash
swift test --filter '(TerminalInputTests|TerminalRuntimeTests|TerminalDirectorySyncBridgeTests|RemoraUIAutomationTests)'
```

Expected:
- terminal input tests pass
- runtime/input integration tests pass
- UI automation tests remain gated/no-op unless explicitly enabled

**Step 2: If failures appear, fix only scoped regressions**

Keep fixes limited to terminal input and event routing.

**Step 3: Commit any final scoped regression fix if needed**

```bash
git add <scoped files>
git commit -m "fix: polish terminal shell cursor navigation"
```

### Task 5: Final verification

**Files:**
- Test only

**Step 1: Run final verification**

Run:

```bash
swift test --filter '(TerminalInputTests|TerminalRuntimeTests|TerminalDirectorySyncBridgeTests)'
```

Expected: all selected suites pass.

**Step 2: Report any unrelated pre-existing failures separately**

Do not conflate unrelated repository failures with this feature.
