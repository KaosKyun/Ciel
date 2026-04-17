---
description: /ciel-update — Update Ciel to latest version
subtask: false
---

# /ciel-update — Update Ciel to latest version

Checks GitHub for a newer version of Ciel and hot-swaps local files.

## What it updates
- `~/.claude/skills/ciel/SKILL.md` — core workflow
- `.claude/commands/ciel.md` — entry command
- `~/.claude/plugins/ciel/hooks/` — pre/post write hooks

## How to run

```bash
bash /root/.claude/plugins/ciel/scripts/self-update.sh
```

Then restart Claude Code to apply changes.

## How it works

1. Fetches remote SKILL.md SHA from GitHub API via `gh` CLI
2. Compares with stored SHA in `/root/.claude/plugins/ciel/.version`
3. If different → downloads all updated files
4. Stores new SHA → next run skips download if already current

## Requirements
- `gh` CLI installed and authenticated (`gh auth status`)
- Private repo access (already configured if you installed Ciel)

## Frequency recommendation
Run at the start of a new project or after a significant gap between sessions.
Not needed every session — CHANGELOG.md lists what changed between versions.
