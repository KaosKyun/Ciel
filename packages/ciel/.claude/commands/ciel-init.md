---
description: Bootstrap or repair Ciel v7 wiring. Auto-detects platform (Claude Code or OpenCode) and configures hooks, agents, and commands. Preserves existing config, creates backups.
---

# /ciel-init — Wire Ciel into Current Project

**Purpose:** Fix the #1 failure mode — hooks not firing because config is missing or has wrong paths.

**Usage:** `/ciel-init [--check] [--user] [--platform=claude|opencode]`

- `--check` — Dry-run: show what would change without writing
- `--user` — Install to user scope (~/.claude/settings.json) instead of project
- `--platform=NAME` — Force platform (default: auto-detect)

## Instructions

This is deterministic — NO agent dispatch, NO research, NO pipeline.

### Step 1: Detect Platform

Run detection in order (pick FIRST match):

1. **Project files:**
   - `./opencode.json` or `./.opencode/` → **opencode**
   - `./.claude/settings.json` or `./.claude/` → **claude**

2. **CLI availability:**
   - `command -v claude` → **claude**
   - `command -v opencode` → **opencode**

3. **If ambiguous:** Ask user to specify with `--platform=NAME`

### Step 2: Find Ciel Source

Check in order:
1. `$CLAUDE_PROJECT_DIR/.claude/hooks/` — project-scoped install (v7 default)
2. `$HOME/.ciel/` — user-level sentinel
3. If not found → tell user to install:
   ```bash
   bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh)
   ```

### Step 3: Configure Platform

**Claude Code** — Backup then write `.claude/settings.json` with hooks registered:
- SessionStart, UserPromptSubmit, PreToolUse (Edit|Write + Bash rm + Agent), PostToolUse (Edit|Write), SubagentStart (ciel-*), Stop, SubagentStop, PreCompact
- Copy agents from source to `.claude/agents/`
- Copy commands from source to `.claude/commands/`
- Copy skills from source to `.claude/skills/`
- Ensure `CLAUDE.md` references Ciel pipeline

**OpenCode** — Backup then ensure `opencode.json`:
- `plugin` array contains `"./.opencode/plugins/ciel.ts"`
- `instructions` array contains `"AGENTS.md"`
- Copy plugin, agents, commands to `.opencode/`

### Step 4: Verify

1. Config file exists at expected path
2. Hooks are executable: `chmod +x .claude/hooks/*.sh`
3. Agent definitions present (4 files)
4. Report summary: platform, config path, hooks count, next steps

## What's preserved

- `ciel-overlay.md` — project-specific rules
- `.ciel/` — state directory (map.json, memory.json, parking.md)
- Existing `settings.json` — merged non-destructively
- Existing `opencode.json` — merged non-destructively

## Error Handling

| Error | Action |
|-------|--------|
| Ciel source not found | Tell user to run install script |
| Config write fails | Show manual instructions |
| Platform ambiguous | Ask user to specify with --platform |
| Permission denied | Check file permissions |
