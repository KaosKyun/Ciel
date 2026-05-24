---
description: Displays current Ciel environment status — version, platform, hooks, skills, agents, commands, memory health. Diagnostic entry point for "is Ciel working?" questions.
---

# /ciel-status — Ciel Environment Health Check

Displays the current Ciel environment status: version, platform, hooks, skills, agents, and config health.

Usage: `/ciel-status [--check]`

- No flag — summary view
- `--check` — run full diagnostics (verify hooks fire, skills load, config valid)

## Summary output

```
## CIEL STATUS

Version: v4.0.1
Platform: Claude Code
Config: .claude/settings.json — OK
Hooks: 12 registered
Skills: 48 domain skills in .claude/skills/
Agents: 4 sub-agents (researcher, explorer, critic, improver)
Commands: 7 available
Memory: .ciel/memory/ — N episodes
```

## Diagnostics (--check)

- CLAUDE.md readable and includes Ciel pipeline
- .claude/settings.json valid JSON, all hooks registered
- .ciel/map.json parseable
- .ciel/memory/index.json present
- Shell hooks executable and firing
- Skills directory non-empty
- Agent definitions present (4 files)

## When to use

- After `/ciel-init` to verify installation
- When "is Ciel working?" is asked
- Debugging hook failures or missing depth classification
