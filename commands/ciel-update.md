---
description: Checks GitHub for a newer Ciel release and re-installs via install.sh --update (preserves .mcp.json and ciel-overlay.md).
---

# /ciel-update — Update Ciel to the latest version

Checks GitHub for a newer release and re-installs if available.

## How it works

1. Compares your local manifest version (`~/.ciel/manifest.json`) with `VERSION` on the main branch.
2. If newer, runs `install.sh --uninstall -y` to remove tracked files, then re-installs from latest.
3. Preserves your `.mcp.json` and `ciel-overlay.md` (whitelisted).

## Run

```bash
# Check only (no changes)
bash ~/.claude/plugins/ciel/scripts/install.sh --check-update

# Apply update (uninstall + re-install from latest)
bash ~/.claude/plugins/ciel/scripts/install.sh --update
```

If you installed from a repo clone rather than the global plugin dir, replace the path accordingly:

```bash
bash scripts/install.sh --check-update
bash scripts/install.sh --update
```

## What's preserved

- `.mcp.json` (project MCP config — you may have custom entries)
- `.mcp.json.backup-*` (prior backups)
- `ciel-overlay.md` (project-specific Ciel rules you customized)

## What's replaced

- All skills (`~/.claude/skills/ciel` + category dirs)
- Agents (`~/.claude/agents/{researcher,explorer,critic,improver}.md`)
- Commands (`~/.claude/commands/ciel*.md`)
- Plugin hooks (`~/.claude/plugins/ciel/hooks/*`)
- Platform-specific artifacts (`.opencode/`, `.cursor/`, `.windsurf/`, etc. — only Ciel's files)

## Auto-notification

The `SessionStart` hook checks for updates once per 24 hours and surfaces a `[UPDATE]` banner in the Claude Code session if a newer version exists. No network call happens on subsequent sessions within the window.

## Frequency

Run at the start of a project or when you see the `[UPDATE]` banner. CHANGELOG.md in the repo describes each release.
