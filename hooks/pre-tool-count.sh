#!/bin/bash
# Ciel — PreToolUse hook for Bash|Read|Grep|Glob (dispatch-gate counter)
# Trigger: PreToolUse on Bash|Read|Grep|Glob
# Purpose: surface the inline-call count via systemMessage so the model
#          knows when to dispatch Task(). Advisory only — no hard-block.
#          Hard deny was removed (v3.2.0): reset mechanism proved too fragile
#          (Agent tool_name varies by platform/session), causing permanent
#          deadlocks. Discipline is enforced by SKILL.md instruction, not gate.
#
# Per-session counter stored at /tmp/ciel-counter-${session_id}.

set -euo pipefail

input_json=""
if [ ! -t 0 ]; then
    input_json=$(cat)
fi
[ -z "$input_json" ] && exit 0

session_id=$(echo "$input_json" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('session_id', ''))
except Exception:
    print('')
" 2>/dev/null)

[ -z "$session_id" ] && exit 0

counter_file="/tmp/ciel-counter-${session_id}"
count=0
if [ -f "$counter_file" ]; then
    count=$(cat "$counter_file" 2>/dev/null || echo 0)
fi

case "$count" in ''|*[!0-9]*) count=0 ;; esac

next=$((count + 1))

if [ "$next" -ge 15 ]; then
    python3 -c "
import json
print(json.dumps({
    'systemMessage': '[CIEL COUNTER: $next] ⚠ inline calls high — dispatch Task(subagent_type=\"ciel-explorer\"|\"ciel-researcher\"|\"ciel-critic\") now if still investigating. Mechanical work (commit, tag, build) is exempt.'
}))"
else
    python3 -c "
import json
print(json.dumps({
    'systemMessage': '[CIEL COUNTER: $next/15] inline Bash/Read/Grep/Glob call — dispatch Task() when input-gathering is complete.'
}))"
fi

exit 0
