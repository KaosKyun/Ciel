#!/bin/bash
# Ciel — Skills & Hooks sync
# Single source of truth: .claude/skills/ + hooks/
# Syncs to: .claude/hooks/ (Claude Code runtime) + packages/ciel/assets/skills/ (distribution)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Ciel sync-skills ==="

# --- 1. Sync hooks -> .claude/hooks/ ---
echo "Syncing hooks/ -> .claude/hooks/"
mkdir -p "$PROJECT_DIR/.claude/hooks"
for f in "$PROJECT_DIR"/hooks/*.sh "$PROJECT_DIR"/hooks/*.py; do
  [ -f "$f" ] || continue
  cp "$f" "$PROJECT_DIR/.claude/hooks/$(basename "$f")"
done
echo "  Hooks synced: $(ls "$PROJECT_DIR/hooks/" | wc -l | tr -d ' ') files"

# --- 2. Sync skills -> packages/ciel/assets/skills/ ---
if [ -d "$PROJECT_DIR/.claude/skills" ]; then
  echo "Syncing .claude/skills/ -> packages/ciel/assets/skills/"
  mkdir -p "$PROJECT_DIR/packages/ciel/assets/skills"
  rsync -av --delete --exclude='.legacy' "$PROJECT_DIR/.claude/skills/" "$PROJECT_DIR/packages/ciel/assets/skills/" 2>&1 | tail -1
fi

# --- 3. Report ---
SKILL_COUNT=$(find "$PROJECT_DIR/.claude/skills" -maxdepth 2 -name "SKILL.md" -not -path "*/.legacy/*" 2>/dev/null | wc -l | tr -d ' ')
echo "  Skills: $SKILL_COUNT"
echo "=== Sync complete ==="
