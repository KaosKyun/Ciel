#!/bin/bash
# Ciel — PostToolUse hook for Bash|Read|Grep|Glob|Task|Agent (counter maintenance)
# Trigger: PostToolUse on Bash|Read|Grep|Glob|Task|Agent
# Purpose: sibling to pre-tool-count.sh.
#   - On Bash/Read/Grep/Glob → increment counter (the call that just
#     succeeded counts against the budget).
#   - On Task or Agent → reset counter to 0 (dispatch happened; the main
#     session earned a fresh budget to process the fork's report).
#     NOTE: Claude Code uses "Agent" as tool_name; OpenCode uses "Task".
#     Both are handled here.
#
# Never blocks. Writes only to /tmp/ciel-counter-${session_id}.

set -euo pipefail

input_json=""
if [ ! -t 0 ]; then
    input_json=$(cat)
fi
[ -z "$input_json" ] && exit 0

parsed=$(echo "$input_json" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('session_id', '') + '\t' + d.get('tool_name', ''))
except Exception:
    print('\t')
" 2>/dev/null)

session_id="${parsed%%$'\t'*}"
tool_name="${parsed#*$'\t'}"

[ -z "$session_id" ] && exit 0

counter_file="/tmp/ciel-counter-${session_id}"

if [ "$tool_name" = "Task" ] || [ "$tool_name" = "Agent" ]; then
    # Dispatch happened — budget refreshes for the main session's
    # post-dispatch processing of the fork's report.
    rm -f "$counter_file"
    exit 0
fi

# Any other matched tool (Bash|Read|Grep|Glob) — increment.
count=0
if [ -f "$counter_file" ]; then
    count=$(cat "$counter_file" 2>/dev/null || echo 0)
fi
case "$count" in ''|*[!0-9]*) count=0 ;; esac
echo $((count + 1)) > "$counter_file"
exit 0
