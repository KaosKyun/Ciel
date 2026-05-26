#!/bin/bash

# CIEL-DEFER-GUARD — a global plugin instance no-ops when the project ships AND
# wires its own copy of this hook. Paths are canonicalized (pwd -P) on BOTH sides
# so a symlinked or trailing-slash CLAUDE_PROJECT_DIR cannot make the project's
# own instance wrongly defer (which would disable Ciel entirely in the project).
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  _ciel_name="$(basename "${BASH_SOURCE[0]}")"
  _ciel_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"
  _ciel_proj="$(cd "$CLAUDE_PROJECT_DIR/.claude/hooks" 2>/dev/null && pwd -P)"
  if [ -n "$_ciel_proj" ] && [ -f "$_ciel_proj/$_ciel_name" ] && [ "$_ciel_self" != "$_ciel_proj" ]; then
    exit 0
  fi
fi
# CIEL SECURITY GATE: block destructive bash commands
# exit 2 = block, exit 0 = allow

INPUT=$(cat 2>/dev/null || echo "{}")
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

if echo "$COMMAND" | grep -qiE 'rm\s+(-rf|--recursive|/-f)'; then
  echo "[CIEL SECURITY] Destructive command blocked: rm -rf" >&2
  exit 2
fi

if echo "$COMMAND" | grep -qiE '(force push|git push --force)'; then
  echo "[CIEL SECURITY] Force push blocked -- use force-with-lease instead" >&2
  exit 2
fi

exit 0
