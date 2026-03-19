# FTP Archive Support Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add phase-1 FTP compress/extract support using local archive processing plus SFTP round-trips, without depending on archive binaries on the remote host.

**Architecture:** Keep archive orchestration in `FileTransferViewModel.swift`, where download/upload/refresh flows already live. Add dedicated archive helpers/sheets in `Sources/RemoraApp`, wire entry points into `FileManagerPanelView.swift`, and keep protocol changes minimal by reusing existing SFTP download/upload/list primitives.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, RemoraApp / RemoraCore SFTP models, local macOS archive libraries or framework integrations

---

## Chunk 1: Archive engine and local staging helpers

### Task 1: Define local archive capabilities and tests first

**Files:**
- Create: `Sources/RemoraApp/ArchiveSupport.swift` (or equivalent focused helper file)
- Create: `Tests/RemoraAppTests/ArchiveSupportTests.swift`

- [ ] **Step 1: Write failing tests** for supported format detection, archive-name generation, and local extraction/compression helpers.
- [ ] **Step 2: Run the focused tests to verify failure**.
- [ ] **Step 3: Implement the minimal local archive helper layer**.
- [ ] **Step 4: Run the focused tests to verify pass**.

## Chunk 2: FileTransferViewModel orchestration

### Task 2: Add end-to-end archive orchestration with TDD

**Files:**
- Modify: `Sources/RemoraApp/FileTransferViewModel.swift`
- Modify/Create: tests in `Tests/RemoraAppTests/FileTransferViewModelTests.swift`

- [ ] **Step 1: Write failing tests** for compress/extract orchestration, staging behavior, upload paths, and refresh behavior.
- [ ] **Step 2: Run focused tests to verify failure**.
- [ ] **Step 3: Implement minimal orchestration** for phase-1 archive formats.
- [ ] **Step 4: Run focused tests to verify pass**.

## Chunk 3: FTP UI entry points

### Task 3: Add Compress/Extract actions and sheets

**Files:**
- Modify: `Sources/RemoraApp/FileManagerPanelView.swift`
- Create: `Sources/RemoraApp/RemoteCompressSheet.swift`
- Create: `Sources/RemoraApp/RemoteExtractSheet.swift`
- Modify relevant UI tests under `Tests/RemoraAppTests/RemoraUIAutomationTests.swift` if feasible

- [ ] **Step 1: Write failing regression coverage** for action visibility and supported archive selection behavior.
- [ ] **Step 2: Run focused tests to verify failure**.
- [ ] **Step 3: Implement the UI entry points and sheet flows**.
- [ ] **Step 4: Run focused tests to verify pass**.

## Chunk 4: Hardening and verification

### Task 4: Exercise edge cases and full verification

**Files:**
- Verify all modified files from chunks 1-3

- [ ] **Step 1: Run `lsp_diagnostics` on all modified Swift files**.
- [ ] **Step 2: Run focused archive tests**.
- [ ] **Step 3: Run `swift build`**.
- [ ] **Step 4: Run `swift test` and record unchanged baseline failures only**.
- [ ] **Step 5: Re-check localization and light/dark compatibility for new UI surfaces**.
