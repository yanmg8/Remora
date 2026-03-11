---
title: Import & Export
description: Import existing SSH config or export Remora data.
---

Remora supports importing host configurations from multiple sources and exporting data for backup.

## Importing Config

### Import Formats

Remora supports the following import formats:

- **SSH Config**: Import from `~/.ssh/config`
- **Remora Export**: Import from `.remora` or `.csv` file
- **WindTerm**: Import from WindTerm user.sessions JSON
- **electerm**: Import from electerm bookmark export JSON
- **Xshell**: Import from Xshell `.sh` or `.xts` files
- **PuTTY**: Import from exported PuTTY `.reg` files

### Import Steps

1. Open **Remora > Import Connections**
2. Select import source
3. Select file to import
4. Select hosts to import
5. Click **Import**

## Exporting Data

### Export as Remora Format

Export host configurations as a `.remora` file:

1. Open **Remora > Export Connections**
2. Select export scope (all or specific group)
3. Choose whether to include saved passwords
4. Choose save location

Exported file contains:
- Host configuration
- Host groups
- Quick commands
- Quick paths

### Export as CSV

Export as CSV format for spreadsheet processing.

### Export as JSON

Export as JSON format for use with other tools.

## Data Migration

### Migrating to New Device

1. Export config on old device
2. Transfer export file to new device
3. Import config on new device

### Backup Recommendations

- Regularly backup your configuration
- Keep export files secure
