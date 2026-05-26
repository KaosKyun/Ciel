#!/bin/bash
# Ciel — PreToolUse hook for Agent (subagent type gate)
# Trigger: PreToolUse on Agent
# Purpose: block Agent dispatches that don't use a ciel-* subagent_type.
#   Generic agents bypass Haiku model, call caps, and researcher waterfall
#   → cost 20K-160K tokens vs ~5K for a constrained Ciel agent.
#
# Escape hatch: include [CIEL_GATE_BYPASS] anywhere in the prompt to allow
#   a non-ciel agent through (e.g. legitimate one-off native dispatch).

set -uo pipefail

input_json=$(cat 2>/dev/null || echo "{}")
[ -z "$input_json" ] && exit 0

# Parse subagent_type and prompt head
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

# Allow explicit bypass
if echo "$prompt_head" | grep -q "\[CIEL_GATE_BYPASS\]"; then
    exit 0
fi

# Allow ciel-* subagent types
if [[ "$subagent_type" == ciel-* ]]; then
    # Dispatch marker: a research dispatch satisfies the write/read gate for
    # this session. Project-local + session-scoped (SessionStart clears it),
    # replacing the old /tmp/ciel_dispatched.* scheme that had no writer.
    if [[ "$subagent_type" == "ciel-researcher" || "$subagent_type" == "ciel-explorer" ]]; then
        if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
            mkdir -p "$CLAUDE_PROJECT_DIR/.ciel" 2>/dev/null || true
            date -u +%Y-%m-%dT%H:%M:%SZ > "$CLAUDE_PROJECT_DIR/.ciel/dispatched" 2>/dev/null || true
        fi
    fi
    exit 0
fi

# Block everything else — generic or non-ciel subagent_type
label="${subagent_type:-<missing>}"
python3 -c "
import json
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': '[CIEL AGENT GATE] Blocked: subagent_type=\"${label}\" is not a Ciel agent. Re-dispatch with subagent_type=\"ciel-researcher\" | \"ciel-explorer\" | \"ciel-critic\" | \"ciel-improver\". Generic agents bypass Haiku model, call caps, and researcher waterfall early-exit. Add [CIEL_GATE_BYPASS] to prompt to force-allow a non-Ciel dispatch.'
    }
}))"
exit 0
