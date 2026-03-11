# Open Source Audit Notes

Last updated: 2026-03-11

This document records the repository-level checks completed before making the project
public. It is not a replacement for manual product validation on real hosts.

## Security And Privacy

### Git history secret scan

- Scanned current tree and git history for common token/private-key patterns.
- No AWS key, GitHub token, Slack token, Google API key, Stripe live key, or PEM/OpenSSH
  private key block patterns were found in tracked history.

### Diagnostics and log redaction

- `SystemSFTPClient` redacts environment keys containing `PASS`, `TOKEN`, or `SECRET`
  before writing diagnostics.
- Diagnostics files are rotated and expired automatically after the retention window.
- Targeted tests cover retention cleanup and sensitive environment redaction.

### Host key trust and credential storage

- SSH and SFTP launch arguments explicitly use `StrictHostKeyChecking=ask`.
- `HostKeyStoreTests` covers first-seen, trusted, and changed-key states.
- `TerminalRuntimeTests` covers the user-facing host key confirmation message.
- `CredentialStoreTests` covers Keychain-backed read/write/remove behavior, persistence
  across instances, memory cache behavior, and the absence of a new plaintext
  `credentials.json` file after writes.

## Licensing And Legal

### Bundled assets

- Repository-tracked bundled brand assets are limited to `logo.png`,
  `Resources/AppIcon.icns`, and `Resources/AppIcon.iconset/*`.
- The app uses Apple platform fonts and symbols at runtime rather than shipping third-party
  font files or icon packs in the repository.
- `NOTICE` documents the current redistribution boundary.

### Remaining manual review

- `AGENTS.md` and the agent-oriented implementation-plan docs were removed from the public
  tree.
- `docs/plans/2026-03-11-ssh-import-format-research.md` still contains local-machine
  inspection notes and should be rewritten or removed before checking the final
  “no proprietary/internal docs remain” item.
- Re-check future docs for internal-only roadmap or customer-specific language before
  publishing.
