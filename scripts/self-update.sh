#!/bin/bash
# Ciel — Self-update script
# Compares local SKILL.md SHA with GitHub remote.
# If different → downloads updated files via gh CLI.
# Requires: gh CLI authenticated (gh auth status)
#
# Usage: bash /root/.claude/plugins/ciel/scripts/self-update.sh
# Or via /ciel-update command

set -euo pipefail

REPO="KaosKyun/Ciel"
LOCAL_SKILL="/root/.claude/skills/ciel/SKILL.md"
LOCAL_COMMAND_DIR="/opt/Neiyomi/.claude/commands"
LOCAL_HOOKS_DIR="/root/.claude/plugins/ciel/hooks"
VERSION_FILE="/root/.claude/plugins/ciel/.version"

echo "Ciel update check..."

# Check gh CLI available and authenticated
if ! command -v gh &>/dev/null; then
  echo "ERROR: gh CLI not found. Install: https://cli.github.com"
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "ERROR: gh CLI not authenticated. Run: gh auth login"
  exit 1
fi

# Get remote SHA for SKILL.md
REMOTE_SHA=$(gh api "repos/$REPO/contents/skills/ciel/SKILL.md" --jq '.sha' 2>/dev/null || echo "")
if [ -z "$REMOTE_SHA" ]; then
  echo "Could not reach GitHub (private repo / network). Skipping update."
  exit 0
fi

# Get local SHA (git blob hash format)
LOCAL_SHA=""
if [ -f "$LOCAL_SKILL" ]; then
  LOCAL_SHA=$(git hash-object "$LOCAL_SKILL" 2>/dev/null || echo "")
fi

# Store remote SHA for comparison
STORED_SHA=""
if [ -f "$VERSION_FILE" ]; then
  STORED_SHA=$(cat "$VERSION_FILE")
fi

if [ "$REMOTE_SHA" = "$STORED_SHA" ] && [ -n "$STORED_SHA" ]; then
  echo "Ciel is up to date (SHA: ${REMOTE_SHA:0:8})."
  exit 0
fi

echo "Update available — downloading..."

# Download SKILL.md
gh api "repos/$REPO/contents/skills/ciel/SKILL.md" --jq '.content' \
  | base64 -d > "$LOCAL_SKILL"
echo "  Updated: $LOCAL_SKILL"

# Download ciel.md command
mkdir -p "$LOCAL_COMMAND_DIR"
gh api "repos/$REPO/contents/commands/ciel.md" --jq '.content' \
  | base64 -d > "$LOCAL_COMMAND_DIR/ciel.md"
echo "  Updated: $LOCAL_COMMAND_DIR/ciel.md"

# Download ciel-update command (if exists)
gh api "repos/$REPO/contents/commands/ciel-update.md" --jq '.content' 2>/dev/null \
  | base64 -d > "$LOCAL_COMMAND_DIR/ciel-update.md" 2>/dev/null || true

# Download hooks
gh api "repos/$REPO/contents/hooks/pre-write-gate.sh" --jq '.content' \
  | base64 -d > "$LOCAL_HOOKS_DIR/pre-write-gate.sh"
gh api "repos/$REPO/contents/hooks/post-write-relire.sh" --jq '.content' \
  | base64 -d > "$LOCAL_HOOKS_DIR/post-write-relire.sh"
chmod +x "$LOCAL_HOOKS_DIR/pre-write-gate.sh" "$LOCAL_HOOKS_DIR/post-write-relire.sh"
echo "  Updated: hooks"

# ─── Platform-specific updates (detect from project root) ───────────────────
PROJECT_ROOT="${1:-$(pwd)}"

_dl() {
  local src="$1" dst="$2"
  local content
  content=$(gh api "repos/$REPO/contents/$src" --jq '.content' 2>/dev/null) || return 1
  mkdir -p "$(dirname "$dst")"
  echo "$content" | base64 -d > "$dst"
  echo "  Updated: $dst"
}

# OpenCode agents + commands
if [ -d "$PROJECT_ROOT/.opencode/agents" ]; then
  echo "  Detected OpenCode install — updating agents + commands..."
  _dl "platforms/opencode/.opencode/agents/ciel-researcher.md" "$PROJECT_ROOT/.opencode/agents/ciel-researcher.md"
  _dl "platforms/opencode/.opencode/agents/ciel-explorer.md"   "$PROJECT_ROOT/.opencode/agents/ciel-explorer.md"
  _dl "platforms/opencode/.opencode/agents/ciel-critic.md"     "$PROJECT_ROOT/.opencode/agents/ciel-critic.md"
  _dl "platforms/opencode/AGENTS.md"                           "$PROJECT_ROOT/AGENTS.md"
  mkdir -p "$PROJECT_ROOT/.opencode/commands"
  _dl "platforms/opencode/.opencode/commands/ciel.md"          "$PROJECT_ROOT/.opencode/commands/ciel.md"
  _dl "platforms/opencode/.opencode/commands/ciel-update.md"   "$PROJECT_ROOT/.opencode/commands/ciel-update.md"
  mkdir -p "$PROJECT_ROOT/.opencode/plugins"
  _dl "platforms/opencode/.opencode/plugins/ciel.ts"           "$PROJECT_ROOT/.opencode/plugins/ciel.ts"
fi

# Kilo Code agents + rules
if [ -d "$PROJECT_ROOT/.kilo/agents" ]; then
  echo "  Detected Kilo Code install — updating agents..."
  _dl "platforms/kilocode/.kilo/agents/ciel-researcher.md" "$PROJECT_ROOT/.kilo/agents/ciel-researcher.md"
  _dl "platforms/kilocode/.kilo/agents/ciel-explorer.md"   "$PROJECT_ROOT/.kilo/agents/ciel-explorer.md"
  _dl "platforms/kilocode/.kilo/agents/ciel-critic.md"     "$PROJECT_ROOT/.kilo/agents/ciel-critic.md"
fi
if [ -f "$PROJECT_ROOT/.kilocode/rules/ciel.md" ]; then
  _dl "platforms/kilocode/.kilocode/rules/ciel.md" "$PROJECT_ROOT/.kilocode/rules/ciel.md"
fi

# Windsurf rules + workflows + skills
if [ -f "$PROJECT_ROOT/.windsurf/rules/ciel.md" ]; then
  echo "  Detected Windsurf install — updating rule + workflow + skill..."
  _dl "platforms/windsurf/.windsurf/rules/ciel.md" "$PROJECT_ROOT/.windsurf/rules/ciel.md"
  mkdir -p "$PROJECT_ROOT/.windsurf/workflows"
  _dl "platforms/windsurf/.windsurf/workflows/ciel.md" "$PROJECT_ROOT/.windsurf/workflows/ciel.md"
  mkdir -p "$PROJECT_ROOT/.windsurf/skills/ciel"
  _dl "platforms/windsurf/.windsurf/skills/ciel/SKILL.md" "$PROJECT_ROOT/.windsurf/skills/ciel/SKILL.md"
fi

# Cursor rules
if [ -f "$PROJECT_ROOT/.cursor/rules/ciel.mdc" ]; then
  echo "  Detected Cursor install — updating rule..."
  _dl "platforms/cursor/.cursor/rules/ciel.mdc" "$PROJECT_ROOT/.cursor/rules/ciel.mdc"
fi

# Store new SHA
echo "$REMOTE_SHA" > "$VERSION_FILE"

echo ""
echo "Ciel updated successfully (SHA: ${REMOTE_SHA:0:8})."
echo "Restart your IDE / AI tool to apply changes."
