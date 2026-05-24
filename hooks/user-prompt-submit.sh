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

# Depth classification is model-driven, not regex-driven.
# Default to Standard — the model reclassifies via depth-classifier skill at DOCS step
# and writes the result to .ciel/last-depth (read by pre-tool-write gate).
# No mechanical keyword detection — regex is too imprecise for AI-driven tasks.
DEPTH="Standard"
REASON="model reclassifies via depth-classifier at DOCS — write to .ciel/last-depth"

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
  if [ "${EDIT_COUNT:-0}" -ge 3 ] 2>/dev/null; then
    # Write META-pending flag — persists across sessions until META completed
    META_FLAG="$PROJECT_DIR/.ciel/meta-pending"
    mkdir -p "$PROJECT_DIR/.ciel" 2>/dev/null || true
    python3 -c "
import json, os, datetime
flag = os.environ.get('META_FLAG', '')
if flag:
    data = {'edits': int(os.environ.get('EDIT_COUNT', '0')), 'since': datetime.datetime.utcnow().isoformat() + 'Z'}
    with open(flag, 'w') as f:
        json.dump(data, f)
" META_FLAG="$META_FLAG" EDIT_COUNT="$EDIT_COUNT" 2>/dev/null || true
    META_GATE=" | META GATE: ${EDIT_COUNT} files edited — previous task MUST complete 10-item META reflection via Skill(meta-critiquer) BEFORE next task. META is NOT optional after 3+ edits. Clear .ciel/meta-pending when done."
  elif [ "${EDIT_COUNT:-0}" -gt 0 ] 2>/dev/null; then
    META_GATE=" | META GATE: ${EDIT_COUNT} file(s) edited — complete 10-item META if previous task ended at PROUVER."
  fi
fi

# ─── Cued-recall: intervention + explicit-save detection ─────────────────────
# Two narrow buckets, BOTH high-precision (POSIX-ERE, no PCRE lookahead):
#  1. Intervention regex — user corrections ("you forgot", "non en fait", …)
#  2. Explicit save-request regex — direct capture asks ("save this to memory", …)
# Bare verbs without an explicit memory noun (e.g. "remember to commit",
# "memorise this") are deliberately NOT triggers — an earlier draft used
# `remember (this|that|it|to)` and fired on every casual "I'll remember to X"
# prompt, polluting the cued-recall corpus. Each save-request branch REQUIRES
# the noun `memory`/`mémoire` OR the unambiguous verb+object pair
# `mémorise <ça/cela/ceci>` / `memorise <this/that/it>`. Anchored to sentence
# boundary so trailing "remember" never fires. See ADR-0001, skill `memoire`,
# and packages/ciel/test/hooks-regex.test.ts.
INTERVENTION_GATE=""
# Bucket 1: corrections / "you missed something" (unchanged from v6.2 — proven precise)
if echo "$PROMPT" | grep -qiE "(tu as oublié|t'as oublié|n'oublie pas (que|de)|non en fait|non,? en fait|attention que|rappelle-toi (que|de)|ici on (fait|utilise) plutôt|non on (fait|utilise) plutôt|en fait c'est pas|c'est pas comme ça|mauvaise approche|tu te trompes|you forgot (to|that)|don't forget (to|that)|that's not (right|correct|how)|that's wrong|no[,]? actually|actually,? no|wait[,—-] (no|don't|you forgot)|stop[,—-] (no|you forgot|don't))"; then
  INTERVENTION_GATE=" | CAPTURE GATE: intervention pattern detected — propose AskUserQuestion to capture as memory under .ciel/memory/episodes/ (skill: memoire). Never silent-write."
fi
# Bucket 2: explicit save requests — every branch requires the memory noun or
# unambiguous mémorise/memorise+object. Anchored to start-of-prompt or
# sentence boundary so "I'll remember the memory of …" never fires.
if [ -z "$INTERVENTION_GATE" ] && echo "$PROMPT" | grep -qiE "(^|[[:space:].!?])(save (this|that|it) (to|in|into) (the )?memory|put (this|that|it) (in|into) (the )?memory|put (it|this|that) in (the )?memory of ciel|garde (ça|cela|ceci) en (mémoire|memoire)|mets (ça|cela|ceci) en (mémoire|memoire)|enregistre (ça|cela|ceci) (en|dans la|à la) (mémoire|memoire)|sauvegarde (ça|cela|ceci) (en|dans la|à la) (mémoire|memoire)|mémorise (ça|cela|ceci)|memorise (this|that|it))"; then
  INTERVENTION_GATE=" | CAPTURE GATE: explicit save request detected — propose AskUserQuestion then capture as memory under .ciel/memory/episodes/ via memory-engine.py (skill: memoire). NEVER write to Claude Code auto-memory (~/.claude/projects/<slug>/memory/MEMORY.md) — that is a DIFFERENT system and invisible to /ciel-audit. Never silent-write."
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

# Persist depth classification for downstream hooks (pre-tool-write gate reads this)
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  echo "$DEPTH" > "$CLAUDE_PROJECT_DIR/.ciel/last-depth" 2>/dev/null || true
fi

# ─── Pipeline state tracker ───────────────────────────────────────────
PIPELINE_STATE=""
if [ -n "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/.ciel/pipeline-state.json" ]; then
  PIPELINE_STATE=$(STATE_FILE="$PROJECT_DIR/.ciel/pipeline-state.json" python3 << 'PYEOF'
import json, os, sys
try:
    with open(os.environ['STATE_FILE']) as f:
        state = json.load(f)
    steps = state.get('steps', {})
    order = ['DOCS','QUOI','ASK','AVEC QUOI','DIVERGE','RECHERCHE','SECURITE','CODEBASE','EVALUER','ASK2','FAIRE','TESTER','ADR','RELIRE','PROUVER','MEMOIRE','COMPILER','META']
    done = [s for s in order if s in steps and steps[s].get('status') == 'done']
    done_count = len(done)
    total = len(order)
    current = state.get('current_step', '')
    # Show last 6 completed + current if pending
    display = done[-6:] if len(done) > 6 else done[:]
    show = [d + '✓' for d in display]
    if current and current not in done:
        show.append(current + '●')
    bar = ' → '.join(show)
    print(f' | PIPELINE: {bar} ({done_count}/{total})')
except Exception:
    pass
PYEOF
)
fi

MSG_BASE="CIEL depth hint: $DEPTH ($REASON).$DISPATCH_GATE$META_GATE$INTERVENTION_GATE$PIPELINE_STATE | SKILLS: load workflow skill via Skill() for current pipeline step (CLAUDE.md column 'Skill a charger'). Never skip. Invoke depth-classifier if ambiguous before routing pipeline."

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
