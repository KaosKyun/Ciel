---
description: Bootstrap or repair Ciel wiring. Auto-detects platform (Claude Code or OpenCode) and configures hooks, agents, and commands. Preserves existing config.
---

# /ciel-init — Wire Ciel into Current Project

**Purpose:** Fix the #1 failure mode — hooks not firing because config is missing or has wrong paths.

**Usage:** `/ciel-init [--yes]`

- No flags — interactive, prompts for confirmation
- `--yes` — skip prompts, run headless (use in CI / Claude sessions)

## Instructions

This is deterministic — NO agent dispatch, NO research, NO pipeline.

### Steps

1. **Run init:**
   ```bash
   # Global install (default)
   ciel init --yes

   # Or local install fallback:
   npx @neikyun/ciel init --yes
   ```
2. **Verify:** `ciel check` or `npx @neikyun/ciel check`
3. **Restart Claude Code** (`claude .`) or OpenCode after init

### What init does

- Detects platform: Claude Code (`.claude/`) or OpenCode (`opencode.json`)
- Copies hooks, agents, commands, and skills to your project
- Writes `.claude/settings.json` with Ciel hooks registered (Claude)
- Updates `opencode.json` plugin reference (OpenCode)
- Creates `.ciel/` state directory

### What's preserved

- `ciel-overlay.md` — project-specific rules
- `.ciel/` — state directory (map.json, memory.json, parking.md)
- Existing `settings.json` — merged non-destructively
- Existing `opencode.json` — merged non-destructively

### Error Handling

| Error | Action |
|-------|--------|
| `ciel: command not found` | Run `npm install -g @neikyun/ciel` first, or use `npx @neikyun/ciel` |
| Config write fails | Show manual instructions |
| Platform ambiguous | Add `.claude/` or `opencode.json` to project root |
| Permission denied | Check file permissions |
