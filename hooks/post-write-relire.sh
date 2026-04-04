#!/bin/bash
# Ciel — Post-write RELIRE injection
# Trigger: PostToolUse Write|Edit
# Forces RELIRE after every code file write
# Never blocks (exit 0 always)

INPUT=$(cat)

# Extract file path
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

MSG="CIEL RELIRE OBLIGATOIRE — ${FILE_PATH} vient d'etre ecrit. Dispatch critic agent maintenant: MODE=RELIRE, CHANGED_FILES=[${FILE_PATH}+autres], QUOI_GOAL=[objectif], IMPLEMENTATION=[resume]. Ne pas continuer avant le verdict."

echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PostToolUse\", \"additionalContext\": \"$MSG\"}}"
exit 0
