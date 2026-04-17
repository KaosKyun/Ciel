---
description: Bootstrap or repair the project's Claude Code settings.json so Ciel hooks actually fire. Detects the plugin install path, writes absolute paths, preserves non-Ciel config, backs up before writing. Use when hooks silently fail (no "CIEL depth hint:" injection, no Stop meta-critiquer, "No such file or directory" on Write/Edit).
---

# /ciel-init — Wire Ciel hooks into the current project

*Fixes the #1 Ciel failure mode: hooks inactive because `settings.json` uses nonexistent filenames, is missing hook events, or uses relative paths that do not resolve from the project cwd.*

Usage: `/ciel-init [--check] [--user]`

- `--check` — dry-run: print the proposed diff without writing.
- `--user` — edit `~/.claude/settings.json` instead of the project file (useful for system-wide installs).
- no flag — apply the fix to `./.claude/settings.json`, backing up to `.bak-<timestamp>` first.

---

## Instructions to the model

You are repairing the current project's Claude Code `settings.json` so Ciel's hook pipeline fires end-to-end: SessionStart banner, UserPromptSubmit depth hint, Pre/PostToolUse FLUX + RELIRE, Stop meta-critiquer, PreCompact progress, SubagentStop report-size log.

This is a deterministic inline operation. Do NOT dispatch agents. Do NOT run `quoi-framer` or any Ciel pipeline skill — this command exists precisely because hooks may be broken.

### Step 1 — Resolve `$CIEL_DIR`

Find the Ciel plugin directory by checking these candidates in order, picking the first that contains `hooks/session-start.sh`:

1. `$CLAUDE_PLUGIN_DIR/ciel` if the env var is set
2. `$HOME/.claude/plugins/ciel`
3. `/root/.claude/plugins/ciel` (Linux system installs run as root)
4. Fallback: `find "$HOME" /root /opt -maxdepth 5 -path '*/plugins/ciel/hooks/session-start.sh' 2>/dev/null | head -1` then strip the suffix

If nothing is found → stop and tell the user to install Ciel first:
```
bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh)
```

### Step 2 — Pick the target file

- Default: `./.claude/settings.json`. Create the directory if missing.
- With `--user`: `$HOME/.claude/settings.json`.

If the file already exists and does not parse as JSON (`jq . <file> > /dev/null` fails) → stop and ask the user to fix the syntax first. Never overwrite broken JSON.

### Step 3 — Build the expected hooks block

Using `$CIEL_DIR`, the canonical Ciel hooks block is:

```json
{
  "SessionStart": [
    { "hooks": [ { "type": "command", "command": "bash $CIEL_DIR/hooks/session-start.sh", "statusMessage": "Ciel: session starting..." } ] }
  ],
  "UserPromptSubmit": [
    { "hooks": [ { "type": "command", "command": "bash $CIEL_DIR/hooks/user-prompt-submit.sh", "statusMessage": "Ciel: classifying depth..." } ] }
  ],
  "PreToolUse": [
    { "matcher": "Write|Edit", "hooks": [ { "type": "command", "command": "bash $CIEL_DIR/hooks/pre-tool-write.sh", "statusMessage": "Ciel: FLUX check..." } ] }
  ],
  "PostToolUse": [
    { "matcher": "Write|Edit", "hooks": [ { "type": "command", "command": "bash $CIEL_DIR/hooks/post-tool-write.sh", "statusMessage": "Ciel: RELIRE dispatch..." } ] }
  ],
  "Stop": [
    { "hooks": [ { "type": "command", "command": "bash $CIEL_DIR/hooks/stop.sh", "statusMessage": "Ciel: META-CRITIQUER..." } ] }
  ],
  "SubagentStop": [
    { "hooks": [ { "type": "command", "command": "bash $CIEL_DIR/hooks/subagent-stop.sh", "statusMessage": "Ciel: agent report size log..." } ] }
  ],
  "PreCompact": [
    { "hooks": [ { "type": "command", "command": "bash $CIEL_DIR/hooks/pre-compact.sh", "statusMessage": "Ciel: session progress save..." } ] }
  ]
}
```

Expand `$CIEL_DIR` to its absolute value in each `command`. Never emit a relative path starting with `.claude/`.

**Forbidden hook filenames** (do not resurrect these — they were renamed):
- `pre-write-gate.sh` → use `pre-tool-write.sh`
- `post-write-relire.sh` → use `post-tool-write.sh`

### Step 4 — Merge with existing config

Read the current `settings.json`. For the merged output:

- Preserve every top-level key except `hooks` exactly as-is (`model`, `contextWindow`, `thinking`, `ignorePatterns`, `permissions`, etc.).
- For the `hooks` key:
  - For each event, keep any existing non-Ciel hook entries (those whose `command` does NOT contain `plugins/ciel/hooks/`). Examples: project-specific `post-edit-check.sh`, `pre-close-check.sh`, ORCHESTRATION RULES `echo` commands, etc.
  - Drop any entries that reference `plugins/ciel/hooks/` with a stale or relative path.
  - Append the canonical Ciel entry from Step 3.

### Step 5 — Backup and write

1. `cp <file> <file>.bak-$(date +%Y%m%d-%H%M%S)` via Bash.
2. Validate the merged JSON with `jq .` on a temp file before replacing.
3. Move the temp file into place.

### Step 6 — Report and verify

Print to the user:
- `$CIEL_DIR` detected
- Target file edited
- Backup path
- Summary of what changed (events added, entries renamed/fixed, entries preserved)

Then give the verification steps:
1. Restart Claude Code.
2. In the new session, send any prompt. A `system-reminder` should contain `"CIEL depth hint:"`.
3. Make a Write or Edit call. A `system-reminder` should contain a `"CIEL "` prefix.
4. End the session. The Stop hook should trigger `meta-critiquer`.

### `--check` mode

Do not write. Run `diff <(jq -S . <current>) <(jq -S . <proposed>)` and show the unified diff. Exit without touching the filesystem.

### Guards

- Never `rm` the existing file — always `cp` to `.bak-*` first.
- Never silently drop a user's top-level setting. If merging is ambiguous, stop and ask.
- Never skip the `jq .` validation step — a malformed `settings.json` breaks every future session.
- Do not commit or push these changes — project-level `settings.json` is frequently in `.gitignore` and is per-machine.
