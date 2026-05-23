#!/bin/bash
# CIEL META-CRITIQUER: post-task reflection triggered on SubagentStop
# Records learnings and updates state

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MEMO_DIR="$PROJECT_DIR/.ciel"
mkdir -p "$MEMO_DIR" 2>/dev/null || true

# Check if RELIRE is required
if [ -f "$MEMO_DIR/relire-required" ]; then
  REASON=$(cat "$MEMO_DIR/relire-required")
  echo "[CIEL META] RELIRE required ($REASON). Dispatch @ciel-critic MODE=RELIRE" >&2
  rm -f "$MEMO_DIR/relire-required"
fi

# Log subagent completion — parse agent type from stdin JSON.
# $SUBAGENT_TYPE env var is not injected by Claude Code; stdin is the correct source.
INPUT=$(cat 2>/dev/null || echo "{}")
AGENT_TYPE=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('subagent_type', d.get('agent_type', 'unknown')))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "- [$TIMESTAMP] Subagent completed: \"$AGENT_TYPE\"" >> "$MEMO_DIR/subagent-log.md"

exit 0
