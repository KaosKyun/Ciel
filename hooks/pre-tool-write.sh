#!/bin/bash
# Ciel — PreToolUse hook for Write/Edit
# Trigger: PreToolUse on Write|Edit
# Purpose: inject faire-gatekeeper reminder before any code write
# Critical files get additional stride-analyzer hint
# Never blocks (exit 0 always)

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    tip = d.get('tool_input', {})
    print(tip.get('file_path', tip.get('path', '')))
except:
    print('')
" 2>/dev/null || echo "")

[ -z "$FILE_PATH" ] && exit 0

# Skip non-code files (docs, config, etc.)
if ! echo "$FILE_PATH" | grep -qE '\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql)$'; then
  exit 0
fi

# Critical file patterns
CRITICAL=false
if echo "$FILE_PATH" | grep -qiE '(auth|Auth|security|Security|Route|Service|Controller|Repository|Gateway|Middleware|Proxy|Token|Session|Password|Secret)'; then
  CRITICAL=true
fi

if $CRITICAL; then
  MSG="CIEL [CRITIQUE] ${FILE_PATH} — Avant d'ecrire: (1) Invoke faire-gatekeeper skill for gate checks (2) stride-analyzer must have run for Critical tasks (3) flux-narrator completed (4) test written BEFORE (RED). Dispatch critic agent MODE=RELIRE after FAIRE is mandatory."
else
  MSG="CIEL ${FILE_PATH} — Invoke faire-gatekeeper skill for FAIRE gates (alternatives, idiomatic, quality, removal, test-first, chunked validation). If Standard/Critical: ensure researcher + explorer agents dispatched."
fi

# PreToolUse hookSpecificOutput only accepts permissionDecision fields, not
# additionalContext. Forcing permissionDecision="allow" would bypass the
# user's default permission mode (security regression for ask-mode users), so
# we surface the reminder via top-level systemMessage — valid on every event,
# non-modifying to permissions.
python3 -c "
import json, sys
print(json.dumps({'systemMessage': sys.argv[1]}))
" "$MSG"
exit 0
