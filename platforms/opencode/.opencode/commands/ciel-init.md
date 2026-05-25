---
description: Bootstrap or repair Ciel wiring for OpenCode. Auto-detects platform and configures plugin, agents, and commands.
---

# /ciel-init — Wire Ciel into Current Project

**Usage:** `/ciel-init [--yes]`

## Steps

1. **Run init:**
   ```bash
   npx @neikyun/ciel init --yes
   ```
2. **Verify:** `npx @neikyun/ciel check`
3. **Restart OpenCode** to load the Ciel plugin

### What init does

- Detects OpenCode from `opencode.json` or `.opencode/`
- Copies plugin (`ciel.js`), agents, and commands to `.opencode/`
- Updates `opencode.json` plugin reference

### Error Handling

| Error | Action |
|-------|--------|
| `npx: command not found` | Install Node.js first |
| Config write fails | Check file permissions |
