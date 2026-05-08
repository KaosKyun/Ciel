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

# ─── Cued-recall: intervention pattern detection ─────────────────────────────
# When the user message contains a clear correction/intervention pattern,
# suggest capturing it as a memory. Patterns are intentionally narrow to keep
# false-positive rate low — generic words like "wait" / "stop" / "actually"
# are NOT triggers on their own; they must combine with a negation/correction
# adjacent. Never auto-silent — the model surfaces a question to the user.
# See ADR-0001 and skill `memoire`.
INTERVENTION_GATE=""
# POSIX-ERE only (no PCRE lookahead). Patterns are intentionally high-precision
# to avoid false positives on generic words (wait/stop/actually). Each pattern
# is a clear signal of correction or "you missed something".
if echo "$PROMPT" | grep -qiE "(tu as oublié|t'as oublié|n'oublie pas (que|de)|non en fait|non,? en fait|attention que|rappelle-toi (que|de)|ici on (fait|utilise) plutôt|non on (fait|utilise) plutôt|en fait c'est pas|c'est pas comme ça|mauvaise approche|tu te trompes|you forgot (to|that)|don't forget (to|that)|that's not (right|correct|how)|that's wrong|no[,]? actually|actually,? no|wait[,—-] (no|don't|you forgot)|stop[,—-] (no|you forgot|don't))"; then
  INTERVENTION_GATE=" | CAPTURE GATE: intervention pattern detected — propose AskUserQuestion to capture as memory under .ciel/memory/episodes/ (skill: memoire). Never silent-write."
fi

# ─── Cued-recall: query memory engine for matching memories ──────────────────
# Calls hooks/memory-engine.py if installed and a memory corpus exists. The
# engine handles cue extraction (paths, symbols, intents, language), scoring,
# token cap, decay, and trigger updates. See docs/adrs/0001-cued-recall-memory.md.
MEMORY_OUTPUT=""
ENGINE_PATH=""
# Resolution order: same dir as this script (most reliable, found via BASH_SOURCE)
# → project-relative paths in priority order → $HOME fallbacks. Covers local-mode
# install (top-level hooks/), curl-mode install (.claude/hooks/ or ~/.claude/plugins/ciel/),
# and OpenCode plugin layout (~/.config/opencode/...).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || echo "")"
for candidate in \
    "$SCRIPT_DIR/memory-engine.py" \
    "$PROJECT_DIR/.claude/hooks/memory-engine.py" \
    "$PROJECT_DIR/hooks/memory-engine.py" \
    "$HOME/.claude/plugins/ciel/memory-engine.py" \
    "$HOME/.ciel/hooks/memory-engine.py"; do
  if [[ -n "$candidate" ]] && [[ -f "$candidate" ]]; then
    ENGINE_PATH="$candidate"
    break
  fi
done

if [[ -n "$ENGINE_PATH" ]] && [[ -n "$PROJECT_DIR" ]] && [[ -f "$PROJECT_DIR/.ciel/memory/index.json" ]]; then
  DEPTH_LOWER=$(echo "$DEPTH" | tr '[:upper:]' '[:lower:]')
  MEMORY_OUTPUT=$(python3 "$ENGINE_PATH" query --prompt "$PROMPT" --cwd "$PROJECT_DIR" --depth "$DEPTH_LOWER" 2>/dev/null || echo "")
fi

MSG_BASE="CIEL depth hint: $DEPTH ($REASON).$DISPATCH_GATE$META_GATE$INTERVENTION_GATE Invoke depth-classifier if ambiguous before routing pipeline."

# Emit JSON via python to handle newlines and quoting safely
MSG_BASE="$MSG_BASE" MEMORY_OUTPUT="$MEMORY_OUTPUT" python3 -c "
import os, json
base = os.environ.get('MSG_BASE', '')
mem = os.environ.get('MEMORY_OUTPUT', '').strip()
combined = base + ('\n\n' + mem if mem else '')
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'UserPromptSubmit',
        'additionalContext': combined,
    }
}))
"
exit 0
