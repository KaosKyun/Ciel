---
description: Bootstrap or repair Ciel wiring. Auto-detects Claude Code vs OpenCode, fixes config so hooks fire. Backs up before writing. Use when hooks fail (no depth hint, no RELIRE reminder).
---

# /ciel-init — Wire Ciel v5 into the current project (Claude Code + OpenCode)

*Fixes the most common Ciel failure mode: hooks/plugin inactive because files reference nonexistent paths, missing events, or wrong versions. Detects Ciel v5 and installs components accordingly.*

Usage: `/ciel-init [--check] [--user] [--platform=claude|opencode]`

- `--check` — dry-run: print the proposed diff without writing.
- `--user` — edit the user-scope config (`~/.claude/settings.json` for Claude, `~/.config/opencode/opencode.json` for OpenCode) instead of the project file.
- `--platform=claude|opencode` — force the target platform; skip auto-detection.
- no flag — apply the fix to the detected platform's project config, backing up to `.bak-<timestamp>` first.

---

## Instructions to the model

You are repairing the current project's Ciel wiring so the deep-reasoning pipeline fires end-to-end. This is a deterministic inline operation. Do NOT dispatch agents. Do NOT run `quoi-framer` or any Ciel pipeline skill — this command exists precisely because the hooks that would normally carry those signals may be broken.

### Step 0 — Detect target platform

If `--platform=<X>` was passed, skip detection and use `X`. Otherwise, run these checks in order and pick the FIRST signal that matches:

1. `./opencode.json` exists OR `./.opencode/` directory exists → **OpenCode**
2. `./.claude/settings.json` exists OR `./.claude/` directory exists → **Claude**
3. `command -v opencode` succeeds AND `command -v claude` does not → **OpenCode**
4. `command -v claude` succeeds → **Claude**
5. Ambiguous (both exist / neither exists) → stop and ask the user:
   > "Cannot auto-detect platform. Re-run with `--platform=claude` or `--platform=opencode`."

If the user passed `--check`, still run the detection and report it — just skip the write at the end.

### Step 0b — Wrong-CWD sanity check (added v2.5.0 after audit violation #1)

Hooks wired into `./.claude/settings.json` only fire when Claude Code is launched with **the current working directory at or above that `.claude/`**. A common failure mode: the user is working from a project root like `/Users/you/Projects/myapp/` where the Ciel repo clone lives at `/Users/you/Projects/myapp/Ciel/`. Running `/ciel-init` with no flag creates `./Ciel/.claude/settings.json` — one level below where the running Claude session actually reads.

Before writing the project-scope file, emit a warning if:

- The resolved target path is `<cwd>/.claude/settings.json` but `<cwd>` is not the parent directory of a sibling `.claude/` of any ancestor directory the user's running Claude Code is rooted at, AND
- The current directory contains a subdirectory that is a git repo (suggests the user is one level too high), OR
- The running Claude Code project root (detectable via `$CLAUDE_PROJECT_DIR` or the `cwd` field of a hook stdin) does not match the target directory.

Warning template:

```
[CIEL-INIT WARN] Creating ./.claude/settings.json at <target-dir>.
Your running Claude Code session may not read this location if its CWD
differs. If /ciel-init does not take effect after restart, re-run with
  /ciel-init --user
to target $HOME/.claude/settings.json instead (applies to all sessions
on this machine regardless of CWD).
```

The warn is non-blocking — proceed with the write but make the fallback option visible.

### Step 1 — Resolve `$CIEL_DIR` (shared by both branches)

Find the Ciel plugin directory by checking these candidates in order, picking the first that contains `hooks/session-start.sh`:

1. `$CLAUDE_PLUGIN_DIR/ciel` if the env var is set
2. `$HOME/.claude/plugins/ciel`
3. `/root/.claude/plugins/ciel` (Linux system installs run as root)
4. Fallback: `find "$HOME" /root /opt -maxdepth 5 -path '*/plugins/ciel/hooks/session-start.sh' 2>/dev/null | head -1` then strip the suffix

If nothing is found → stop and tell the user to install Ciel first:
```
bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh)
```

### Step 1b — Verify hooks are physically present

After resolving `$CIEL_DIR`, check that `$CIEL_DIR/hooks/` contains the 8 required scripts (v3.3.0 removed counter hooks):

```
session-start.sh  user-prompt-submit.sh  pre-tool-write.sh  pre-agent-gate.sh
post-tool-write.sh  stop.sh  subagent-stop.sh  pre-compact.sh
```

Run: `ls "$CIEL_DIR/hooks/"*.sh 2>/dev/null | wc -l`

If the count is < 8 (directory absent or scripts missing):

1. Locate the Ciel source repo by checking these candidates in order:
   - `find "$HOME" -maxdepth 7 -path '*/Ciel/hooks/session-start.sh' 2>/dev/null | head -1` → strip `/hooks/session-start.sh` suffix
2. If a source directory is found: `mkdir -p "$CIEL_DIR/hooks" && cp "<source>/hooks/"*.sh "$CIEL_DIR/hooks/"`
3. If no source found: stop and tell the user to reinstall Ciel:
   ```
   bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh)
   ```

Report any hooks that were copied during this repair step in the Step C5/O6 summary.

### Step 2 — Branch on platform

Jump to **Claude branch** or **OpenCode branch** below.

---

## Claude branch

### Step C1 — Pick the target file

- Default: `./.claude/settings.json`. Create the directory if missing.
- With `--user`: `$HOME/.claude/settings.json`.

If the file already exists and does not parse as JSON (`jq . <file> > /dev/null` fails) → stop and ask the user to fix the syntax first. Never overwrite broken JSON.

### Step C2 — Build the expected hooks block

Using `$CIEL_DIR`, the canonical Ciel v5 hooks block is:

```json
{
  "autoMemoryEnabled": true,
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CIEL_DIR/.claude/hooks/check-test-first.sh",
            "statusMessage": "Ciel: checking test-first gate..."
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(rm *)",
            "command": "bash $CIEL_DIR/.claude/hooks/block-destructive.sh",
            "statusMessage": "Ciel: blocking destructive commands..."
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CIEL_DIR/.claude/hooks/track-file.sh",
            "statusMessage": "Ciel: tracking files for RELIRE..."
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash $CIEL_DIR/.claude/hooks/meta-critiquer.sh",
            "statusMessage": "Ciel: META-CRITIQUER..."
          }
        ]
      }
    ]
  }
}
```

Expand `$CIEL_DIR` to its absolute value in each `command`. Never emit a relative path starting with `.claude/`.

**Forbidden legacy hook filenames** (v4 era — do not use):
- `session-start.sh`, `user-prompt-submit.sh`, `pre-tool-write.sh`, `pre-agent-gate.sh`
- `post-tool-write.sh`, `stop.sh`, `subagent-stop.sh`, `pre-compact.sh`
- These were replaced by the 4 v5 hooks above

### Step C3 — Merge with existing config

Read the current `settings.json`. For the merged output:

- Preserve every top-level key except `hooks` exactly as-is (`model`, `contextWindow`, `thinking`, `ignorePatterns`, `permissions`, etc.).
- For the `hooks` key:
  - For each event, keep any existing non-Ciel hook entries (those whose `command` does NOT contain `plugins/ciel/hooks/`). Examples: project-specific `post-edit-check.sh`, `pre-close-check.sh`, ORCHESTRATION RULES `echo` commands, etc.
  - Drop any entries that reference `plugins/ciel/hooks/` with a stale or relative path.
  - Append the canonical Ciel entry from Step C2.

### Step C4 — Backup and write

1. `cp <file> <file>.bak-$(date +%Y%m%d-%H%M%S)` via Bash.
2. Validate the merged JSON with `jq .` on a temp file before replacing.
3. Move the temp file into place.

### Step C5 — Report and verify (Claude)

Print to the user:
- Detected platform: **Claude**
- Ciel version: **v5**
- `$CIEL_DIR` detected
- Target file edited (hooks block updated or created)
- Backup path
- Summary of what changed (events added, entries renamed/fixed, entries preserved)
- Subagents installed (ciel-researcher, ciel-explorer, ciel-critic, ciel-improver)

Then give the verification steps:
1. Restart Claude Code.
2. In the new session, verify auto memory is working: `/memory` should show enabled.
3. Make a Write or Edit call. The hook should block if no test file exists.
4. Run `claude --agent ciel-researcher "research something"` to test subagents.
5. End the session. The SubagentStop hook should trigger meta-critiquer.

---

## OpenCode branch

### Step O1 — Pick the target config

- Default: `./opencode.json` (project-scope). Create if missing.
- With `--user`: `$HOME/.config/opencode/opencode.json`. Create the parent directory if missing.

If the file exists and does not parse as JSON (`python3 -m json.tool <file> > /dev/null` fails) → stop and ask the user to fix the syntax first. Never overwrite broken JSON.

### Step O2 — Copy the native primitives into `.opencode/`

Create the directory tree under the project root (even if `--user` is passed, the plugin + agents + commands still live project-scope so they can be version-controlled with the code):

```
.opencode/
  plugins/
    ciel.ts          # v5 plugin (16-step pipeline, ASK, map, spike, parking)
  agents/
    ciel.md            # v5 primary orchestrator
    ciel-researcher.md # v5 researcher (version changelog, waterfall)
    ciel-explorer.md   # v5 explorer (LSP, scent-following, git history)
    ciel-critic.md     # v5 critic (5 modes: RELIRE/CRITIQUER/RCA/FEEDBACK/INVESTIGATE)
    ciel-improver.md   # meta-agent
  commands/
    ciel.md
    ciel-init.md
    ciel-improve.md
    ciel-eval.md
    ciel-create-skill.md
    ciel-recommend.md
    ciel-update.md
    ciel-audit.md
```

Also create `.claude/` structure for Claude Code compatibility (if the project uses Claude Code):

```
.claude/
  agents/
    ciel-researcher.md     # with memory: user, model: haiku
    ciel-explorer.md       # with memory: project, isolation: worktree
    ciel-critic.md         # with memory: local, model: opus
    ciel-improver.md
  hooks/
    check-test-first.sh    # test-first gate (exit 2 = block)
    block-destructive.sh   # security gate (blocks rm -rf)
    track-file.sh          # file tracking for RELIRE threshold
    meta-critiquer.sh      # post-task reflection
  settings.json            # hooks config
```

Source every file from `$CIEL_DIR/`. Steps:

1. `mkdir -p ./.opencode/plugins ./.opencode/agents ./.opencode/commands`
2. `cp "$CIEL_DIR/.opencode/plugins/ciel.ts" "./.opencode/plugins/ciel.ts"`
3. `cp "$CIEL_DIR/.opencode/agents/"*.md "./.opencode/agents/"`
4. `cp "$CIEL_DIR/.opencode/commands/"*.md "./.opencode/commands/"`
5. `cp "$CIEL_DIR/CLAUDE.md" "./CLAUDE.md"` (if not exists)
6. `mkdir -p ./.claude/agents ./.claude/hooks`
7. `cp "$CIEL_DIR"/.claude/agents/*.md "./.claude/agents/"`
8. `cp "$CIEL_DIR"/.claude/hooks/*.sh "./.claude/hooks/"`
9. `cp "$CIEL_DIR/.claude/settings.json" "./.claude/settings.json"`
10. `chmod +x ./.claude/hooks/*.sh`

If the source directory does not exist (unbuilt repo), regenerate it first:
```
bash "$CIEL_DIR/scripts/build-platforms.sh" --target=opencode
```

### Step O3 — Ensure `AGENTS.md`

If `./AGENTS.md` does NOT exist, copy `$CIEL_DIR/platforms/opencode/AGENTS.md` to `./AGENTS.md`. If it DOES exist and already contains the string `"Ciel deep-reasoning workflow"`, leave it alone. Otherwise, ask the user: "AGENTS.md already exists and does not mention Ciel — overwrite, append, or skip?".

### Step O4 — Merge `opencode.json`

Use Python (same pattern as `scripts/install.sh` `_install_mcp`). Requirements for the merged output:

- Preserve every top-level key that is already present (`model`, `small_model`, `provider`, `agent`, `mode`, `permission`, `mcp`, `keybinds`, etc.).
- Ensure `"$schema": "https://opencode.ai/config.json"` is present.
- Ensure `"instructions"` is an array containing `"AGENTS.md"`. If an array already exists, add `"AGENTS.md"` only if absent; if a string is present, wrap it into an array.
- Ensure `"plugin"` is an array containing `"./.opencode/plugins/ciel.ts"`. Same merge rule as instructions — do not drop existing entries.
- Everything else: preserved exactly as-is.

Use this Python heredoc (adapt paths to the resolved target):

```bash
python3 - "$TARGET" <<'PY'
import json, os, sys
target = sys.argv[1]
current = {}
if os.path.exists(target):
    with open(target) as f:
        current = json.load(f)

current.setdefault("$schema", "https://opencode.ai/config.json")

# instructions: ensure array containing "AGENTS.md"
ins = current.get("instructions")
if ins is None:
    current["instructions"] = ["AGENTS.md"]
elif isinstance(ins, str):
    current["instructions"] = [ins] if ins == "AGENTS.md" else [ins, "AGENTS.md"]
elif isinstance(ins, list) and "AGENTS.md" not in ins:
    current["instructions"] = ins + ["AGENTS.md"]

# plugin: ensure array containing the local ciel.ts
target_plugin = "./.opencode/plugins/ciel.ts"
plg = current.get("plugin")
if plg is None:
    current["plugin"] = [target_plugin]
elif isinstance(plg, str):
    current["plugin"] = [plg] if plg == target_plugin else [plg, target_plugin]
elif isinstance(plg, list) and target_plugin not in plg:
    current["plugin"] = plg + [target_plugin]

os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
with open(target, "w") as f:
    json.dump(current, f, indent=2)
    f.write("\n")
PY
```

### Step O5 — Backup and write (OpenCode)

Wrap Step O4 with a backup:

1. Before running the Python merge: if the target file exists, `cp "$TARGET" "$TARGET.bak-$(date +%Y%m%d-%H%M%S)"`.
2. After: validate with `python3 -m json.tool < "$TARGET" > /dev/null`. If validation fails (should not happen — Python json.dump is canonical), stop and restore from the backup.

### Step O6 — Report and verify (OpenCode)

Print to the user:
- Detected platform: **OpenCode**
- Ciel version: **v5**
- `$CIEL_DIR` detected
- Target file edited (`opencode.json`)
- Backup path (if one was made)
- Primitives installed: plugin v5, 5 agents (ciel + 4 subagents), 8 commands, `AGENTS.md`, `CLAUDE.md`, `.claude/` agents + hooks
- `.ciel/` directory structure created (map.json, memory.json, parking.md, learnings.md)
- Enable LSP navigation: `OPENCODE_EXPERIMENTAL_LSP_TOOL=true opencode`

Then give the verification steps:
1. Restart `opencode`.
2. Send a message containing "auth" or "password" → depth classification should show `"[CIEL] Depth: Critical"`.
3. Ask the assistant to edit a `.ts` file. The tool result should contain `[CIEL]` or `[CIEL CRITIQUE]` reminder.
4. After 3+ code files, subsequent turns should include `"[CIEL RELIRE REQUIRED]"` until you dispatch `@ciel-critic`.
5. Send an ambiguous request → the agent should use the `question` tool (ASK window).
6. Check `.ciel/map.json` after exploring -- should contain auto-detected modules.
7. For SPIKE mode: create `.ciel/exploration.active` file, gates will be assouplies.

---

## `--check` mode

Do not write. For both branches:
- Claude: `diff <(jq -S . <current>) <(jq -S . <proposed>)` → show the unified diff.
- OpenCode: run the Python merge against a temp file, then `diff <(python3 -m json.tool < <current>) <(python3 -m json.tool < <temp>)` → show the unified diff. Also list the files that *would* be copied under `.opencode/` (without copying them).

Exit without touching the filesystem.

## Guards (both platforms)

- Never `rm` the existing config — always `cp` to `.bak-*` first.
- Never silently drop a user's top-level setting. If merging is ambiguous, stop and ask.
- Never skip JSON validation — a malformed config breaks every future session.
- Do not commit or push these changes — project-level configs are frequently in `.gitignore` and are per-machine.
- Never cross-contaminate: if platform is Claude, do NOT touch `opencode.json`; if platform is OpenCode, do NOT touch `./.claude/settings.json`.
