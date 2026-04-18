---
description: Checks GitHub for a newer Ciel release and re-installs via install.sh or install.ps1. Auto-detects platform (Bash vs PowerShell) and uses the appropriate script. Preserves .mcp.json, ciel-overlay.md, opencode.json, and .claude/settings.json.
---

# /ciel-update — Update Ciel to the latest version

Checks GitHub for a newer release and re-installs if available. Works on every platform Ciel supports (Claude Code, Cursor, Windsurf, Codex, OpenCode, Kilo, Ollama, LM Studio).

## How it works

1. Compares your local manifest version (`~/.ciel/manifest.json`) with `VERSION` on the main branch.
2. If newer, runs `install.sh --uninstall -y` or `install.ps1 --uninstall` to remove tracked files.
3. Re-fetches the latest installer from GitHub and runs it with `-y`, which detects installed platforms and re-installs each one.
4. Whitelisted files are preserved across the uninstall+reinstall (they are never deleted, and re-install merges non-destructively into them).

## Run

**Auto-detect (recommended)** — works on Linux, macOS, Windows (WSL/native PowerShell):

```bash
# Bash (Linux/macOS/WSL)
bash scripts/install.sh --check-update    # check only
bash scripts/install.sh --update          # apply update

# PowerShell (Windows native)
pwsh scripts/install.ps1 --check-update   # check only
pwsh scripts/install.ps1 --update         # apply update
```

**Network one-liner (works from any directory)**:

```bash
# Bash
bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh) --check-update
bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh) --update

# PowerShell
irm https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.ps1 | iex -- --check-update
irm https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.ps1 | iex -- --update
```

**Claude Code plugin path** (if installed via `claude plugin install`):

```bash
# Bash
bash ~/.claude/plugins/ciel/scripts/install.sh --check-update
bash ~/.claude/plugins/ciel/scripts/install.sh --update

# PowerShell
pwsh ~/.claude/plugins/ciel/scripts/install.ps1 --check-update
pwsh ~/.claude/plugins/ciel/scripts/install.ps1 --update
```

## Which script to use?

| Your system | Use this script |
|-------------|-----------------|
| Linux / macOS | `bash scripts/install.sh` |
| Windows (WSL) | `bash scripts/install.sh` (from WSL terminal) |
| Windows (PowerShell) | `pwsh scripts/install.ps1` |
| Windows (CMD) | Not supported — use PowerShell or WSL |

Both scripts have **identical functionality** and preserve the same files. Pick the one that matches your shell.

## What's preserved (whitelisted across uninstall+reinstall)

- `.mcp.json` and `.mcp.json.backup-*` — project MCP servers + backups
- `ciel-overlay.md` — project-specific Ciel rules you wrote
- `opencode.json` and `opencode.json.bak-*` — your OpenCode config (model, provider, mcp, permission, keybinds, custom agents). Re-install merges the Ciel `plugin` + `instructions` entries **non-destructively** via Python so you don't lose customizations.
- `.claude/settings.json` and `.claude/settings.json.bak-*` — project-scope Claude config (contains absolute `$CIEL_DIR` hook paths, per-machine; created by `/ciel-init`)

## What's replaced

- All skills (`~/.claude/skills/<name>/`) — the full Ciel library re-copied
- Agents (`~/.claude/agents/{researcher,explorer,critic,improver}.md`)
- Commands (`~/.claude/commands/ciel*.md`)
- Plugin hooks (`~/.claude/plugins/ciel/hooks/*`)
- Platform-specific artifacts under `./.cursor/`, `./.windsurf/`, `./.opencode/{plugins,agents,commands}/`, `./.kilocode/`, `./.kilo/agents/`, etc. — only Ciel's files inside those directories.

## OpenCode specifics

The update touches:

- `./.opencode/plugins/ciel.ts` — replaced with the fresh v{NEW} TS plugin.
- `./.opencode/agents/ciel-*.md` — 4 subagents replaced.
- `./.opencode/commands/ciel*.md` — all 9 Ciel commands replaced (including the 2 OpenCode-only thin wrappers for `/ciel` and `/ciel-improve`).
- `./AGENTS.md` — replaced **only if** it contained `"Ciel deep-reasoning workflow"` (your custom AGENTS.md is left alone).
- `./opencode.json` — merged non-destructively. The `plugin` array gets the Ciel entry added if missing; the `instructions` array gets `AGENTS.md` added if missing; every other top-level key (model, provider, mcp, keybinds, permission, agent, mode) is preserved exactly as you had it. A `.bak-<timestamp>` backup is always written first.

## Auto-notification

The `SessionStart` hook (Claude Code) or TS plugin `session.created` event (OpenCode) checks for updates once per 24 hours and surfaces a `[UPDATE]` banner if a newer version exists. No network call happens on subsequent sessions within the window.

## Frequency

Run at the start of a project or when you see the `[UPDATE]` banner. `CHANGELOG.md` in the repo describes each release.

## Troubleshooting

- **"No manifest — cannot --update"**: You installed Ciel before v2.1.0. Run a fresh install once to create the manifest, then `--update` will work.
- **"Could not fetch remote VERSION"**: network to GitHub blocked. Workarounds: (a) run from a box with network, pull the repo manually; (b) set a proxy with `https_proxy=...` before running.
- **"Local ahead of remote"**: you're on a dev build (e.g., you committed locally but haven't pushed, or the CDN is stale). The installer refuses to "downgrade" — no-op.
- **OpenCode reports `plugin not found` after update**: restart `opencode`. The TS plugin is loaded at session start; a running session won't pick up the new file until reload.
- **PowerShell execution policy blocked**: run `Set-ExecutionPolicy -Scope Process Bypass` before running the script, or use `pwsh -ExecutionPolicy Bypass -File scripts/install.ps1`.
