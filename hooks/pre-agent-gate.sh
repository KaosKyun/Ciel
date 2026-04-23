#!/bin/bash
# Ciel — PreToolUse hook for Agent (subagent type gate)
# Purpose: block Agent dispatches that don't use a ciel-* subagent_type.
# Escape hatch: include [CIEL_GATE_BYPASS] anywhere in the prompt to allow through.

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
    tool_input = d.get('tool_input', {})
    subagent_type = tool_input.get('subagent_type', '')
    prompt = tool_input.get('prompt', '')
    print(subagent_type + '\t' + prompt[:200])
except Exception:
    print('\t')
" 2>/dev/null)

subagent_type="${parsed%%$'\t'*}"
prompt_head="${parsed#*$'\t'}"

if echo "$prompt_head" | grep -q "\[CIEL_GATE_BYPASS\]"; then
    exit 0
fi

if [[ "$subagent_type" == ciel-* ]]; then
    exit 0
fi

label="${subagent_type:-<missing>}"
python3 -c "
import json
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': '[CIEL AGENT GATE] Blocked: subagent_type=\"${label}\" is not a Ciel agent. Re-dispatch with subagent_type=\"ciel-researcher\" | \"ciel-explorer\" | \"ciel-critic\" | \"ciel-improver\". Add [CIEL_GATE_BYPASS] to prompt to force-allow.'
    }
}))"
exit 0
