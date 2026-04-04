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

# Store new SHA
echo "$REMOTE_SHA" > "$VERSION_FILE"

echo ""
echo "Ciel updated successfully (SHA: ${REMOTE_SHA:0:8})."
echo "Restart Claude Code to apply changes (/restart or reopen session)."
