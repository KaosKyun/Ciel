#!/bin/bash
# CIEL META-CRITIQUER: post-task reflection triggered on SubagentStop
# Records learnings and updates state

MEMO_DIR="$CLAUD_PROJECT_DIR/.ciel"
mkdir -p "$MEMO_DIR"

# Check if RELIRE is required
if [ -f "$MEMO_DIR/relire-required" ]; then
  REASON=$(cat "$MEMO_DIR/relire-required")
  echo "[CIEL META] RELIRE required ($REASON). Dispatch @ciel-critic MODE=RELIRE" >&2
  rm -f "$MEMO_DIR/relire-required"
fi

# Log subagent completion
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "- [$TIMESTAMP] Subagent completed: $(echo "$SUBAGENT_TYPE" | jq -R .)" >> "$MEMO_DIR/subagent-log.md"

exit 0
