#!/bin/bash
# Ciel — PreToolUse hook for Bash|Read|Grep|Glob (dispatch-gate counter)
# Trigger: PreToolUse on Bash|Read|Grep|Glob
# Purpose: mechanically enforce the 5-inline-call dispatch gate from
#          skills/ciel/SKILL.md. Under budget → surface counter via
#          systemMessage (visibility). At budget → deny via
#          permissionDecision (the only schema-valid hard-block on
#          PreToolUse — verified against @opencode-ai/plugin .d.ts
#          + Anthropic hook docs).
#
# Per-session counter stored at /tmp/ciel-counter-${session_id}. Missing
# file = 0 (implicit reset on new session). The sibling post-tool-count.sh
# increments this file on every matched tool, and resets it to 0 on Task
# dispatch (so a fork dispatch refills the budget for the main session to
# process the fork's report).

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

# Sanity: treat non-numeric as 0
case "$count" in ''|*[!0-9]*) count=0 ;; esac

if [ "$count" -ge 15 ]; then
    # Hard-block the 16th+ inline tool call. The model will see the reason.
    python3 -c "
import json
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': '[CIEL HARD-STOP] Dispatch gate exceeded ($count inline calls without a Task() on a Standard+ task). Emit Task(subagent_type=\"ciel-researcher\"|\"ciel-explorer\"|\"ciel-critic\") now with [ASSUMED] markers for unresolved inputs. Further investigation belongs INSIDE the fork, not in the main session. This is the mechanical enforcement of skills/ciel/SKILL.md dispatch-gate. To opt out for a genuine inline task (Trivial depth), dispatch a no-op Task() first to reset the counter, or delete /tmp/ciel-counter-$session_id.'
    }
}))"
    exit 0
fi

# Under budget — inject counter so the model sees the running total
next=$((count + 1))
python3 -c "
import json
print(json.dumps({
    'systemMessage': f'[CIEL COUNTER: $next/15] inline Bash/Read/Grep/Glob call — on 15/15 the next non-Task tool call will be hard-stopped. Dispatch Task() now if input-gathering is complete.'
}))"
exit 0
