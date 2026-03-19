# FTP Toolbar Navigation and UI Unification Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dedicated parent-directory button to the FTP toolbar and unify the icon-button visuals so the quick-paths trigger matches the rest of the toolbar controls.

**Architecture:** Keep the change focused inside `FileManagerPanelView.swift`, because the toolbar layout, actions, and icon-button helper already live there. Add a small parent-path helper with targeted tests, then refactor the quick-paths menu label to reuse the same button chrome as the existing toolbar icon buttons without changing the rest of the file manager architecture.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, RemoraApp localization helpers (`tr(...)`)

---

## Chunk 1: Parent-directory behavior and state tests

### Task 1: Add failing tests for parent-directory navigation semantics

**Files:**
- Modify: `Tests/RemoraAppTests/FileTransferViewModelTests.swift`
- Modify: `Sources/RemoraApp/FileManagerPanelView.swift`
- Test: `Tests/RemoraAppTests/FileTransferViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Add small tests for a pure helper that computes the parent path target:

```swift
@Test
func parentDirectoryPathReturnsNilForRoot() {
    #expect(FileManagerPanelView.parentDirectoryPath(for: "/") == nil)
}

@Test
func parentDirectoryPathStripsTrailingSlashAndReturnsParent() {
    #expect(FileManagerPanelView.parentDirectoryPath(for: "/var/log/nginx/") == "/var/log")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FileTransferViewModelTests`
Expected: FAIL because the helper does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Add a small pure helper in `FileManagerPanelView.swift` that normalizes the current path and returns either the parent path or `nil` when already at `/`.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FileTransferViewModelTests`
Expected: PASS.

## Chunk 2: Toolbar actions and UI unification

### Task 2: Add the Up button and unify quick-path button styling

**Files:**
- Modify: `Sources/RemoraApp/FileManagerPanelView.swift`
- Modify: `Tests/RemoraAppTests/RemoraUIAutomationTests.swift`
- Test: `Tests/RemoraAppTests/RemoraUIAutomationTests.swift`

- [ ] **Step 1: Write/extend the failing UI regression test**

Add or extend a toolbar-focused UI test that verifies:

- a dedicated parent-directory button exists (new accessibility identifier)
- the quick-paths trigger remains available after the styling refactor
- the existing back button identifier still exists separately from the new parent-directory button

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter RemoraUIAutomationTests`
Expected: FAIL because the new parent-directory control does not exist yet.

- [ ] **Step 3: Write minimal implementation**

In `FileManagerPanelView.swift`:

- insert the new **Up** button in `remoteToolbar` between forward and root
- give it a unique accessibility identifier such as `file-manager-up`
- disable it when the current path has no parent above `/`
- add a `navigateToParentDirectory()` action that uses the pure helper and clears selection state like root/path-jump navigation
- refactor the quick-paths menu label to reuse the same button chrome as `toolbarIconButton(...)`
- keep all tooltip text routed through `tr(...)`

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter RemoraUIAutomationTests`
Expected: PASS.

## Chunk 3: Final verification and cleanup

### Task 3: Verify the toolbar change end to end

**Files:**
- Modify: `Sources/RemoraApp/FileManagerPanelView.swift`
- Modify: `Tests/RemoraAppTests/FileTransferViewModelTests.swift`
- Modify: `Tests/RemoraAppTests/RemoraUIAutomationTests.swift`

- [ ] **Step 1: Run language diagnostics on modified files**

Commands:
- `lsp_diagnostics` for each modified Swift file
Expected: zero errors.

- [ ] **Step 2: Run focused tests**

Run: `swift test --filter FileTransferViewModelTests`
Run: `swift test --filter RemoraUIAutomationTests`
Expected: PASS.

- [ ] **Step 3: Run the full verification suite**

Run: `swift build`
Run: `swift test`
Expected: build passes; full test suite has no new failures, and if the known UTF-8 local shell test still fails, record it as unchanged baseline behavior.

- [ ] **Step 4: Re-check requirement coverage**

Confirm all of the following:
- Back remains history navigation
- Up is a distinct parent-directory action
- Up is disabled at `/`
- quick-paths trigger remains functional
- toolbar icon buttons are visually unified
- all new visible/help text uses `tr(...)`
