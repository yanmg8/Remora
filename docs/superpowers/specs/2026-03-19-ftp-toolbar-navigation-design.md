# FTP Toolbar Navigation and Button Unification Design

**Status:** Approved for implementation

**Goal**

Add a dedicated parent-directory navigation button to the FTP/file manager toolbar, clearly distinct from history back/forward controls, while visually unifying the toolbar’s icon-button row so the quick-paths entry matches the existing button chrome.

## Background

The current FTP toolbar in `Sources/RemoraApp/FileManagerPanelView.swift` already has separate controls for:

- history back
- history forward
- go to root
- refresh
- direct path entry + go

However, it does **not** expose a direct “go to parent directory” action. That forces users to either edit the path field manually or depend on history semantics, which is the wrong mental model for simple directory ascent.

The current quick-paths entry is also implemented as a standalone `Menu` label using a borderless button style, while the other toolbar icon actions use the shared `toolbarIconButton(...)` helper. This makes the row look visually inconsistent.

## Desired Behavior

### Navigation semantics

- **Back** continues to mean navigation through remote browsing history only.
- **Forward** continues to mean navigation through remote browsing history only.
- **Up** is a new action that navigates to the current directory’s parent path.
- **Root** continues to mean jump directly to `/`.

These actions must stay conceptually distinct:

- `Back`: “where I was before”
- `Up`: “the parent of where I am now”

### Parent-directory rules

- If the current path is `/`, the new **Up** button is disabled.
- If the current path is a nested directory such as `/var/log/nginx`, **Up** navigates to `/var/log`.
- If the current path is `/Users/demo/`, the normalized parent target should still be `/Users`.
- Triggering **Up** should clear remote selection state the same way root/path-jump navigation does.

## Toolbar layout

Recommended order:

1. Back
2. Forward
3. Up
4. Root
5. Refresh
6. Quick Paths
7. Path field
8. Go

This keeps navigation actions grouped together before the path and sync controls.

## UI design

### Button unification

All icon-style controls in the left side of the toolbar should share the same visual system:

- same button size
- same bordered chrome
- same control size
- same icon sizing/alignment
- same disabled treatment
- same hover/press affordance inherited from the current bordered button style

The new **Up** button should be implemented using the same helper path as the other icon buttons.

The **Quick Paths** menu trigger should stop using its custom borderless appearance and instead reuse the same icon-button chrome while preserving menu behavior.

### Iconography

The exact SF Symbol can be finalized during implementation, but the semantic goal is:

- **Back/Forward** visually communicate history traversal
- **Up** visually communicates parent-directory ascent
- **Root** visually communicates jump-to-root/home-level destination

Tooltip text must remove ambiguity, especially for the new button:

- `Back`
- `Forward`
- `Go to Parent Directory`
- `Go to Root`
- `Refresh`
- `Open quick paths`

All visible/help text must continue to use `tr(...)`.

## Implementation approach

Primary implementation file:

- `Sources/RemoraApp/FileManagerPanelView.swift`

Expected implementation steps:

1. Introduce a small helper to compute the parent directory target from `viewModel.remoteDirectoryPath`.
2. Add a new `toolbarIconButton(...)` call for the **Up** action in `remoteToolbar`.
3. Refactor the quick-paths menu trigger so its label uses the same button chrome as the rest of the icon row.
4. Keep the existing history and root actions unchanged except for final visual alignment.

This should remain a focused toolbar/navigation refinement, not a full file-manager layout rewrite.

## Testing strategy

### Behavior coverage

Add or update tests to verify:

- **Up** is disabled at `/`
- **Up** navigates from a nested path to its parent
- **Back** remains history-based and does not get repurposed as parent navigation
- quick-paths access remains functional after the style unification

### Regression expectations

Existing FTP toolbar tests should continue to pass, especially those covering:

- back/forward visibility and behavior
- remote directory navigation
- quick-path interactions
- remote path field submission

## Risks and guardrails

- Do not overload the existing back button with parent-directory semantics.
- Do not turn this into a broader redesign of the entire toolbar row.
- Do not introduce non-localized tooltip or menu text.
- Do not break current accessibility identifiers unless tests are updated intentionally.

## Acceptance criteria

The change is complete when all of the following are true:

- FTP toolbar shows a distinct **Up** button
- **Up** behaves as parent-directory navigation, not history navigation
- quick-paths trigger looks visually consistent with the other icon buttons
- existing toolbar controls still work as before
- all new visible/help text uses `tr(...)`
