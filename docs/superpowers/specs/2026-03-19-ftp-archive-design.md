# FTP Archive Support Design

**Status:** Approved for implementation

**Goal**

Add compress and extract support to the FTP/file-manager panel without depending on `zip`, `unzip`, `tar`, or other archive tools being installed on the remote server.

## Key constraint

Remora is a desktop SSH/SFTP client, not a server-side control panel with an agent running on the target host. That means the archive work must not assume shell-level archive commands are available remotely.

## 1Panel comparison

1Panel can archive files even when target machines do not have `zip/unzip` installed because its own backend agent runs on the managed server and performs archive work with built-in backend libraries.

Direct source-backed evidence:

- `agent/utils/files/file_op.go` imports `archive/zip`, `compress/gzip`, `github.com/mholt/archiver/v4`, and `github.com/klauspost/compress/zip`
- `frontend/src/enums/files.ts` declares support for `zip`, `gz`, `bz2`, `tar.bz2`, `tar`, `tgz`, `tar.gz`, `xz`, `tar.xz`, `rar`, and `7z`

Remora cannot copy that server-side execution model directly, so it needs a client-side archive strategy.

## Recommended architecture

### Primary approach: local archive engine + SFTP round-trip

#### Compress flow

1. User selects one or more remote files/directories in the FTP panel.
2. Remora downloads the selected content into a local temporary staging directory.
3. Remora builds the archive locally on the macOS client.
4. Remora uploads the finished archive file back to the current remote directory.
5. Remora refreshes the remote listing and reports completion.

#### Extract flow

1. User selects one supported archive file in the FTP panel.
2. Remora downloads the archive into a local temporary staging directory.
3. Remora extracts the archive locally on the macOS client.
4. Remora uploads the extracted file tree back to the chosen remote directory.
5. Remora refreshes the remote listing and reports completion.

## Phase 1 scope

### Compression formats (create archives)

- `zip`
- `tar`
- `tar.gz`
- `tgz`

### Extraction formats

- `zip`
- `tar`
- `tar.gz`
- `tgz`
- `gz`

## Deferred / later-expansion formats

- `bz2`
- `xz`
- `tar.bz2`
- `tar.xz`
- `rar`
- `7z`

These remain desirable, but should only ship once a local archive implementation is confirmed to be stable and supportable in Swift/macOS.

## UI entry points

### FTP panel context menus

Add archive-related actions to `FileManagerPanelView.swift`:

- `Compress…` for file/folder selections
- `Extract Here` for supported archive files
- `Extract To…` if a destination-picker flow is warranted during implementation

### Dialogs / sheets

Recommended dedicated sheet(s):

- `RemoteCompressSheet`
  - format selection
  - archive name
  - selected item summary
- `RemoteExtractSheet`
  - extraction destination
  - overwrite/conflict handling guidance
  - archive summary

## Backend orchestration placement

### `FileTransferViewModel.swift`

This should own the orchestration because it already manages:

- downloads/uploads
- remote selection-driven file actions
- refresh behavior
- progress / transfer queue feedback

Archive work should be introduced as app-side orchestration methods rather than new SFTP protocol methods.

Recommended responsibilities:

- create local staging directories
- recursively materialize selected remote items into staging
- run local archive build/extraction
- upload archive or extracted tree back to remote
- report progress and cleanup temporary files

## Error handling expectations

- Unsupported format → clear localized error
- Archive parsing failure → localized extraction error
- Name collision on upload → follow existing conflict strategy where practical
- Partial upload/download failure → fail the operation clearly and clean staging files
- Empty selection / invalid selection → action disabled or guarded before execution

## Testing expectations

The implementation must be robust enough for aggressive user testing, including edge cases.

Minimum coverage areas:

- single-file compression
- multi-file compression
- directory compression
- zip extraction
- tar/tar.gz/tgz/gz extraction
- nested directories
- name collisions
- cleanup after failure
- unsupported archive selection
- remote refresh after success

## Acceptance criteria

- FTP panel can compress remote selections without depending on remote archive binaries
- FTP panel can extract supported archive files without depending on remote archive binaries
- Phase 1 formats work end-to-end through local archive processing plus SFTP round-trips
- UI strings are localized with `tr(...)`
- UI remains correct in both light and dark appearances
