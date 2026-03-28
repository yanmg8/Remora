# Sidebar Create Connection Button Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new icon button to the right side of the `SSH Threads` sidebar header that opens the existing create-SSH-connection flow while keeping the existing create-group button and preserving native macOS styling.

**Architecture:** Reuse the existing sidebar action wiring instead of introducing a new flow. Keep the change narrowly scoped to the sidebar header and shared icon-button styling, then add a focused regression test that proves the new header button invokes the existing host-creation path and remains visible alongside the group button.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Testing, existing `VisualStyle` tokens, `tr(...)` localization helpers

---

## Constraints

- Do not change the existing create-group button behavior.
- The new button must trigger the same host-creation flow as `beginCreateHostInPreferredGroup()` / the existing `New SSH Connection` action.
- Preserve existing native macOS sidebar spacing, hover treatment, and light/dark appearance behavior.
- Any new user-facing copy must use `tr(...)` and be added to both `Sources/RemoraApp/Resources/en.lproj/Localizable.strings` and `Sources/RemoraApp/Resources/zh-Hans.lproj/Localizable.strings`.
- Keep changes isolated to this worktree: `.worktree/sidebar-create-connection-button`.

## File map

- Modify: `Sources/RemoraApp/ContentViewLayout.swift`
  - Add the new `SSH Threads` header icon button next to the existing create-group button.
  - Wire the new button to the existing create-host action.
- Modify: `Sources/RemoraApp/ContentViewSidebarComponents.swift`
  - If needed, extend shared sidebar icon-button support for tooltip/accessibility consistency without changing existing button visuals.
- Modify: `Sources/RemoraApp/Resources/en.lproj/Localizable.strings`
  - Add English localization for any new tooltip/accessibility text.
- Modify: `Sources/RemoraApp/Resources/zh-Hans.lproj/Localizable.strings`
  - Add Simplified Chinese localization for the same text.
- Create: `Tests/RemoraAppTests/SidebarHeaderButtonsTests.swift`
  - Add a focused regression test for the header button arrangement and action wiring.
- Verify: `Tests/RemoraAppTests/SidebarMenuIconButtonTests.swift`
  - Re-run existing compact icon-button regression coverage.
- Verify: `Tests/RemoraAppTests/L10nTests.swift`
  - Re-run localization coverage after string updates.

## Chunk 1: Lock down expected behavior first

### Task 1: Add a failing regression test for the sidebar header controls

**Files:**
- Create: `Tests/RemoraAppTests/SidebarHeaderButtonsTests.swift`
- Read for reference: `Tests/RemoraAppTests/SidebarMenuIconButtonTests.swift`
- Read for reference: `Sources/RemoraApp/ContentViewLayout.swift`

- [ ] **Step 1: Write a focused test that renders the sidebar header and asserts both header icon buttons are present**
- [ ] **Step 2: Make the test verify the new connection button uses a distinct icon from the group button and remains compact in rendered AppKit hosting**
- [ ] **Step 3: Add an interaction-oriented assertion, if practical within current test helpers, that the new button routes into the existing create-host path rather than a new flow**
- [ ] **Step 4: Run `swift test --filter SidebarHeaderButtonsTests` and confirm the new test fails for the expected missing-button reason**

## Chunk 2: Implement the smallest UI change

### Task 2: Add the new sidebar header icon button

**Files:**
- Modify: `Sources/RemoraApp/ContentViewLayout.swift`
- Modify: `Sources/RemoraApp/ContentViewSidebarComponents.swift`

- [ ] **Step 1: Add a new `SidebarIconButton` beside the existing `folder.badge.plus` button in the `SSH Threads` header**
- [ ] **Step 2: Choose an SF Symbol that communicates "new connection" more clearly than the group button while matching existing native macOS iconography**
- [ ] **Step 3: Wire the action to `beginCreateHostInPreferredGroup()` so the button opens the existing create-connection sheet flow**
- [ ] **Step 4: If adding tooltip/help or accessibility label text, reuse the shared sidebar button styling and avoid any unrelated refactors**
- [ ] **Step 5: Run `swift test --filter SidebarHeaderButtonsTests` and confirm it passes**

## Chunk 3: Localize any new copy

### Task 3: Add localization entries for any new header-button copy

**Files:**
- Modify: `Sources/RemoraApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/RemoraApp/Resources/zh-Hans.lproj/Localizable.strings`
- Verify: `Tests/RemoraAppTests/L10nTests.swift`

- [ ] **Step 1: Add matching localization entries for the new button tooltip/help/accessibility text in both language files**
- [ ] **Step 2: Keep the string wording aligned with existing sidebar terminology (`SSH`, `Connection`, `Threads`)**
- [ ] **Step 3: Run `swift test --filter L10nTests` and confirm the localization suite stays green**

## Chunk 4: Regression and appearance verification

### Task 4: Re-run focused UI regressions and full package tests

**Files:**
- Modify: `Sources/RemoraApp/ContentViewLayout.swift`
- Modify: `Sources/RemoraApp/ContentViewSidebarComponents.swift`
- Modify: `Sources/RemoraApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/RemoraApp/Resources/zh-Hans.lproj/Localizable.strings`
- Create: `Tests/RemoraAppTests/SidebarHeaderButtonsTests.swift`

- [ ] **Step 1: Run `swift test --filter SidebarMenuIconButtonTests` to confirm compact icon button rendering still behaves correctly**
- [ ] **Step 2: Run `swift test --filter SidebarHeaderButtonsTests` one more time as a focused regression check**
- [ ] **Step 3: Run `swift test` for full verification**
- [ ] **Step 4: Run `swift run RemoraApp` or equivalent local UI verification and visually confirm the header in both light mode and dark mode**
- [ ] **Step 5: If environment constraints prevent visual verification, record exactly what was verified and what remains manual**
