# Remora Config Storage Migration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Remora persistence off Keychain, `~/.remora`, `UserDefaults`, and `@AppStorage`, and store all durable SSH / AI / app settings under `~/.config/remora` as JSON files.

**Architecture:** Introduce a shared config-path + JSON persistence layer, keep existing public APIs stable where practical, and migrate each persistence surface onto file-backed JSON. SSH catalog data becomes plaintext JSON, credentials become plaintext JSON, and app settings move into a shared settings document consumed by SwiftUI instead of `UserDefaults`.

**Tech Stack:** Swift 6, SwiftUI, Foundation, Testing

---

## Chunk 1: Shared persistence foundation

### Task 1: Add config path and JSON file helpers

**Files:**
- Create: `Sources/RemoraCore/Config/RemoraConfigPaths.swift`
- Create: `Sources/RemoraCore/Config/RemoraJSONFileStore.swift`
- Modify: `Package.swift`
- Test: `Tests/RemoraCoreTests/ConfigPathTests.swift`

- [ ] Define a single helper that resolves `~/.config/remora` and named JSON files.
- [ ] Add JSON read/write helpers that create parent directories and apply file permissions where needed.
- [ ] Update package layout if new source folder registration is needed.
- [ ] Add tests that verify path resolution and JSON persistence basics.

## Chunk 2: SSH credentials and host catalog migration

### Task 2: Rewrite `CredentialStore` as file-backed plaintext JSON

**Files:**
- Modify: `Sources/RemoraCore/Security/CredentialStore.swift`
- Test: `Tests/RemoraCoreTests/CredentialStoreTests.swift`

- [ ] Replace Security / Keychain behavior with JSON-file persistence under `~/.config/remora/credentials.json`.
- [ ] Preserve the async `setSecret/secret/removeSecret` API and in-memory cache behavior.
- [ ] Remove all Keychain code paths and Security imports.
- [ ] Update tests to assert plaintext JSON persistence instead of Keychain behavior.

### Task 3: Rewrite host catalog persistence to plaintext JSON

**Files:**
- Modify: `Sources/RemoraApp/HostCatalogPersistence.swift`
- Modify: `Sources/RemoraApp/HostCatalog.swift`
- Test: `Tests/RemoraAppTests/HostCatalogPersistenceStoreTests.swift`
- Test: `Tests/RemoraAppTests/HostCatalogStoreTests.swift`

- [ ] Replace encrypted `connections.enc.json` + `catalog.key` storage with plaintext JSON in `~/.config/remora/connections.json`.
- [ ] Remove catalog-key indirection and all Keychain fallback logic.
- [ ] Keep `HostCatalogStore` behavior stable for create/edit/list/import/export flows.
- [ ] Update tests to validate plaintext JSON round-trips and remove legacy Keychain assertions.

### Task 4: Verify SSH consumers still work with file-backed credentials

**Files:**
- Modify: `Sources/RemoraCore/SSH/SystemSSHClient.swift`
- Modify: `Sources/RemoraCore/SFTP/SystemSFTPClient.swift`
- Modify: `Sources/RemoraApp/ContentView.swift`
- Modify: `Sources/RemoraApp/HostConnectionImporter.swift`
- Modify: `Sources/RemoraApp/HostConnectionExporter.swift`
- Modify: `Sources/RemoraApp/HostConnectionClipboardBuilder.swift`
- Test: `Tests/RemoraCoreTests/SystemSSHClientTests.swift`
- Test: `Tests/RemoraCoreTests/SystemSFTPClientTests.swift`
- Test: `Tests/RemoraAppTests/HostConnectionImporterTests.swift`
- Test: `Tests/RemoraAppTests/HostConnectionExporterTests.swift`
- Test: `Tests/RemoraAppTests/HostConnectionClipboardBuilderTests.swift`

- [ ] Keep password-reference based SSH flows working against the new plaintext credential file.
- [ ] Update create/edit/import/export/copy-password behavior and user messaging.
- [ ] Ensure importing passwords persists them into the new JSON store.
- [ ] Re-run the full SSH-related test surface.

## Chunk 3: App settings migration off `UserDefaults` / `@AppStorage`

### Task 5: Introduce file-backed app settings store

**Files:**
- Create: `Sources/RemoraApp/AppPreferences.swift`
- Modify: `Sources/RemoraApp/AppSettings.swift`
- Modify: `Sources/RemoraApp/AISettingsStore.swift`
- Test: `Tests/RemoraAppTests/AISettingsStoreTests.swift`
- Test: `Tests/RemoraAppTests/AppSettingsTests.swift`

- [ ] Define a codable settings document stored at `~/.config/remora/settings.json`.
- [ ] Move AI provider/base URL/model/API key and other durable app settings into the document.
- [ ] Preserve clamping/default logic and existing `AISettingsStore` API.
- [ ] Add tests covering defaults, save/load, and plaintext persistence.

### Task 6: Replace `@AppStorage` / `UserDefaults` readers with the shared settings store

**Files:**
- Modify: `Sources/RemoraApp/RemoraAppMain.swift`
- Modify: `Sources/RemoraApp/RemoraSettingsSheet.swift`
- Modify: `Sources/RemoraApp/ContentView.swift`
- Modify: `Sources/RemoraApp/TerminalPaneView.swift`
- Modify: `Sources/RemoraApp/TerminalAIAssistantView.swift`
- Modify: `Sources/RemoraApp/FileTransferViewModel.swift`
- Modify: `Sources/RemoraApp/L10n.swift`
- Modify: `Sources/RemoraApp/AppLanguage.swift`
- Modify: `Sources/RemoraApp/ServerStatusWindow.swift`
- Modify: `Sources/RemoraApp/AppKeyboardShortcuts.swift`
- Test: `Tests/RemoraAppTests/AppLanguageModeTests.swift`
- Test: `Tests/RemoraAppTests/AppKeyboardShortcutStoreTests.swift`
- Test: `Tests/RemoraAppTests/TerminalAIAssistantCoordinatorTests.swift`
- Test: `Tests/RemoraAppTests/RemoraUIAutomationTests.swift`

- [ ] Replace persistent settings reads/writes so they come from the file-backed settings store instead of `UserDefaults` / `@AppStorage`.
- [ ] Keep UI behavior stable in SSH list, AI drawer, settings, launch appearance/language, and download-directory handling.
- [ ] Move keyboard shortcut persistence into JSON as part of the same config-root abstraction.
- [ ] Update tests that previously depended on isolated `UserDefaults` suites.

## Chunk 4: Copy, cleanup, and verification

### Task 7: Update user-facing copy and remove old storage assumptions

**Files:**
- Modify: `Sources/RemoraApp/ContentView.swift`
- Modify: `Sources/RemoraApp/RemoraSettingsSheet.swift`
- Modify: `Sources/RemoraApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/RemoraApp/Resources/zh-Hans.lproj/Localizable.strings`

- [ ] Replace Keychain wording with accurate `~/.config/remora` wording.
- [ ] Keep all changed UI strings localized in English and Simplified Chinese.
- [ ] Ensure copy still warns clearly about plaintext export / clipboard behavior.

### Task 8: Verify the migration end-to-end

**Files:**
- Verify all files touched above

- [ ] Run `lsp_diagnostics` on all modified Swift files.
- [ ] Run focused tests for credential store, host catalog persistence, AI settings, app language, keyboard shortcuts, importer/exporter, and clipboard flows.
- [ ] Run `swift test` for the full suite.
- [ ] Run `swift build` to prove the package still compiles cleanly.
- [ ] Manually verify any changed UI-related behavior that can be exercised through existing tests.
