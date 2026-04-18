#!/usr/bin/env bash
# Ciel depth-classification hook for Codex CLI (UserPromptSubmit)
# Stdin: JSON { session_id, turn_id, prompt, cwd, hook_event_name, model, transcript_path }
# Stdout: JSON { "additionalContext": "..." }  — injected into the model's context

set -euo pipefail

PAYLOAD=$(cat)
PROMPT=$(printf '%s' "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('prompt',''))" 2>/dev/null || echo "")

CRITICAL_KW='auth|authenti|author|jwt|oauth|password|secret|token|session|payment|credit.card|migration.*schema|2fa|mfa|encryption|credential|cookie.*security'
TRIVIAL_KW='rename|typo|copyright|comment|readme|1-line|one.line|fix.typo|spelling'

if printf '%s' "$PROMPT" | grep -qiE "$CRITICAL_KW"; then
  DEPTH="Critical"
  REASON="auth/security/payment keyword detected"
elif printf '%s' "$PROMPT" | grep -qiE "$TRIVIAL_KW"; then
  DEPTH="Trivial"
  REASON="rename/typo/docs keyword detected"
else
  DEPTH="Standard"
  REASON="default"
fi

HINT="[CIEL] Depth: $DEPTH ($REASON). Route the pipeline accordingly — see AGENTS.md for the 10-step pipeline."
printf '{"additionalContext": "%s"}\n' "$HINT"
