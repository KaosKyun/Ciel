---
description: Check for Ciel updates and install if available. Compares local manifest version with GitHub main branch. Preserves all custom configs.
---

# /ciel-update — Update Ciel to Latest Version

**Purpose:** Safely update Ciel while preserving your customizations.

**Usage:** `/ciel-update [--check-only] [--force]`

- `--check-only` — Only check, don't install
- `--force` — Install even if versions match (reinstall)

---

## Instructions

Deterministic update operation. NO agent dispatch.

### Step 1: Read Local Version

Check in order:
1. `~/.ciel/manifest.json` → `"version"` field
2. `$CIEL_DIR/VERSION` file
3. Fallback: "unknown"

### Step 2: Fetch Remote Version

```bash
curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/VERSION
```

If fails → Network error, tell user to check connection.

### Step 3: Compare Versions

Semver comparison (MAJOR.MINOR.PATCH):
- Parse each component as integer
- Compare left-to-right
- Return: -1 (update available), 0 (same), 1 (local newer)

**Decision table:**

| Local vs Remote | Action |
|-----------------|--------|
| -1 (local < remote) | Update available |
| 0 (equal) | Already up to date |
| 1 (local > remote) | Development version |

### Step 4: Pre-Update Checks

Before updating:

1. **Backup manifest:** `cp ~/.ciel/manifest.json ~/.ciel/manifest.json.bak-TIMESTAMP`
2. **Check running sessions:** Warn if Claude Code/OpenCode is running
3. **Verify disk space:** Need ~10MB for new version

### Step 5: Uninstall Old Version

Run uninstall for each platform:

**Claude Code:**
```bash
rm -rf ~/.claude/plugins/ciel
# Project settings preserved
```

**OpenCode:**
```bash
rm .opencode/plugins/ciel.ts
rm -rf .opencode/agents/ciel-*
rm -rf .opencode/commands/ciel-*
# opencode.json preserved (restored from backup)
```

**Other platforms:**
- Remove platform-specific Ciel files
- Preserve user configs

### Step 6: Install New Version

**Option A: Git clone (recommended)**
```bash
TEMP_DIR=$(mktemp -d)
git clone --depth=1 https://github.com/KaosKyun/Ciel.git "$TEMP_DIR"
bash "$TEMP_DIR/scripts/install.sh" -y
rm -rf "$TEMP_DIR"
```

**Option B: Download script**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh) -y
```

### Step 7: Post-Update Verification

1. **Check version:** `cat ~/.ciel/manifest.json | grep version`
2. **Verify hooks:** `ls ~/.claude/plugins/ciel/hooks/*.sh | wc -l` (should be 8)
3. **Test plugin:** Restart platform, check for depth hint

### Step 8: Report

```
✓ Update complete

Before: v3.3.0
After:  v3.3.1

Platforms updated:
  ✓ Claude Code
  ✓ OpenCode

Customizations preserved:
  ✓ .mcp.json
  ✓ ciel-overlay.md
  ✓ opencode.json
  ✓ .claude/settings.json

Next steps:
1. Restart your AI coding platform
2. Run /ciel-init to verify hooks
```

---

## Rollback Procedure

If update fails:

```bash
# Restore manifest
cp ~/.ciel/manifest.json.bak-TIMESTAMP ~/.ciel/manifest.json

# Reinstall previous version
git clone --depth=1 --branch v3.3.0 https://github.com/KaosKyun/Ciel.git /tmp/ciel-old
bash /tmp/ciel-old/scripts/install.sh -y
rm -rf /tmp/ciel-old
```

---

## What's Preserved

| File | Action |
|------|--------|
| `~/.ciel/manifest.json` | Backed up, restored |
| `.mcp.json` | Never deleted, merged |
| `ciel-overlay.md` | Never deleted |
| `opencode.json` | Backed up, merged |
| `.claude/settings.json` | Never deleted (project-specific) |
| Custom agents | Preserved |
| Custom commands | Preserved |

---

## What's Replaced

| File | Action |
|------|--------|
| `~/.claude/plugins/ciel/*` | Replaced |
| `~/.claude/skills/*` | Replaced |
| `~/.claude/agents/ciel-*` | Replaced |
| `~/.claude/commands/ciel-*` | Replaced |
| `.opencode/plugins/ciel.ts` | Replaced |
| `.opencode/agents/ciel-*` | Replaced |
| `.opencode/commands/ciel-*` | Replaced |

---

## Examples

```bash
# Check for update
/ciel-update --check-only

# Install update if available
/ciel-update

# Force reinstall (repair)
/ciel-update --force
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "No manifest" | Run fresh install first |
| "Network error" | Check connection, retry |
| "Permission denied" | Run with sudo or fix permissions |
| "Hooks not firing after update" | Run /ciel-init to reconfigure |
| "Version mismatch" | Check git branch, may be on dev version |
