---
description: Displays the current Ciel environment status — active version, loaded skills, registered hooks, last session state, and configuration health. A diagnostic entry point for "is Ciel working?" questions.
---

# /ciel-status — Ciel Environment Health Check

*Displays the current Ciel environment status: version, skills, hooks, and config.*

Usage: `/ciel-status [--check]`

- `--check` — run diagnostics (verify hooks fire, skills load, config is valid)

## Output

```
## CIEL STATUS

Version: v{{VERSION}}
Platform: Claude Code
Config: .claude/settings.json — OK (4 hooks registered)
Skills directory: skills/ — 43 skills loaded
Commands: 7 commands available
Last session: 2026-05-06T11:20:00Z — Skills library reorg
```

## Diagnostics (--check)

- [ ] CLAUDE.md readable and includes Ciel pipeline
- [ ] .claude/settings.json valid JSON, hooks registered
- [ ] .ciel/map.json parseable and up-to-date
- [ ] .ciel/memory.json parseable
- [ ] Shell hooks executable (check-test-first, block-destructive, track-file, meta-critiquer)
- [ ] Skills directory non-empty and accessible
- [ ] Agent definitions present (.claude/agents/ or .opencode/agents/)

## When triggered

- User asks "is Ciel working?" or "check Ciel health"
- After ciel-init to verify installation
- Debugging hook failures or missing depth classification
