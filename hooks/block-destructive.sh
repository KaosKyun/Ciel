#!/bin/bash
# CIEL SECURITY GATE: block destructive bash commands
# exit 2 = block, exit 0 = allow

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

if echo "$COMMAND" | grep -qiE 'rm\s+(-rf|--recursive|/-f)'; then
  echo "[CIEL SECURITY] Destructive command blocked: rm -rf" >&2
  exit 2
fi

if echo "$COMMAND" | grep -qiE '(force push|git push --force)'; then
  echo "[CIEL SECURITY] Force push blocked -- use force-with-lease instead" >&2
  exit 2
fi

exit 0
