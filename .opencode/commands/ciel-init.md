---
command: ciel-init
description: Initialize or reinstall Ciel in the current project
subtask: false
---

# /ciel-init — Initialize Ciel

Installs Ciel agents, hooks, and configuration for the current project. Detects OpenCode and/or Claude Code automatically.

Usage: `/ciel-init`

## What it does

- Detects platform (OpenCode / Claude Code / both)
- Copies agent definitions (`.opencode/agents/`)
- Copies commands (`.opencode/commands/`)
- Patches `opencode.json` with plugin reference
- Creates `.ciel/` state directory
