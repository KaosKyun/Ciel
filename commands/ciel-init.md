---
description: Bootstrap or repair Ciel wiring. Auto-detects platform (Claude Code, OpenCode, Cursor, etc.) and configures hooks. Preserves existing config, creates backups.
---

# /ciel-init — Wire Ciel into Current Project

**Purpose:** Fix the #1 Ciel failure mode — hooks not firing because config is missing, has wrong paths, or platform not detected.

**Usage:** `/ciel-init [--check] [--user] [--platform=NAME]`

- `--check` — Dry-run: show what would change without writing
- `--user` — Install to user scope (~/.claude/settings.json) instead of project
- `--platform=NAME` — Force platform (claude, opencode, cursor, windsurf, codex, kilocode, ollama, lmstudio)

---

## Instructions

You are repairing Ciel wiring. This is deterministic — NO agent dispatch, NO research, NO pipeline.

### Step 1: Detect Platform

Run detection in order (pick FIRST match):

1. **Project files:**
   - `./opencode.json` or `./.opencode/` → **opencode**
   - `./.claude/settings.json` or `./.claude/` → **claude**
   - `./.cursor/` → **cursor**
   - `./.windsurf/` → **windsurf**
   - `./.codex/` → **codex**
   - `./.kilocode/` or `./.kilo/` → **kilocode**

2. **CLI availability:**
   - `command -v claude` → **claude**
   - `command -v opencode` → **opencode**
   - `command -v ollama` → **ollama**

3. **If ambiguous:** Ask user to specify with `--platform=NAME`

### Step 2: Find Ciel Directory

Check in order:
1. `$CLAUDE_PLUGIN_DIR/ciel` (if env var set)
2. `$HOME/.claude/plugins/ciel`
3. `$HOME/.ciel`
4. `find "$HOME" -maxdepth 5 -path '*/ciel/hooks/session-start.sh' 2>/dev/null | head -1`

If not found → Tell user to run install first:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh)
```

### Step 3: Verify Hooks Exist

Check for 8 required hooks in `$CIEL_DIR/hooks/`:
```
session-start.sh, user-prompt-submit.sh, pre-tool-write.sh, post-tool-write.sh,
stop.sh, subagent-stop.sh, pre-compact.sh, pre-agent-gate.sh
```

If missing → Copy from nearest Ciel source or tell user to reinstall.

### Step 4: Configure Platform

#### Claude Code Branch

**Config file:** `./.claude/settings.json` (project) or `$HOME/.claude/settings.json` (user)

**Before writing:**
1. Check CWD sanity — warn if running Claude from different directory
2. Backup existing config: `cp file.json file.json.bak-TIMESTAMP`

**Write config:**
```json
{
  "hooks": {
    "SessionStart": { "command": "$CIEL_DIR/hooks/session-start.sh", "stdin": true },
    "UserPromptSubmit": { "command": "$CIEL_DIR/hooks/user-prompt-submit.sh", "stdin": true },
    "PreToolUse": { "command": "$CIEL_DIR/hooks/pre-tool-write.sh", "stdin": true, "matcher": "Write|Edit" },
    "PostToolUse": { "command": "$CIEL_DIR/hooks/post-tool-write.sh", "stdin": true, "matcher": "Write|Edit" },
    "PreCompact": { "command": "$CIEL_DIR/hooks/pre-compact.sh", "stdin": true },
    "Stop": { "command": "$CIEL_DIR/hooks/stop.sh", "stdin": true }
  }
}
```

#### OpenCode Branch

**Config file:** `./opencode.json`

**Before writing:**
1. Backup: `cp opencode.json opencode.json.bak-TIMESTAMP`
2. Merge existing config (preserve model, provider, mcp, keybinds)

**Ensure:**
- `plugin` array contains `"./.opencode/plugins/ciel.ts"`
- `instructions` array contains `"AGENTS.md"`

**Copy files:**
- `.opencode/plugins/ciel.ts`
- `.opencode/agents/ciel-*.md` (6 files)
- `.opencode/commands/ciel-*.md` (9 files)

#### Other Platforms Branch

Install platform-specific artifacts:
- **Cursor:** `.cursor/rules/ciel.mdc`
- **Windsurf:** `.windsurf/rules/*.md`
- **Codex:** `AGENTS.md`, `.codex/hooks.json`
- **Kilocode:** `.kilocode/rules/ciel.md`, `.kilo/agents/*`
- **Ollama:** `Modelfile` (user runs `ollama create`)
- **LM Studio:** `ciel.preset.json`, `system-prompt.md`

### Step 5: Verification

After configuration, verify:

1. **Config file exists** at expected path
2. **Hooks are executable:** `chmod +x "$CIEL_DIR/hooks/"*.sh`
3. **Plugin file syntax valid** (for OpenCode: `npx tsc --noEmit`)

### Step 6: Report

Output summary:

```
✓ /ciel-init completed

Platform: Claude Code
Config: /path/to/settings.json
CIEL_DIR: /path/to/ciel
Hooks: 8/8 present

Next steps:
1. Restart Claude Code
2. Run a test prompt — should see depth hint
3. Make code changes — should see RELIRE reminder
```

---

## Error Handling

| Error | Action |
|-------|--------|
| Ciel directory not found | Tell user to run install script |
| Hooks missing | Try to copy from source, else reinstall |
| Config write fails | Show manual instructions |
| Platform ambiguous | Ask user to specify with --platform |
| Permission denied | Suggest running with sudo or check file permissions |

---

## Examples

```bash
# Auto-detect and install to project
/ciel-init

# Force Claude Code, user scope
/ciel-init --platform=claude --user

# Check what would change (dry-run)
/ciel-init --check

# Force OpenCode
/ciel-init --platform=opencode
```
