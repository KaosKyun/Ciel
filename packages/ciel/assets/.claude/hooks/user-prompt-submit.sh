#!/bin/bash
# Ciel v9 — UserPromptSubmit hook
# Injects: depth hint + cued-recall memory + intervention detection + auto-skill content
# Never blocks (exit 0 always)

# ─── Defer to project-level hook if this is a global plugin instance ─────
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -f "$CLAUDE_PROJECT_DIR/.claude/hooks/user-prompt-submit.sh" ]; then
  SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/$(basename "${BASH_SOURCE[0]}")"
  PROJECT_HOOK="$CLAUDE_PROJECT_DIR/.claude/hooks/user-prompt-submit.sh"
  if [ "$SCRIPT_PATH" != "$PROJECT_HOOK" ]; then
    exit 0
  fi
fi

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

# ─── Helper: prompt pattern matching ─────────────────────────────────────
prompt_matches() { printf '%s\n' "$PROMPT" | grep -qiE "$1"; }

# ─── Depth classification — default Standard, model reclassifies at DOCS ──
DEPTH="Standard"
if prompt_matches "(rename|typo|one.?liner|single.?line|comment|spelling|formatting|whitespace)"; then
  DEPTH="Trivial"
fi

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
if prompt_matches "(tu as oublié|t'as oublié|non en fait|attention que|ici on (fait|utilise) plutôt|tu te trompes|you forgot (to|that)|don't forget|that's not (right|correct|how)|no[,]? actually|wait[,—-] (no|don't|you forgot)|mauvaise approche)"; then
  INTERVENTION_GATE=" | CAPTURE GATE: intervention detected — propose memory capture via memoire skill"
fi

# ─── Persist depth ──────────────────────────────────────────────────────
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  echo "$DEPTH" > "$CLAUDE_PROJECT_DIR/.ciel/last-depth" 2>/dev/null || true
fi

# ─── compact_skill — extract description + first 15 body lines ──────────
# Mirrors bundle_skills_compact() from scripts/build-platforms.sh
compact_skill() {
  local name="$1"
  [ -z "$PROJECT_DIR" ] && return 1
  local skill_md="$PROJECT_DIR/.claude/skills/$name/SKILL.md"
  [ ! -f "$skill_md" ] && return 1

  local desc
  desc=$(awk '/^description:/{sub(/^description: */,""); print; exit}' "$skill_md" 2>/dev/null || echo "")

  echo "### $name"
  [ -n "$desc" ] && echo "$desc"
  echo ""

  # Strip YAML frontmatter, strip H1, take first 15 body lines
  awk '
    BEGIN { in_yaml=0; done=0 }
    /^---$/ {
      if (!done) {
        if (in_yaml) { in_yaml=0; done=1; next }
        else { in_yaml=1; next }
      }
    }
    !in_yaml { print }
  ' "$skill_md" 2>/dev/null | sed '/^# /d' | head -15
  return 0
}

# ─── Phase detection ────────────────────────────────────────────────────
PHASE=""
if prompt_matches "(architecture|design pattern|conception|structur.e?|schema.?archi|trade.?off|decoupage|ddd|monolithe|microservice|flux.*donn.e?|diagram|c4.?model|vision.*technique|plan.*architecture|hld|lld|system.?design|choisir.*techno|compare.*stack|refonte.*archi|audit.*archi|concevoir|designer)"; then
  PHASE="conception"
elif prompt_matches "(fix|bug|error|crash|debug|incident|regression|panic|stack.*trace|root.?cause|ne.*marche|pas.*fonctionn)"; then
  PHASE="debug"
elif prompt_matches "(implement|code|write|creer|creat|setup|configure|deploy|migrat|refactor|feature|function|method|class|route|endpoint|service|ajout|add.*route)"; then
  PHASE="implementation"
fi

# ─── Auto-inject compact skills based on phase ──────────────────────────
# Skipped for Trivial depth (rename, typo, 1-liner)
SKILL_INJECT=""
SKILL_BLOCK=""
SKILL_NAMES=""
if [ "$DEPTH" != "Trivial" ]; then

load_skills() {
  for name in "$@"; do
    local content
    content=$(compact_skill "$name" 2>/dev/null || true)
    if [ -n "$content" ]; then
      SKILL_BLOCK="${SKILL_BLOCK}
$content"
      SKILL_NAMES="${SKILL_NAMES}Skill(\"$name\"), "
    fi
  done
}

case "$PHASE" in
  conception)
    load_skills "system-design" "architecture"
    if prompt_matches "(ha|high.availability|resilience|failover|fallback|disaster|recovery)"; then
      load_skills "high-availability" "resilience"
    fi
    if prompt_matches "(ddd|domain|cqrs|event.source|event.driven|message|queue|kafka)"; then
      load_skills "ddd" "event-driven"
    fi
    ;;
  implementation)
    load_skills "testing"
    if prompt_matches "(backend|api|route|endpoint|controller|service|server|express|fastify|spring|django|go|rust)"; then
      load_skills "backend" "api-design"
    fi
    if prompt_matches "(frontend|react|vue|svelte|component|ui|css|tailwind|next|nuxt)"; then
      load_skills "frontend"
    fi
    if prompt_matches "(database|db|sql|prisma|orm|migration|schema|postgres|mysql|sqlite|mongo)"; then
      load_skills "database-design"
    fi
    if prompt_matches "(auth|security|token|oauth|jwt|password|secret|permission)"; then
      load_skills "appsec"
    fi
    ;;
  debug)
    load_skills "logging" "monitoring"
    if prompt_matches "(trace|span|opentelemetry|distributed|propagation)"; then
      load_skills "tracing"
    fi
    if prompt_matches "(auth|security|token|injection|xss|csrf|vuln|exploit)"; then
      load_skills "appsec"
    fi
    if prompt_matches "(slow|perf|performance|leak|memory|cpu|bottleneck|latency)"; then
      load_skills "performance"
    fi
    ;;
  *)
    load_skills "research"
    ;;
esac

SKILL_BLOCK=$(echo "$SKILL_BLOCK" | sed '/^$/N;/^\n$/d' 2>/dev/null || true)
SKILL_NAMES=$(echo "$SKILL_NAMES" | sed 's/, $//')
if [ -n "$SKILL_BLOCK" ]; then
  SKILL_INJECT="
[CIEL SKILLS] Compact preview. You MUST now invoke for full anti-patterns + patterns:
→ $SKILL_NAMES
$SKILL_BLOCK"
fi

fi  # [ "$DEPTH" != "Trivial" ]

# ─── Phase-aware skill loading order ────────────────────────────────────
SKILL_MSG=""
if [ "$PHASE" = "conception" ]; then
  SKILL_MSG="Phase CONCEPTION — charge les skills conception d'abord (system-design, architecture), puis skills techniques."
elif [ "$PHASE" = "implementation" ]; then
  SKILL_MSG="Phase IMPLEMENTATION — charge les skills techniques d'abord, puis implementation."
elif [ "$PHASE" = "debug" ]; then
  SKILL_MSG="Phase DEBUG — charge d'abord logging, tracing, monitoring, appsec pour investiguer."
fi

# ─── Build context injection ────────────────────────────────────────────
MSG="CIEL depth: $DEPTH. | Dispatch researcher+explorer before writing code.$INTERVENTION_GATE | $SKILL_MSG$SKILL_INJECT"

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
