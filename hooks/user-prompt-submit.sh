#!/bin/bash
# Ciel — UserPromptSubmit hook
# Trigger: user submits a prompt (before Claude processes)
# Purpose: light depth pre-classification hint injected into context
# Invokes: depth-classifier skill (lightweight mode)
# Never blocks (exit 0 always)

INPUT=$(cat 2>/dev/null || echo "{}")
PROMPT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('prompt', ''))
except:
    print('')
" 2>/dev/null || echo "")

[ -z "$PROMPT" ] && exit 0

# Mechanical depth signals
DEPTH="Standard"  # default
REASON=""

# Check for Critical signals
if echo "$PROMPT" | grep -qiE '\b(auth|authenti|author|jwt|oauth|password|secret|token|session|payment|credit.card|migration.*schema|2fa|mfa|encryption|credential|cookie.*security)\b'; then
  DEPTH="Critical"
  REASON="auth/security/payment keyword detected"
fi

# Check for Trivial signals (only if not Critical)
if [[ "$DEPTH" != "Critical" ]] && echo "$PROMPT" | grep -qiE '\b(rename|typo|copyright|comment|readme|1-line|one.line|fix.typo|spelling)\b'; then
  DEPTH="Trivial"
  REASON="rename/typo/docs keyword detected"
fi

DISPATCH_GATE=""
if [[ "$DEPTH" == "Standard" || "$DEPTH" == "Critical" ]]; then
  DISPATCH_GATE=" | DISPATCH GATE: dispatch ciel-researcher + ciel-explorer in parallel BEFORE first Bash/Read/Edit."
fi

META_GATE=""
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
if [ -n "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/.ciel/tracked-files.json" ]; then
  EDIT_COUNT=$(CIEL_PATH="$PROJECT_DIR/.ciel/tracked-files.json" python3 -c "
import json, os
try: print(len(json.load(open(os.environ['CIEL_PATH']))))
except: print(0)
" 2>/dev/null || echo "0")
  if [ "${EDIT_COUNT:-0}" -gt 0 ] 2>/dev/null; then
    META_GATE=" | META GATE: ${EDIT_COUNT} file(s) edited this session — complete 10-item META if previous task ended at PROUVER."
  fi
fi

MSG="CIEL depth hint: $DEPTH ($REASON).$DISPATCH_GATE$META_GATE Invoke depth-classifier if ambiguous before routing pipeline."

echo "{\"hookSpecificOutput\": {\"hookEventName\": \"UserPromptSubmit\", \"additionalContext\": \"$MSG\"}}"
exit 0
