# Changelog

All notable changes to this project will be documented in this file.

This project generally follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html), with pre-release style suffixes where needed during active iteration.

## [Unreleased]

### Changed

- License switched from Apache-2.0 to MIT.

## [v0.9.1-open-source-readiness] - 2026-03-04

### Added

- Open-source docs set:
  - `CONTRIBUTING.md`
  - `SECURITY.md`
  - `docs/OPEN_SOURCE_CHECKLIST.md`
- Apache-2.0 `LICENSE`.
- README screenshots for SSH workspace, terminal TUI, and file manager workflow.
- File manager operation toasts for user feedback (copy/cut/delete/paste/upload/download/move/rename/create/retry).
- FTP/SFTP drag-and-drop enhancements:
  - upload destination routing (directory target vs current directory fallback)
  - destination hint overlay
  - stronger directory drop target affordances (icon + subtle scale animation).

### Changed

- Reworked `README.md` for public open-source launch with a full feature matrix and clearer quick start/testing docs.
- Reorganized planning docs into `docs/` and removed legacy OpenSpec artifacts from repository root.

## [v0.9.0-altscreen-start]

- Baseline milestone tag for alternate-screen and TUI compatibility work.

## [v0.8.0-ssh-reconnect-fixes-start]

- Baseline milestone tag for SSH reconnect stability work.

## [v0.8.0-pre-major-changes]

- Baseline milestone tag before major terminal/file-manager feature wave.
