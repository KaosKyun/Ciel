#!/bin/bash
# Ciel — SubagentStop hook
# Trigger: subagent finishes
# Purpose: log agent report size to eval log; warn if < 200 tokens on Standard/Critical task
# Passive — does not inject context, just logs

INPUT=$(cat 2>/dev/null || echo "{}")

# Extract agent name + result size (rough word count)
AGENT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('agent_type', d.get('subagent_type', 'unknown')))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

RESULT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    result = d.get('result', d.get('output', ''))
    print(len(result.split()) if result else 0)
except:
    print(0)
" 2>/dev/null || echo "0")

# Rough token estimate: 1 word ≈ 1.33 tokens
TOKENS=$((RESULT * 133 / 100))

# Log to evals/results (if CIEL_TRACE_ID set)
if [[ -n "${CIEL_TRACE_ID:-}" ]]; then
  LOG_DIR="$HOME/.claude/plugins/ciel/evals/results"
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  echo "{\"trace_id\":\"$CIEL_TRACE_ID\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"agent\":\"$AGENT\",\"tokens\":$TOKENS}" >> "$LOG_DIR/subagent-stops.jsonl" 2>/dev/null || true
fi

# Warn if truncation suspected
if [[ $TOKENS -lt 200 && $TOKENS -gt 0 ]]; then
  echo "CIEL WARN — $AGENT agent report is only ${TOKENS} tokens. Suspect truncation on Standard/Critical task. Consider re-dispatching with narrower scope." >&2
fi

exit 0
