# Terminal Caret Input Fix Design

## Goal

Fix the custom `TerminalView` shell-input experience so that:

- left and right arrow keys move the shell cursor reliably
- the caret blinks when the terminal is focused
- the caret geometry aligns with rendered text
- single-click cursor repositioning lands on the expected column without requiring a second click

This work targets the normal shell input line in `TerminalView`, not full-screen TUI programs.

## Constraints

- Keep PTY ownership of shell editing. Remora must continue sending terminal control input instead of maintaining a local editable text model.
- Preserve mouse-reporting passthrough for TUI applications.
- Reuse one caret geometry model for drawing, IME placement, and click hit testing so the terminal does not drift between code paths.

## Root Cause Hypothesis

- Keyboard routing already has unit coverage and appears logically correct, so the reported editing failures are likely caused by focus and caret/click geometry mismatches rather than missing arrow-key mapping.
- The caret is currently a static full-cell fill with no blink state, so it never blinks and visually feels detached from the rendered glyph baseline.
- Mouse hit testing and IME caret placement each derive geometry independently, which makes click-to-column behavior easy to skew.
- Single-click shell repositioning defers work until `mouseUp`, but the surrounding selection path still relies on a separate coordinate model, which can make the first click feel wrong.

## Recommended Approach

### 1. Centralize caret geometry

Add a shared caret-rect helper in `TerminalView` that derives:

- cell origin
- caret x/y position
- caret width/height

from renderer metrics and the active cursor position.

Use the same helper for:

- `drawCursor`
- `firstRect(forCharacterRange:)`
- test-only point generation helpers

### 2. Add focused caret blinking

Track a blink phase in `TerminalView` and toggle it on a timer only when:

- the view is first responder
- keyboard input is allowed
- the viewport is at the bottom
- the terminal is not in a mode that should hide the local caret

Reset the blink to visible whenever input arrives or the cursor position changes.

### 3. Tighten shell click handling

Keep click-to-move as relative PTY cursor movement, but compute the target column from the same shared geometry and keep the single-click path fully separated from selection setup.

Behavior:

- single click on the active shell line sends relative left/right movement
- drag from that same press transitions into normal selection
- double/triple click keep word/line selection
- mouse-reporting mode still routes events directly to the PTY

### 4. Test strategy

Follow TDD:

- add failing terminal tests for caret rect alignment and blink visibility state transitions
- add failing tests for single-click shell repositioning dispatch and click hit accuracy
- run targeted `TerminalInputTests` and renderer tests after each step

## Alternatives Considered

### Replace the shell line with a native text control

Rejected. It would conflict with the terminal renderer and PTY-driven shell model.

### Maintain a local shadow input buffer

Rejected. It would diverge from shell/readline/zsh state and create reconciliation bugs.

## Risks

- Wrapped shell lines can still be tricky if logical and visual columns diverge.
- A blink timer can cause unnecessary redraw churn if not scoped tightly.

## Mitigations

- Keep geometry helpers buffer-aware and cover wrapped-line cases with tests.
- Blink only while focused and invalidate only the caret region when practical.
