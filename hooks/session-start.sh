#!/bin/bash
# Ciel — SessionStart hook
# Trigger: session begins or resumes
# Purpose: print Ciel banner, load overlay context, set TRACE_ID for eval logging
# Never blocks (exit 0 always). Stdout is added to Claude's context.

INPUT=$(cat 2>/dev/null || echo "{}")
CWD=$(echo "$INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('cwd', ''))" 2>/dev/null || pwd)

# Detect overlay presence
OVERLAY=""
for candidate in "$CWD/ciel-overlay.md" "$CWD/.claude/ciel-overlay.md"; do
  if [[ -f "$candidate" ]]; then
    OVERLAY="$candidate"
    break
  fi
done

# Generate TRACE_ID for this session (used by eval logging)
TRACE_ID=$(date -u +%Y%m%dT%H%M%SZ)-$$
export CIEL_TRACE_ID="$TRACE_ID"

MSG="CIEL v2.0.0 — Skills-first deep-reasoning active. "
if [[ -n "$OVERLAY" ]]; then
  MSG+="Overlay loaded: $OVERLAY. "
else
  MSG+="No overlay found at $CWD/ciel-overlay.md — create one for project-specific rules. "
fi
MSG+="Trace ID: $TRACE_ID. Principle: Understand before generating. Verify before claiming done."

echo "$MSG"
exit 0
