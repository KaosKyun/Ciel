#!/bin/bash
# Ciel — UserPromptSubmit hook
# Purpose: light depth pre-classification hint injected into context
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

DEPTH="Standard"
REASON=""

if echo "$PROMPT" | grep -qiE '\b(auth|authenti|author|jwt|oauth|password|secret|token|session|payment|credit.card|migration.*schema|2fa|mfa|encryption|credential|cookie.*security)\b'; then
  DEPTH="Critical"
  REASON="auth/security/payment keyword detected"
fi

if [[ "$DEPTH" != "Critical" ]] && echo "$PROMPT" | grep -qiE '\b(rename|typo|copyright|comment|readme|1-line|one.line|fix.typo|spelling)\b'; then
  DEPTH="Trivial"
  REASON="rename/typo/docs keyword detected"
fi

MSG="CIEL depth hint: $DEPTH ($REASON). Invoke depth-classifier if ambiguous before routing pipeline."

echo "{\"hookSpecificOutput\": {\"hookEventName\": \"UserPromptSubmit\", \"additionalContext\": \"$MSG\"}}"
exit 0
