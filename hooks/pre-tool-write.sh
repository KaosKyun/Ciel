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

# Read session edit count for RELIRE gate
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
COUNT=0
if [ -n "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/.ciel/tracked-files.json" ]; then
  COUNT=$(CIEL_PATH="$PROJECT_DIR/.ciel/tracked-files.json" python3 -c "
import json, os
try: print(len(json.load(open(os.environ['CIEL_PATH']))))
except: print(0)
" 2>/dev/null || echo "0")
fi

RELIRE_WARN=""
if [ "${COUNT:-0}" -ge 2 ] 2>/dev/null; then
  RELIRE_WARN=" | RELIRE GATE: ${COUNT} file(s) edited this session — dispatch ciel-critic MODE=RELIRE before declaring done."
fi

# Skip non-code files (docs, config) but still inject RELIRE gate when needed
if ! echo "$FILE_PATH" | grep -qE '\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql|sh|json|yaml|yml|toml)$'; then
  if [ -n "$RELIRE_WARN" ]; then
    echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"additionalContext\": \"CIEL${RELIRE_WARN}\"}}"
  fi
  exit 0
fi

# Critical file patterns
CRITICAL=false
if echo "$FILE_PATH" | grep -qiE '(auth|Auth|security|Security|Route|Service|Controller|Repository|Gateway|Middleware|Proxy|Token|Session|Password|Secret)'; then
  CRITICAL=true
fi

if $CRITICAL; then
  MSG="CIEL [CRITIQUE] ${FILE_PATH} — Avant d'ecrire: (1) Invoke faire-gatekeeper skill for gate checks (2) stride-analyzer must have run for Critical tasks (3) flux-narrator completed (4) test written BEFORE (RED). Dispatch critic agent MODE=RELIRE after FAIRE is mandatory.${RELIRE_WARN}"
else
  MSG="CIEL ${FILE_PATH} — Invoke faire-gatekeeper skill for FAIRE gates (alternatives, idiomatic, quality, removal, test-first, chunked validation). If Standard/Critical: ensure researcher + explorer agents dispatched.${RELIRE_WARN}"
fi

# Serialize via python3 to safely handle $FILE_PATH with quotes/backslashes/newlines
# PreToolUse supports additionalContext since Claude Code v2.1.9 (changelog confirmed)
python3 -c "
import json, sys
msg = sys.argv[1]
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': msg}}))
" "$MSG"
exit 0
