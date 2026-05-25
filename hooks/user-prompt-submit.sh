#!/bin/bash
# Ciel v9 — UserPromptSubmit hook
# Injects: depth hint + cued-recall memory + intervention detection
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

# Depth classification — default Standard, model reclassifies at DOCS
DEPTH="Standard"

# ─── Cued-recall: query memory engine ──────────────────────────────────
MEMORY_OUTPUT=""
ENGINE_PATH=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || echo "")"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"

for candidate in \
    "$SCRIPT_DIR/memory-engine.py" \
    "$PROJECT_DIR/.claude/hooks/memory-engine.py" \
    "$PROJECT_DIR/hooks/memory-engine.py"; do
  if [[ -n "$candidate" ]] && [[ -f "$candidate" ]]; then
    ENGINE_PATH="$candidate"
    break
  fi
done

if [[ -n "$ENGINE_PATH" ]] && [[ -n "$PROJECT_DIR" ]] && [[ -f "$PROJECT_DIR/.ciel/memory/index.json" ]]; then
  DEPTH_LOWER=$(echo "$DEPTH" | tr '[:upper:]' '[:lower:]')
  MEMORY_OUTPUT=$(python3 "$ENGINE_PATH" query --prompt "$PROMPT" --cwd "$PROJECT_DIR" --depth "$DEPTH_LOWER" 2>/dev/null || echo "")
fi

# ─── Intervention detection ─────────────────────────────────────────────
INTERVENTION_GATE=""
if echo "$PROMPT" | grep -qiE "(tu as oublié|t'as oublié|non en fait|attention que|ici on (fait|utilise) plutôt|tu te trompes|you forgot (to|that)|don't forget|that's not (right|correct|how)|no[,]? actually|wait[,—-] (no|don't|you forgot)|mauvaise approche)"; then
  INTERVENTION_GATE=" | CAPTURE GATE: intervention detected — propose memory capture via memoire skill"
fi

# ─── Persist depth ──────────────────────────────────────────────────────
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  echo "$DEPTH" > "$CLAUDE_PROJECT_DIR/.ciel/last-depth" 2>/dev/null || true
fi

# ─── Phase detection (skill LOADING ORDER) ─────────────────────────────
PHASE=""
if echo "$PROMPT" | grep -qiE "(architecture|design pattern|conception|structur.e?|schema.?archi|trade.?off|decoupage|ddd|monolithe|microservice|flux.*donn.e?|diagram|c4.?model|vision.*technique|plan.*architecture|hld|lld|system.?design|choisir.*techno|compare.*stack|refonte.*archi|audit.*archi|concevoir|designer)"; then
  PHASE="conception"
elif echo "$PROMPT" | grep -qiE "(fix|bug|error|crash|debug|incident|regression|panic|stack.*trace|root.?cause|ne.*marche|pas.*fonctionn)"; then
  PHASE="debug"
elif echo "$PROMPT" | grep -qiE "(implement|code|write|creer|creat|setup|configure|deploy|migrat|refactor|feature|function|method|class|route|endpoint|service|ajout|add.*route)"; then
  PHASE="implementation"
fi

# ─── Phase-aware skill loading instruction ─────────────────────────────
	if [ "$PHASE" = "conception" ]; then
	  SKILL_MSG="Phase CONCEPTION. Tu DOIS appeler Skill() pour system-design, architecture, high-availability, resilience. Puis scanner la liste des skills disponibles et invoquer tout skill technique pertinent. Skip = violation du pipeline."
	elif [ "$PHASE" = "implementation" ]; then
	  SKILL_MSG="Phase IMPLEMENTATION. Tu DOIS appeler Skill() pour testing d'abord. Puis scanner la liste des skills disponibles et invoquer chaque skill technique pertinent (backend, database-design, api-design...). Aucun code sans skills charges."
	elif [ "$PHASE" = "debug" ]; then
	  SKILL_MSG="Phase DEBUG. Tu DOIS appeler Skill() pour logging, tracing, monitoring, appsec. Puis scanner la liste et invoquer les skills de correction pertinents. Skip = violation du pipeline."
	else
	  SKILL_MSG="Tu DOIS scanner la liste des skills disponibles et invoquer Skill() pour chaque domaine pertinent a cette tache. Aucune exception. Skip = violation du pipeline Ciel."
	fi

# ─── Build context injection ────────────────────────────────────────────
MSG="CIEL depth: $DEPTH. | Dispatch researcher+explorer before writing code.$INTERVENTION_GATE | $SKILL_MSG"

MSG_BASE="$MSG" MEMORY_OUTPUT="$MEMORY_OUTPUT" python3 -c "
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
