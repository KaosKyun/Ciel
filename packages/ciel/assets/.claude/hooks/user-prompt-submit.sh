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

# ─── Phase detection + skill routing ────────────────────────────────────
# Determines phase, maps to skill names. No compact body — delegates to Skill() native.
PHASE=""
if prompt_matches "(architecture|design pattern|conception|structur.e?|schema.?archi|trade.?off|decoupage|ddd|monolithe|microservice|flux.*donn.e?|diagram|c4.?model|vision.*technique|plan.*architecture|hld|lld|system.?design|choisir.*techno|compare.*stack|refonte.*archi|audit.*archi|concevoir|designer)"; then
  PHASE="conception"
elif prompt_matches "(fix|bug|error|crash|debug|incident|regression|panic|stack.*trace|root.?cause|ne.*marche|pas.*fonctionn)"; then
  PHASE="debug"
elif prompt_matches "(implement|code|write|creer|creat|setup|configure|deploy|migrat|refactor|feature|function|method|class|route|endpoint|service|ajout|add.*route)"; then
  PHASE="implementation"
fi

# ─── Skill routing — names only, no compact bodies ─────────────────────
# Native Skill() loads full SKILL.md in tool_result (optimal context position).
SKILL_NAMES=""
SKILL_INJECT=""

route_skill() {
  for name in "$@"; do
    SKILL_NAMES="${SKILL_NAMES}Skill(\"$name\"), "
  done
}

if [ "$DEPTH" != "Trivial" ]; then
  case "$PHASE" in
    conception)
      route_skill "system-design" "architecture"
      prompt_matches "(ha|high.availability|resilience|failover|fallback|disaster|recovery)" && route_skill "high-availability" "resilience"
      prompt_matches "(ddd|domain|cqrs|event.source|event.driven|message|queue|kafka)" && route_skill "ddd" "event-driven"
      ;;
    implementation)
      route_skill "testing"
      prompt_matches "(backend|api|route|endpoint|controller|service|server|express|fastify|spring|django|go|rust)" && route_skill "backend" "api-design"
      prompt_matches "(frontend|react|vue|svelte|component|ui|css|tailwind|next|nuxt)" && route_skill "frontend"
      prompt_matches "(database|db|sql|prisma|orm|migration|schema|postgres|mysql|sqlite|mongo)" && route_skill "database-design"
      prompt_matches "(auth|security|token|oauth|jwt|password|secret|permission)" && route_skill "appsec"
      # Intent-bound (no reliable file glob — routed by prompt keywords)
      prompt_matches "(crypto|chiffr|encrypt|decrypt|\bhash|signature|\btls\b|certificat|cle.*priv)" && route_skill "crypto"
      prompt_matches "(resilience|circuit.?breaker|retry|timeout|fallback|bulkhead|degradation|failover)" && route_skill "resilience"
      prompt_matches "(caching|cache (strategy|layer|invalidation|stampede|aside|hit|miss|key|eviction)|cache.?stampede|\bredis\b|memcache|\bttl\b)" && route_skill "caching"
      prompt_matches "(performance|\blatency\b|\bp95\b|profiling|bottleneck|n\+1|slow.?quer)" && route_skill "performance"
      prompt_matches "(serverless|lambda|cloud.?function|\bfaas\b|cold.?start|step.?function)" && route_skill "serverless"
      prompt_matches "(nosql|dynamo|cassandra)" && route_skill "nosql"
      prompt_matches "(event.?driven|kafka|rabbitmq|\bsqs\b|pub.?sub|message.*queue|outbox)" && route_skill "event-driven"
      ;;
    debug)
      route_skill "logging" "monitoring"
      prompt_matches "(trace|span|opentelemetry|distributed|propagation)" && route_skill "tracing"
      prompt_matches "(auth|security|token|injection|xss|csrf|vuln|exploit)" && route_skill "appsec"
      prompt_matches "(slow|perf|performance|leak|memory|cpu|bottleneck|latency)" && route_skill "performance"
      prompt_matches "(circuit|retry|timeout|cascading|outage|flaky|intermittent)" && route_skill "resilience"
      ;;
    *)
      route_skill "research"
      ;;
  esac

  SKILL_NAMES=$(echo "$SKILL_NAMES" | sed 's/, $//')
  if [ -n "$SKILL_NAMES" ]; then
    SKILL_INJECT="
[CIEL] Skills pertinents (profondeur a la demande — invoque si utile, les contraintes dures arrivent par les rules) : → $SKILL_NAMES"
  fi
fi

# ─── Build context injection ────────────────────────────────────────────
MSG="CIEL depth: $DEPTH. | Dispatch researcher+explorer before writing code.$INTERVENTION_GATE$SKILL_INJECT"

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
