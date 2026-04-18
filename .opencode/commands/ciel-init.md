---
description: "Bootstrap or repair Ciel wiring for the current project — fix hook config, backup before writing"
---

# /ciel-init — Wire Ciel into the current project

Fixes Ciel hooks not firing. Auto-detects Claude Code vs OpenCode and fixes the config.

Usage: `/ciel-init [--check] [--user]`

Args: $ARGUMENTS

---

## OpenCode-specific instructions

For OpenCode, verify these files exist and are correct:

1. `.opencode/plugins/ciel.ts` — must be the Ciel v2.7.2 plugin
2. `.opencode/agents/ciel-*.md` — 4 agents with valid frontmatter
3. `.opencode/commands/ciel*.md` — all commands
4. `opencode.json` — must contain `"plugin": ["./.opencode/plugins/ciel.ts"]`

If any is missing or broken, fix it by copying from the Ciel repo.

Check the plugin hooks are firing: look for `[CIEL]` messages in the terminal output.

---

## Check mode

When run with `--check`, do a dry-run audit:

1. Read `opencode.json` → verify `plugin` entry exists
2. Check `.opencode/plugins/ciel.ts` exists and imports `@opencode-ai/plugin`
3. Check all 4 agents exist with valid `description` in frontmatter
4. Check all commands exist with valid `description` in frontmatter
5. Report what's broken without fixing
