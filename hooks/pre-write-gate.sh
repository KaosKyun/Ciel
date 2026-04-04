#!/bin/bash
# Ciel — Pre-write gate
# Trigger: PreToolUse Write|Edit
# Injects FLUX checkpoint context before writing code files
# Never blocks (exit 0 always)

INPUT=$(cat)

# Extract file path from tool input
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
if ! echo "$FILE_PATH" | grep -qE '\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte)$'; then
  exit 0
fi

# Critical file patterns
if echo "$FILE_PATH" | grep -qiE '(auth|Auth|security|Security|Route|Service|Controller|Repository|Gateway|Middleware|Proxy|Token|Session|Password|Secret)'; then
  MSG="CIEL [CRITIQUE] ${FILE_PATH} — Avant d'ecrire: (1) SECURITE STRIDE fait? (2) FLUX narre? (3) Dispatch critic apres FAIRE obligatoire."
else
  MSG="CIEL ${FILE_PATH} — FLUX narre pour ce changement? Si Standard/Critical: researcher + explorer dispatche?"
fi

echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"additionalContext\": \"$MSG\"}}"
exit 0
