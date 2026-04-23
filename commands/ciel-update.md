---
description: Update Ciel for the current platform only (Claude, OpenCode, etc.)
---

# ciel-update — Platform-aware update

Update Ciel components for **only the platform that executed this command**.

## Process

### 1. Detect current platform

Check execution context to determine which platform is running:

```bash
# Check if running in Claude Code
if [ -d "$HOME/.claude/plugins/ciel" ]; then
  PLATFORM="claude"
# Check if running in OpenCode  
elif [ -f ".opencode/plugins/ciel.ts" ] || [ -d ".opencode" ]; then
  PLATFORM="opencode"
# Check Cursor
elif [ -d ".cursor" ]; then
  PLATFORM="cursor"
# Check Windsurf
elif [ -d ".windsurf" ]; then
  PLATFORM="windsurf"
else
  echo "Unknown platform, aborting"
  exit 1
fi
```

### 2. Fetch latest version

```bash
REMOTE_VERSION=$(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/VERSION | tr -d '[:space:]')
LOCAL_VERSION=$(cat VERSION 2>/dev/null || echo "unknown")

echo "Current: $LOCAL_VERSION → Latest: $REMOTE_VERSION"
```

### 3. Update platform-specific files

**For Claude Code:**
```bash
PLUGIN_DIR="$HOME/.claude/plugins/ciel"

# Update hooks
for hook in session-start.sh stop.sh pre-tool-write.sh post-tool-write.sh pre-compact.sh; do
  curl -fsSL "https://raw.githubusercontent.com/KaosKyun/Ciel/main/hooks/$hook" -o "$PLUGIN_DIR/$hook"
done

# Update skills
curl -fsSL "https://raw.githubusercontent.com/KaosKyun/Ciel/main/skills/ciel-critic/relire-critic.md" -o "$PLUGIN_DIR/skills/ciel-critic/relire-critic.md"
# ... (other skills)

# Update agents (ciel = merged plan+build)
for agent in ciel ciel-researcher ciel-explorer ciel-critic ciel-improver; do
  curl -fsSL "https://raw.githubusercontent.com/KaosKyun/Ciel/main/agents/${agent}.md" -o "$PLUGIN_DIR/agents/${agent}.md"
done

# Update commands
for cmd in ciel-init ciel-update ciel-refresh ciel-improve ciel-eval ciel-create-skill ciel-recommend ciel-audit; do
  curl -fsSL "https://raw.githubusercontent.com/KaosKyun/Ciel/main/commands/${cmd}.md" -o "$PLUGIN_DIR/commands/${cmd}.md"
done
```

**For OpenCode:**
```bash
OPENDIR=".opencode"

# Update plugin
curl -fsSL "https://raw.githubusercontent.com/KaosKyun/Ciel/main/.opencode/plugins/ciel.ts" -o "$OPENDIR/plugins/ciel.ts"

# Update agents, commands, skills similarly...
```

### 4. Verify and report

```bash
echo "✓ Updated to version $REMOTE_VERSION for $PLATFORM"
echo ""
echo "Restart your AI assistant to apply changes."
```

## Important rules

1. **Platform isolation**: Only update files for the executing platform
2. **No cross-platform updates**: Claude command ≠ OpenCode update
3. **Preserve config**: Don't overwrite settings.json or opencode.json
4. **Atomic updates**: Download to temp, then move (avoid partial installs)

## Error handling

- Network error → exit with message "Update failed: network issue"
- Permission error → exit with message "Update failed: permission denied"
- Unknown platform → exit with message "Update failed: unknown platform"
