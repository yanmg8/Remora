---
title: Local Terminal
description: Use the local terminal to run your local shell.
---

Remora not only supports SSH remote connections but also provides complete local terminal functionality.

## Starting Local Terminal

### Creating a Local Session

1. Click the **+** button in the sidebar
2. Select **New Local Terminal**

### Differences from SSH Terminal

| Feature | Local Terminal | SSH Terminal |
|---------|----------------|--------------|
| Runs on | Local macOS | Remote server |
| Startup | Local shell process | SSH connection |
| Environment variables | Local environment | Remote server environment |
| File system | Local filesystem | Remote server filesystem |

## Local Terminal Features

- **Full terminal emulation**: ANSI/VT, 256 color, true color support
- **TUI compatible**: Works with vim, tmux, htop, etc.
- **History**: Inherits shell history (e.g., .zsh_history)
- **Auto-completion**: Supports shell built-in completions

## Use Cases

- Local development and testing
- Quick local command execution
- Use alongside SSH sessions (split panes)
