# ContentView Modularization Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce `Sources/RemoraApp/ContentView.swift` complexity by splitting it into focused files without changing any visible UI, interaction behavior, accessibility identifiers, localization behavior, or runtime functionality.

**Architecture:** Keep `ContentView` as the composition root that owns app-level state and orchestration. Extract only already-separable top-level helper types and leaf/subtree SwiftUI components into sibling files under `Sources/RemoraApp/`, and preserve the existing callback/data flow so the root view still drives the same state transitions. Prefer moving code over rewriting code.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Combine, Swift Testing, existing `VisualStyle` and `tr(...)` localization helpers

---

## Constraints

- No user-facing UI copy changes unless required by compilation; if any visible string must move, keep using `tr(...)` and update both localization files.
- No layout, styling, accessibility identifier, gesture, sheet, alert, or menu behavior changes.
- Keep light mode and dark mode rendering behavior intact.
- Keep work isolated to `.worktree/contentview-refactor`.
- Prefer pure file splits and minimal access-control widening over logic rewrites.

## File map

- Modify: `Sources/RemoraApp/ContentView.swift`
  - Leave the root `ContentView` composition, state ownership, and action methods in place.
  - Remove helper types and child views that are migrated out.
- Create: `Sources/RemoraApp/ContentViewSupport.swift`
  - Move top-level helper models and pure state utilities used by `ContentView`.
- Create: `Sources/RemoraApp/ContentViewSidebarComponents.swift`
  - Move sidebar buttons, host rows, and group section UI.
- Create: `Sources/RemoraApp/ContentViewSheets.swift`
  - Move sheets, drafts, editor modes, and sheet-local helpers.
- Create: `Sources/RemoraApp/ContentViewSessionComponents.swift`
  - Move session-tab-specific UI and compact metrics views.
- Modify: `scripts/generate_xcodeproj.rb` only if project generation needs explicit grouping changes beyond auto-discovery.
- Regenerate: `Remora.xcodeproj/project.pbxproj`
  - Refresh generated Xcode project contents after new source files are added.
- Verify: `Tests/RemoraAppTests/BottomPanelVisibilityStateTests.swift`
- Verify: `Tests/RemoraAppTests/SidebarMenuIconButtonTests.swift`
- Verify: `Tests/RemoraAppTests/RemoraUIAutomationTests.swift`

## Chunk 1: Lock down safe split boundaries

### Task 1: Inventory what can move without behavior change

**Files:**
- Modify: `Sources/RemoraApp/ContentView.swift`
- Create: `Sources/RemoraApp/ContentViewSupport.swift`

- [ ] **Step 1: Separate pure support types from root view orchestration**
- [ ] **Step 2: Keep types already covered by tests (`BottomPanelVisibilityState`, `SSHRefreshActionDecision`) source-compatible**
- [ ] **Step 3: Avoid moving methods that depend on `private` `@State` until component extraction is complete**

## Chunk 2: Extract leaf UI components

### Task 2: Move sidebar-specific reusable views

**Files:**
- Modify: `Sources/RemoraApp/ContentView.swift`
- Create: `Sources/RemoraApp/ContentViewSidebarComponents.swift`

- [ ] **Step 1: Move `SidebarIconButton`, `SidebarMenuIconButton`, and `SidebarActionRowButton` unchanged**
- [ ] **Step 2: Move `SidebarHostRow` and `SidebarGroupSectionView` unchanged**
- [ ] **Step 3: Keep all callback signatures, accessibility identifiers, and context menus identical**

### Task 3: Move sheets and their local models

**Files:**
- Modify: `Sources/RemoraApp/ContentView.swift`
- Create: `Sources/RemoraApp/ContentViewSheets.swift`

- [ ] **Step 1: Move import/export/editor/rename/quick-command/quick-path sheets**
- [ ] **Step 2: Move sheet-specific enums and drafts (`SidebarGroupEditorMode`, `SidebarHostEditorMode`, `SidebarHostAuthMethod`, `SidebarHostEditorDraft`, `HostConnectionTestState`, `HostConnectionTester`)**
- [ ] **Step 3: Keep button labels, bindings, widths, and validation behavior unchanged**

### Task 4: Move session-tab child views

**Files:**
- Modify: `Sources/RemoraApp/ContentView.swift`
- Create: `Sources/RemoraApp/ContentViewSessionComponents.swift`

- [ ] **Step 1: Move `SessionTabBarItem` and `SessionMetricCompactBars` unchanged**
- [ ] **Step 2: Keep metrics hover behavior, tooltip anchor preferences, and accessibility identifiers unchanged**

## Chunk 3: Reconcile project wiring

### Task 5: Refresh generated project structure

**Files:**
- Regenerate: `Remora.xcodeproj/project.pbxproj`

- [ ] **Step 1: Regenerate the Xcode project using the repo script after adding new Swift files**
- [ ] **Step 2: Confirm the new sources are included exactly once and resources/localizations remain intact**

## Chunk 4: Verification

### Task 6: Compile and regression-check the split

**Files:**
- Modify: `Sources/RemoraApp/ContentView.swift`
- Create: `Sources/RemoraApp/ContentViewSupport.swift`
- Create: `Sources/RemoraApp/ContentViewSidebarComponents.swift`
- Create: `Sources/RemoraApp/ContentViewSheets.swift`
- Create: `Sources/RemoraApp/ContentViewSessionComponents.swift`
- Regenerate: `Remora.xcodeproj/project.pbxproj`

- [ ] **Step 1: Run `swift test --filter BottomPanelVisibilityStateTests`**
- [ ] **Step 2: Run `swift test --filter SidebarMenuIconButtonTests`**
- [ ] **Step 3: Run `swift test --filter RemoraUIAutomationTests`**
- [ ] **Step 4: Run `swift test`**
- [ ] **Step 5: If UI automation cannot run in this environment, record that explicitly and fall back to the strongest available compile/test verification**
