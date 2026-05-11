---
description: ---
subtask: false
---

---
description: Check GitHub for newer Ciel release and re-install. Runs `scripts/install.sh --check-update` then `--update`.
---

# /ciel-update — Update Ciel to the latest version

Checks GitHub for a newer release and re-installs if available.

## Steps

1. **Check version**: `bash scripts/install.sh --check-update`
   - Fetches `VERSION` from GitHub, compares with local
   - Prints "up to date" or "update available"

2. **Apply update**: `bash scripts/install.sh --update -y`
   - Re-installs all Ciel files (plugins, agents, commands, hooks)
   - Preserves: `ciel-overlay.md`, `.ciel/`, existing configs
   - Non-destructive merge on `opencode.json`

## Flags

| Flag | Purpose |
|------|---------|
| `--check-update` | Check remote version, don't install |
| `--update` / `-u` | Force reinstall all files |
| `-y` | Skip confirmation (non-interactive) |
| `-q` | Quiet mode (summary only) |

## One-liner

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh) --check-update
bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh) --update -y
```

## What's preserved

- `ciel-overlay.md` — project-specific rules
- `.ciel/map.json`, `.ciel/memory.json`, `.ciel/parking.md`
- `opencode.json` — existing config merged non-destructively
- `.claude/settings.json` — hook paths preserved

## What's replaced

- `.opencode/plugins/ciel.ts` — fresh plugin
- `.opencode/agents/ciel-*.md` — agent definitions
- `.opencode/commands/ciel-*.md` — command files
- `.claude/agents/ciel-*.md` — Claude Code agents
- `.claude/hooks/*.sh` — shell hooks
- `CLAUDE.md` — root instruction

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Could not fetch remote version` | Check internet or proxy: `https_proxy=... bash install.sh --check-update` |
| Plugin not loaded after update | Restart OpenCode (plugin loaded at session start) |
| `jq not found` warning | Install jq for automatic opencode.json patching |
