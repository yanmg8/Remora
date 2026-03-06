# Terminal Shell Cursor Navigation Design

## Goal

Improve command-line editing in the terminal for normal local and remote shell input by supporting:

- left/right arrow cursor movement
- single-click cursor repositioning
- `command+left` to line start
- `command+right` to line end

This work explicitly does not target `vim`, `less`, `nano`, `tmux`, or other full-screen TUI applications.

## Constraints

- Do not introduce a local shadow input buffer that competes with the shell's own line editor.
- Preserve existing TUI mouse reporting behavior. If the remote program has enabled mouse reporting, Remora must not reinterpret clicks as shell cursor movement.
- Keep behavior compatible with both local shell sessions and remote SSH shell sessions.

## Recommended Approach

### Keyboard behavior

Use the existing PTY input path and continue sending terminal control sequences instead of attempting local text editing:

- left/right arrows send the standard cursor movement sequence already understood by readline/zle
- `command+left` sends `Ctrl-A`
- `command+right` sends `Ctrl-E`

This maps cleanly onto shell behavior without requiring prompt parsing or input mirroring.

### Mouse click repositioning

Implement single-click cursor repositioning as relative movement, not absolute editing:

1. Determine the clicked terminal cell.
2. Determine the current visible cursor position from `ScreenBuffer`.
3. If mouse reporting is active, do nothing special and continue routing the click to the PTY.
4. Otherwise, compute the horizontal delta within the active visible shell input row/span.
5. Send repeated left or right cursor movement sequences to the PTY.

This matches the scope of “ordinary shell input line” and avoids inventing a second command-line model inside Remora.

## Alternatives Considered

### Alternative 1: Maintain a local editable input buffer

Rejected. This would require Remora to infer prompt boundaries, mirror shell state, and reconcile local edits with readline/zle behavior. It is fragile, difficult to generalize across shells, and likely to regress remote sessions.

### Alternative 2: Use absolute cursor addressing

Rejected. Shells do not expose a stable terminal-independent protocol for “move insertion point to absolute command-line column.” Relative movement via existing control sequences is simpler and more portable.

## Interaction Model

- Single click in ordinary shell input:
  - moves the cursor to the clicked column by sending relative left/right motion
- Double/triple click:
  - keep existing selection behavior
- Drag:
  - keep existing selection behavior
- Mouse reporting enabled:
  - keep existing PTY routing for TUI programs

## Implementation Areas

- `Sources/RemoraTerminal/Input/TerminalInputMapper.swift`
  - ensure `command+left/right` map to shell-friendly line navigation
- `Sources/RemoraTerminal/View/TerminalView.swift`
  - add shell cursor repositioning helper
  - gate the behavior behind non-mouse-reporting mode
  - preserve existing selection and hyperlink behavior
- `Tests/RemoraTerminalTests/TerminalInputTests.swift`
  - add input mapping and click-reposition tests

## Testing Strategy

- Unit-test command selector mapping for `command+left/right`
- Unit-test relative cursor movement generation for single-click repositioning
- Unit-test no-op behavior when mouse reporting is enabled
- Run targeted terminal input tests first
- Run a broader targeted regression pass for terminal runtime and terminal input behavior after implementation

## Risks

- If click positioning is allowed outside the current editable shell row, the cursor may move unexpectedly in scrollback or output regions.
- Wrapped command lines can make visual-to-logical column calculations tricky.

## Mitigations

- Restrict repositioning to the visible active cursor row/continuation span only.
- Use TDD around wrapped-line cases and mouse-reporting mode.
