# SSH Import Format Research

Date: 2026-03-11

## Scope

Remora currently imports only its own JSON/CSV export format:

- `Sources/RemoraApp/HostConnectionImporter.swift`
- `Sources/RemoraApp/HostConnectionExporter.swift`

This note compares export or persisted connection formats from the SSH tools the user wants to support next:

- Termius
- Xshell
- WindTerm
- FinalShell
- electerm

The goal is to identify which formats are practical to import directly, which fields map cleanly to `RemoraCore.Host`, and which tools still need a real sample file before implementation.

## Remora Current Format

Remora JSON and CSV both serialize the same logical fields:

- `id`
- `name`
- `address`
- `port`
- `username`
- `group`
- `tags`
- `note`
- `favorite`
- `lastConnectedAt`
- `connectCount`
- `authMethod`
- `privateKeyPath`
- `password`
- `keepAliveSeconds`
- `connectTimeoutSeconds`
- `terminalProfileID`

This is the target model for third-party import normalization.

## Findings By Tool

### 1. WindTerm

Confidence: high

Most useful import artifact:

- User profile directory, not a single ad-hoc export file.
- On macOS, the active profile root is controlled by `profiles.config`.
- On this machine, WindTerm stores user sessions at:
  - `~/SSHConfig/.wind/profiles/default.v10/terminal/user.sessions`

Observed structure:

- File type: JSON
- Top level: array
- Each item: one session object

Observed SSH session keys:

- `session.protocol`
- `session.label`
- `session.target`
- `session.port`
- `session.group`
- `session.uuid`
- `session.icon`
- `session.autoLogin`
- `ssh.identityFilePath`

Observed non-SSH entries:

- WindTerm also stores local shell sessions in the same array with keys like:
  - `process.arguments`
  - `process.workingDirectory`
  - `session.protocol = "Shell"`
  - `session.target = /bin/zsh`

Import implications:

- Filter to `session.protocol == "SSH"`.
- `session.label -> name`
- `session.target -> address`
- `session.port -> port`
- `session.group -> group`
- `ssh.identityFilePath -> privateKeyPath`
- Username and password are not stored as plain top-level fields in the sampled SSH entries.
- `session.autoLogin` is an encrypted blob, so credential import is not currently reliable without reverse-engineering WindTerm encryption.

Practicality:

- Good first target.
- Host-only import is straightforward.
- Password/private key passphrase import should be treated as unsupported unless decryption is intentionally added.

### 2. electerm

Confidence: high

Most useful import artifacts:

- Bookmark export JSON
- Local SQLite database

Observed local storage on this machine:

- `~/Library/Application Support/electerm/users/default_user/electerm.db`
- Tables:
  - `bookmarks`
  - `bookmarkGroups`
  - `profiles`
  - `quickCommands`
  - `addressBookmarks`

Observed local table shape:

- Table schema is simple:
  - `_id TEXT PRIMARY KEY`
  - `data TEXT`
- `data` is JSON text.

Observed bookmark JSON fields:

- `title`
- `host`
- `username`
- `authType`
- `password`
- `port`
- `useSshAgent`
- `sshAgent`
- `encode`
- `type`
- `enableSsh`
- `enableSftp`
- `envLang`
- `term`
- `displayRaw`
- `cipher`
- `serverHostKey`
- `sshTunnels`
- `connectionHoppings`
- `color`
- `runScripts`
- `quickCommands`
- `passwordEncrypted`

Observed bookmark group JSON fields:

- `title`
- `bookmarkIds`
- `bookmarkGroupIds`

Export behavior confirmed from app bundle:

- Bookmark export writes a JSON object:
  - `{ "bookmarkGroups": [...], "bookmarks": [...] }`
- Bookmark export filename pattern:
  - `bookmarks-YYYY-MM-DD-HH-mm-ss.json`
- Quick command export writes a JSON array:
  - `electerm-quickCommands-YYYY-MM-DD-HH-mm-ss.json`
- Profile export reuses the same array-export behavior as quick commands.

Import implications for bookmark export:

- `title -> name`
- `host -> address`
- `port -> port`
- `username -> username`
- Group is recoverable by walking `bookmarkGroups.bookmarkIds`
- `authType` maps well:
  - `password`
  - `privateKey`
  - profile-based auth may need fallback handling
- `passwordEncrypted: true` means the `password` field should not be assumed to be portable plain text
- `quickCommands` is present and could be partially mapped later

Practicality:

- Good second target.
- The bookmark export JSON is stable enough to support directly.
- Credentials should probably be imported conservatively:
  - keep auth method
  - do not blindly trust `password` as plaintext

### 3. Xshell

Confidence: medium-high

Most useful import artifacts:

- Official export package: `.xts`
- Extracted per-session files: `.xsh`

Documented/exported packaging:

- Xshell export uses `.xts`
- `.xts` is a ZIP archive
- The archive contains session files and can be imported or extracted

Observed session file characteristics from public parser samples:

- `.xsh` is plain text
- Encoding is UTF-16 LE
- Structure is INI-like key/value text
- Public parsers read keys such as:
  - `Host`
  - `Port`
  - `UserName`
  - `Protocol`
  - `Password`
  - `PasswordV2`
  - `Description`
  - `FontSize`

Import implications:

- Supporting raw `.xsh` is simpler than supporting the whole `.xts` package first.
- Supporting `.xts` is still practical:
  - unzip
  - enumerate contained `.xsh`
  - parse UTF-16 LE key/value files
- Password handling is risky:
  - values may be encrypted or protected depending on Xshell settings and master password usage

Practicality:

- Good target after WindTerm/electerm.
- Session metadata import looks feasible.
- Credential import is likely partial unless Xshell encryption is explicitly implemented.

### 4. FinalShell

Confidence: low-medium

Most useful import artifact currently identified:

- Profile or connection directory, not a clearly documented stable export JSON schema

Publicly documented storage clues:

- Official FinalShell documentation points to a user config directory under `.finalshell`
- Community migration posts on macOS point to `~/Library/FinalShell/conn`

Current problem:

- I found public references for the storage location, but not a trustworthy public sample of the actual per-connection file structure.
- That means I do not yet have enough evidence to define:
  - file extension
  - top-level schema
  - credential field layout
  - grouping model

Practicality:

- Not ready for implementation from public docs alone.
- Needs a real exported directory or a local install sample before writing a parser.

Recommendation:

- Ask for one anonymized `conn` directory sample before implementation.

### 5. Termius

Confidence: low

Current problem:

- I did not find a trustworthy public description of a native Termius connection export file schema.
- I also did not confirm a stable desktop export artifact equivalent to Xshell `.xts` or WindTerm `user.sessions`.

What this means for implementation:

- A native Termius importer should not be started from assumptions.
- The realistic interop route may be:
  - OpenSSH config export, if the user can produce it
  - CSV export, if the user has a Termius workflow that emits one
  - or a native export sample supplied by the user

Practicality:

- Blocked until we get a real exported sample file or a confirmed official export route.

Recommendation:

- Ask for one anonymized Termius export file before implementation.

## Recommended Import Priority

### Tier 1: implement now

1. WindTerm
2. electerm
3. Xshell

These already have a discoverable file structure and enough fields to build a reliable host import path.

### Tier 2: wait for sample files

1. FinalShell
2. Termius

These still need real exported artifacts before we should design a parser.

## Proposed Parser Strategy

### WindTerm

- Accept `user.sessions`
- Parse JSON array
- Keep only `session.protocol == "SSH"`
- Map:
  - `session.label -> name`
  - `session.target -> address`
  - `session.port -> port`
  - `session.group -> group`
  - `ssh.identityFilePath -> auth.keyReference`
- Ignore `session.autoLogin` for now

### electerm

- Accept bookmark export JSON
- Require top-level object with:
  - `bookmarks`
  - `bookmarkGroups`
- Build group lookup from `bookmarkGroups`
- Map:
  - `title -> name`
  - `host -> address`
  - `port -> port`
  - `username -> username`
  - `authType -> auth.method`
- Default to not importing encrypted password material

### Xshell

- Phase 1:
  - accept `.xsh`
  - decode UTF-16 LE
  - parse key/value fields
- Phase 2:
  - accept `.xts`
  - unzip and import all `.xsh`

## Risks

- Credentials are the unstable part across all three feasible targets.
- Session metadata is much easier than password portability.
- For first implementation, importing host, port, username, group, and key path is much safer than trying to preserve encrypted secrets.

## Sources

- Xshell official export packaging: [NetSarang Xshell/Xftp session export guide](https://netsarang.atlassian.net/wiki/spaces/PUB/pages/175276032/Xshell%2BXftp%2BExporting%2Band%2BImporting%2BSession%2BFiles)
- Xshell `.xsh` parser sample: [convert_xsh.py gist](https://gist.github.com/serkanh/3782857)
- WindTerm repository and release notes: [WindTerm GitHub repository](https://github.com/kingToolbox/WindTerm)
- FinalShell official docs root: [Hostbuf FinalShell docs](https://www.hostbuf.com/)
- FinalShell config path article: [How to share or move FinalShell config files](https://www.hostbuf.com/t/988.html)

## Local Inspection Notes

The following findings were confirmed by inspecting locally installed apps on this machine, not by copying user secrets into the repository:

- WindTerm:
  - `~/SSHConfig/.wind/profiles/default.v10/terminal/user.sessions`
  - `~/SSHConfig/.wind/profiles/default.v10/user.config`
- electerm:
  - `~/Library/Application Support/electerm/users/default_user/electerm.db`
  - `app.asar` export logic inside `/Applications/electerm.app/Contents/Resources/app.asar`
