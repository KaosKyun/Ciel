---
description: Update Ciel to the latest version via NPM. Preserves project config — ciel-overlay.md, .ciel/, settings.json.
---

# /ciel-update — Update Ciel to the latest version

Updates the NPM package and re-installs Ciel files (hooks, agents, commands, skills) in the current project.

Usage: `/ciel-update [--check]`

- No flag — full update (check + apply)
- `--check` — only check remote version, report, don't install

## Steps

1. **Run update:**
   ```bash
   # Global install (default)
   ciel update --yes

   # Or local install fallback:
   npx @neikyun/ciel update --yes
   ```
2. **Verify:** `ciel check` or `npx @neikyun/ciel check`

## What's preserved

- `ciel-overlay.md` — project-specific rules
- `.ciel/` — state directory (map.json, memory/, parking.md)
- `.claude/settings.json` — merged non-destructively

## What's replaced

- `.claude/hooks/*.sh` — shell hooks
- `.claude/agents/ciel-*.md` — agent definitions
- `.claude/commands/ciel-*.md` — command files
- `.claude/skills/` — domain skills

## Troubleshooting

| Symptom | Fix |
|---------|------|
| `ciel: command not found` | Run `npm install -g @neikyun/ciel` first, or use `npx @neikyun/ciel` |
| Plugin not loaded after update | Restart editor (plugin loaded at session start) |
| Hook permissions after update | `chmod +x .claude/hooks/*.sh` |
