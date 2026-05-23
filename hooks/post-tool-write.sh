#!/bin/bash
# Ciel — PostToolUse hook for Write/Edit
# Trigger: PostToolUse on Write|Edit
# Purpose: inject relire-critic dispatch instruction after code write
# Never blocks (exit 0 always)

INPUT=$(cat 2>/dev/null || echo "{}")

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

# Skip non-code files
if ! echo "$FILE_PATH" | grep -qE '\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql)$'; then
  exit 0
fi

# JSON-escape the file path (backslash and double-quote are the dangerous chars)
ESCAPED_PATH=$(echo "$FILE_PATH" | sed 's/\\/\\\\/g; s/"/\\"/g')

MSG="CIEL RELIRE OBLIGATOIRE — ${ESCAPED_PATH} vient d'etre ecrit. Invoke relire-critic skill now (inline for Trivial, or dispatch critic agent MODE=RELIRE for Standard/Critical with 3+ files). Required: 4 RISQUES (functional + imports + data assumptions + domain skill conformity) + FIX/ACCEPT/DEFER + 8-item checklist. Ne pas continuer avant le verdict."

echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PostToolUse\", \"additionalContext\": \"$MSG\"}}"
exit 0
