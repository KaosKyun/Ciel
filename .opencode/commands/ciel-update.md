---
description: Update Ciel to the latest version via NPM. Checks NPM registry, updates global package, force-reinstalls in project.
---

# /ciel-update — Update Ciel to the latest version

## Steps

### Global install (recommended)

```bash
# 1. Check
ciel check

# 2. Update global package
npm update -g @neikyun/ciel

# 3. Force reinstall in project (new plugin JS, agents, commands, hooks)
ciel update
```

### Project-local install

```bash
npm update @neikyun/ciel   # postinstall auto-updates everything
```

## What's preserved

- `ciel-overlay.md` — project-specific rules
- `.ciel/map.json`, `.ciel/memory.json`, `.ciel/parking.md` — persistent state
- `opencode.json` — existing config patched non-destructively

## What's replaced

- `.opencode/plugins/ciel.js` — compiled plugin
- `.opencode/agents/ciel-*.md` — agent definitions
- `.opencode/commands/ciel-*.md` — command files
- `.claude/agents/ciel-*.md` — Claude Code agents
- `.claude/hooks/*.sh` — shell hooks
- `CLAUDE.md` — root instruction
- `.claude/settings.json` — hook config

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Plugin not loaded after update | Restart OpenCode (plugin loaded at session start) |
| `ciel: command not found` | Reinstall globally: `npm install -g @neikyun/ciel` |
| NPM registry unreachable | Check internet or proxy: `HTTPS_PROXY=... ciel check` |
