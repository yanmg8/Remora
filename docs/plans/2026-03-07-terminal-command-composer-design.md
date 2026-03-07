# Terminal Command Composer Design

## Goal

Introduce a Warp-style command composer for normal shell usage:

- users edit commands in a dedicated multiline input area
- the terminal viewport remains the canonical transcript and still shows shell echo/output
- the composer can be placed at the top or bottom
- the composer automatically hides in TUI mode and hands input back to the terminal

## Context

The current terminal implementation uses [TerminalView](/Users/wuu/Projects/indie-hacker/lighting-tech.io/Remora/Sources/RemoraTerminal/View/TerminalView.swift) as both the renderer and the text input host. That is fragile in a SwiftUI/AppKit responder chain, especially for:

- arrow-key editing
- command-left/right movement
- IME/composition interactions
- click-to-reposition followed by delete/backspace

For normal shell usage, we do not need terminal-in-place editing. We need predictable command editing. A dedicated SwiftUI editor gives that control directly.

## Product Decision

When the session is in normal shell mode:

- the composer is the only editing surface for command entry
- the terminal viewport remains visible and continues to show shell echo/output
- command echo is not suppressed
- the app may later visually differentiate command lines from command output

When the session enters TUI mode:

- the composer hides automatically
- keyboard input is routed back to the terminal viewport
- any unsubmitted draft is preserved and restored when the session returns to normal shell mode

## Recommended Architecture

### 1. Split display from command editing

Keep [TerminalView](/Users/wuu/Projects/indie-hacker/lighting-tech.io/Remora/Sources/RemoraTerminal/View/TerminalView.swift) as the renderer and TUI interaction surface.

Add a new SwiftUI command composer for normal shell editing. This should be a native multiline text component wrapper, not a custom editor.

Reason:

- system text editing behavior is already correct for selection, IME, undo/redo, cursor motion, and accessibility
- we stop fighting AppKit key event routing inside the terminal renderer
- the terminal becomes responsible for terminal semantics only

### 2. Drive shell input through `TerminalRuntime`

Use existing helpers in [TerminalRuntime](/Users/wuu/Projects/indie-hacker/lighting-tech.io/Remora/Sources/RemoraApp/TerminalRuntime.swift):

- `sendText`
- `sendCtrlA`
- `sendCtrlK`
- `sendLeftArrow`
- `sendRightArrow`
- `replaceCurrentInputLine(with:cursorAt:)`

The composer owns a draft buffer and caret position. On edit changes, runtime synchronizes the shell prompt line by replacing the current input line and restoring the caret.

This is intentionally closer to Warp than xterm.js:

- xterm.js keeps editing inside the terminal surface
- this design makes the app own the normal-shell draft explicitly

### 3. Detect TUI mode from terminal state, not from guesswork

Primary signal:

- alternate buffer active

Secondary signals:

- mouse reporting enabled
- application cursor keys enabled

These are already surfaced inside the terminal stack:

- [ANSIParser.swift](/Users/wuu/Projects/indie-hacker/lighting-tech.io/Remora/Sources/RemoraTerminal/ANSI/ANSIParser.swift)
- [ScreenBuffer.swift](/Users/wuu/Projects/indie-hacker/lighting-tech.io/Remora/Sources/RemoraTerminal/Model/ScreenBuffer.swift)
- [TerminalView.swift](/Users/wuu/Projects/indie-hacker/lighting-tech.io/Remora/Sources/RemoraTerminal/View/TerminalView.swift)

The app should expose a simple published state from runtime such as:

- `isCommandComposerVisible`
- `isInteractiveTerminalMode`

The terminal layer provides raw terminal signals; runtime converts them into UI-facing state.

## UI Design

### Layout

[TerminalPaneView](/Users/wuu/Projects/indie-hacker/lighting-tech.io/Remora/Sources/RemoraApp/TerminalPaneView.swift) becomes:

- header
- composer at top or bottom depending on setting
- terminal viewport

The terminal viewport remains full-width and full-height within remaining space.

### Composer behavior

The composer should:

- support multiline editing
- submit with `Enter`
- insert newline with `Shift+Enter`
- preserve standard text-editing shortcuts
- become first responder when visible and the pane is active
- visually feel separate from transcript

Suggested first-pass visual treatment:

- subtle bordered card
- monospaced font
- command accent tint
- visible run affordance
- compact mode when empty

### Placement

Add a setting for:

- top
- bottom

Default should be bottom.

The layout switch should be immediate and per-app, not per-pane.

## Data Model

### Runtime-owned state

Add UI-facing state in [TerminalRuntime](/Users/wuu/Projects/indie-hacker/lighting-tech.io/Remora/Sources/RemoraApp/TerminalRuntime.swift):

- current draft text
- draft selection/caret metadata
- whether composer is available
- whether terminal-only mode is active

Each pane/runtime instance owns its own draft so tabs do not leak input state.

### Settings-owned state

Add app setting for composer placement in:

- [AppSettings.swift](/Users/wuu/Projects/indie-hacker/lighting-tech.io/Remora/Sources/RemoraApp/AppSettings.swift)
- [RemoraSettingsSheet.swift](/Users/wuu/Projects/indie-hacker/lighting-tech.io/Remora/Sources/RemoraApp/RemoraSettingsSheet.swift)

## Input Synchronization Strategy

### Normal shell mode

On any composer edit:

1. update draft state locally
2. compute caret index
3. call `replaceCurrentInputLine(with:cursorAt:)`

On submit:

1. ensure runtime line matches the current draft
2. send newline
3. clear draft

This is intentionally brute-force and predictable. We are not trying to emulate incremental readline internals.

### TUI mode

When composer is hidden:

- the composer stops syncing
- the terminal viewport becomes the active input target
- no attempt is made to keep a synthetic draft in sync with TUI state

### Returning from TUI mode

When the terminal returns to normal shell mode:

- restore the previous draft in the composer
- push the draft back into the shell line only when the user resumes editing

That avoids surprising mutation of whatever the shell emitted during mode transitions.

## Risks and Mitigations

### Risk: shell line replacement can be noisy

Replacing the full line on every edit can feel heavier than character-at-a-time input on slow SSH sessions.

Mitigation:

- keep the first version simple
- debounce only if needed after measurement
- do not introduce diff-based editing in v1

### Risk: false-positive TUI detection

Some programs enable terminal modes transiently.

Mitigation:

- use alternate buffer as the main gate
- treat the others as supporting signals
- keep detection logic centralized and testable

### Risk: multiline shell behavior differs by shell

Different shells handle literal newlines differently.

Mitigation:

- treat multiline as literal command text insertion plus submit
- verify against local shell and real SSH shell
- document any shell-specific edge cases found during testing

## Testing Strategy

### Unit tests

- runtime draft synchronization
- submit behavior
- composer visibility state machine
- placement setting persistence
- draft preservation across TUI enter/exit

### UI/integration tests

- composer visible in normal shell
- composer hidden in alternate-buffer TUI
- top/bottom placement switch
- multiline edit and submit
- pane-local draft isolation

### Acceptance checks

- `swift run RemoraApp`
- local shell
- real SSH shell
- `vim` / `less` / `top` or equivalent TUI transitions

## Non-Goals

- hiding shell echo from transcript
- building a fully custom text editor
- supporting terminal-in-place editing and composer editing at the same time
- rewriting transcript rendering in this phase

## Recommendation

Proceed with the Warp-style composer architecture.

It is not the same as xterm.js input architecture, but that is now intentional. xterm.js solves terminal-surface editing; this feature should instead optimize for predictable normal-shell command entry and clean TUI escape hatches.
