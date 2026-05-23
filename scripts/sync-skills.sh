#!/bin/bash
# Ciel — Skills, Rules, Hooks & Agents sync
# Single source of truth: .claude/skills/ + .claude/rules/ + hooks/ + .claude/agents/
# Syncs to: .claude/hooks/ (Claude Code runtime) + packages/ciel/assets/ (distribution)
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
  rsync -av --delete "$PROJECT_DIR/.claude/skills/" "$PROJECT_DIR/packages/ciel/assets/skills/" 2>&1 | tail -1
fi

# --- 3. Sync rules -> packages/ciel/assets/rules/ ---
if [ -d "$PROJECT_DIR/.claude/rules" ]; then
  echo "Syncing .claude/rules/ -> packages/ciel/assets/rules/"
  mkdir -p "$PROJECT_DIR/packages/ciel/assets/rules"
  rsync -av --delete "$PROJECT_DIR/.claude/rules/" "$PROJECT_DIR/packages/ciel/assets/rules/" 2>&1 | tail -1
fi

# --- 4. Sync agents -> packages/ciel/assets/.claude/agents/ ---
if [ -d "$PROJECT_DIR/.claude/agents" ]; then
  echo "Syncing .claude/agents/ -> packages/ciel/assets/.claude/agents/"
  mkdir -p "$PROJECT_DIR/packages/ciel/assets/.claude/agents"
  rsync -av --delete "$PROJECT_DIR/.claude/agents/" "$PROJECT_DIR/packages/ciel/assets/.claude/agents/" 2>&1 | tail -1
fi

# --- 5. Sync .claude/hooks/ -> packages/ciel/assets/.claude/hooks/ ---
if [ -d "$PROJECT_DIR/.claude/hooks" ]; then
  echo "Syncing .claude/hooks/ -> packages/ciel/assets/.claude/hooks/"
  mkdir -p "$PROJECT_DIR/packages/ciel/assets/.claude/hooks"
  rsync -av --delete "$PROJECT_DIR/.claude/hooks/" "$PROJECT_DIR/packages/ciel/assets/.claude/hooks/" 2>&1 | tail -1
fi

# --- 6. Sync .claude/settings.json -> packages/ciel/assets/.claude/settings.json ---
if [ -f "$PROJECT_DIR/.claude/settings.json" ]; then
  echo "Syncing .claude/settings.json -> packages/ciel/assets/.claude/settings.json"
  mkdir -p "$PROJECT_DIR/packages/ciel/assets/.claude"
  cp "$PROJECT_DIR/.claude/settings.json" "$PROJECT_DIR/packages/ciel/assets/.claude/settings.json"
fi

# --- 7. Report ---
SKILL_COUNT=$(find "$PROJECT_DIR/.claude/skills" -maxdepth 2 -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
RULES_COUNT=$(find "$PROJECT_DIR/.claude/rules" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
AGENT_COUNT=$(find "$PROJECT_DIR/.claude/agents" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
echo "  Skills: $SKILL_COUNT, Rules: $RULES_COUNT, Agents: $AGENT_COUNT"
echo "=== Sync complete ==="
