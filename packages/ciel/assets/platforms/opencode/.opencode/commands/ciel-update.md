---
description: Update Ciel to the latest version via NPM. Preserves project config.
---

# /ciel-update — Update Ciel

Updates the NPM package and re-installs Ciel files in the current project.

Usage: `/ciel-update [--check]`

## Steps

1. **Run update:**
   ```bash
   npx @neikyun/ciel update --yes
   ```
2. **Verify:** `npx @neikyun/ciel check`

## What's preserved

- `.ciel/` — state directory
- `opencode.json` — merged non-destructively

## What's replaced

- `.opencode/plugins/ciel.js` — plugin
- `.opencode/agents/ciel-*.md` — agent definitions
- `.opencode/commands/ciel*.md` — command files
