---
title: Security Settings
description: Learn about Remora's security mechanisms and configuration options.
---

Remora uses a local-first security strategy to protect your credentials and connections.

## Credential Storage

### Keychain Storage

Remora uses macOS Keychain to securely store passwords:

- Passwords encrypted in system Keychain
- Asked to save on first connection

### Exporting Credentials

When exporting host configurations, you can choose whether to include saved passwords. Exported files with passwords are stored in plaintext - handle with care.

## SSH Keys

### Supported Key Formats

Remora supports the following SSH key formats:

- RSA (2048/4096 bits)
- ED25519
- ECDSA (256/384/521 bits)

### Key Locations

Key files are typically stored in `~/.ssh/`:

```
~/.ssh/id_rsa
~/.ssh/id_ed25519
~/.ssh/id_ecdsa
```

### Key Permissions

Ensure private key permissions are correct:

```bash
chmod 600 ~/.ssh/id_ed25519
```

## Host Fingerprints

When connecting to a new host for the first time, Remora displays the host fingerprint for confirmation. You can choose to accept or reject the host key.
