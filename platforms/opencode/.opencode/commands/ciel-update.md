---
description: Check GitHub for newer Ciel release and re-install. Preserves project config — ciel-overlay.md, .ciel/, settings.json.
---

# /ciel-update — Update Ciel to the latest version

Checks GitHub for a newer release and re-installs if available.

Usage: `/ciel-update [--check]`

- No flag — full update (check + apply)
- `--check` — only check remote version, report, don't install

## Steps

1. **Check version**: fetch `VERSION` from GitHub, compare with `.ciel/version` or `VERSION`
2. **Apply update**: re-install all Ciel files (hooks, agents, commands, skills, plugin)
3. **Verify**: confirm hooks executable, agents present, config valid

## What's preserved

- `ciel-overlay.md` — project-specific rules
- `.ciel/` — state directory (map.json, memory/, parking.md)
- `.claude/settings.json` — merged non-destructively
- `.opencode/opencode.json` — merged non-destructively

## What's replaced

- `.claude/hooks/*.sh` — shell hooks
- `.claude/agents/ciel-*.md` — agent definitions
- `.claude/commands/ciel-*.md` — command files
- `.claude/skills/` — domain skills
- `.opencode/plugins/ciel.ts` — plugin
- `.opencode/agents/ciel-*.md` — OpenCode agents
- `.opencode/commands/ciel*.md` — OpenCode commands

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Could not fetch remote version | Check internet or proxy: `https_proxy=...` |
| Plugin not loaded after update | Restart editor (plugin loaded at session start) |
| Hook permissions after update | `chmod +x .claude/hooks/*.sh` |
