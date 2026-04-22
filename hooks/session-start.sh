#!/bin/bash
# Ciel — SessionStart hook
# Trigger: session begins or resumes
# Purpose: print Ciel banner, load overlay context
# Never blocks (exit 0 always)

CWD="${PWD:-$(pwd)}"

# Detect overlay presence
OVERLAY=""
for candidate in "$CWD/ciel-overlay.md" "$CWD/.claude/ciel-overlay.md"; do
  if [[ -f "$candidate" ]]; then
    OVERLAY="$candidate"
    break
  fi
done

# Generate TRACE_ID for this session
TRACE_ID=$(date -u +%Y%m%dT%H%M%SZ)-$$
export CIEL_TRACE_ID="$TRACE_ID"

MSG="CIEL v3.5.0 — Deep-reasoning active. "
if [[ -n "$OVERLAY" ]]; then
  MSG+="Overlay loaded: $OVERLAY. "
else
  MSG+="No overlay found — create ciel-overlay.md for project rules. "
fi
MSG+="Trace ID: $TRACE_ID. Principle: Understand before generating. Verify before claiming done."

echo "$MSG"
exit 0
