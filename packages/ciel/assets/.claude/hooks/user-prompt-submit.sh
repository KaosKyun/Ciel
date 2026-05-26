#!/bin/bash
# Ciel v9 — UserPromptSubmit hook
# Injects: depth hint + cued-recall memory + intervention detection + auto-skill content
# Never blocks (exit 0 always)

# CIEL-DEFER-GUARD — a global plugin instance no-ops when the project ships AND
# wires its own copy of this hook. Paths are canonicalized (pwd -P) on BOTH sides
# so a symlinked or trailing-slash CLAUDE_PROJECT_DIR cannot make the project's
# own instance wrongly defer (which would disable Ciel entirely in the project).
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  _ciel_name="$(basename "${BASH_SOURCE[0]}")"
  _ciel_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"
  _ciel_proj="$(cd "$CLAUDE_PROJECT_DIR/.claude/hooks" 2>/dev/null && pwd -P)"
  if [ -n "$_ciel_proj" ] && [ -f "$_ciel_proj/$_ciel_name" ] && [ "$_ciel_self" != "$_ciel_proj" ]; then
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
      prompt_matches "(network|reseau|r.?seau|\bvpc\b|\bvnet\b|subnet|sous.?reseau|\bcidr\b|subnetting|spine.?leaf|hub.?(and.?)?spoke|transit.?gateway|vpc.?peering|network.?segmentation|network.?topolog|adressage|ip.?plan)" && route_skill "network-architecture"
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
      prompt_matches "(\bvpc\b|\bvnet\b|\bcidr\b|subnetting|sous.?reseau|spine.?leaf|transit.?gateway|vpc.?peering|ip.?plan|adressage.*reseau)" && route_skill "network-architecture"
      prompt_matches "(\btcp\b|\budp\b|http/?2|http/?3|\bquic\b|\bdns\b|\bbgp\b|\bospf\b|\bmtu\b|nat.?(gateway|traversal|table|rule)|network.?address.?translat|\bsnat\b|\bdnat\b|ipv6|ipv4|\bosi\b.?(model|layer|couche)|handshake|paquet.?ip|routing.?protocol)" && route_skill "network-protocols"
      prompt_matches "(firewall|pare.?feu|zero.?trust|\bmtls\b|spiffe|spire|micro.?segmentation|security.?group|\bnacl\b|\bddos\b|reseau.*s.?curit|s.?curit.*reseau|network.*security)" && route_skill "network-security"
      prompt_matches "(load.?balanc|reverse.?proxy|tls.?termination|\bingress\b|connectivit.*reseau|reseau.*config|configure.*network)" && route_skill "networking"
      ;;
    debug)
      route_skill "logging" "monitoring"
      prompt_matches "(trace|span|opentelemetry|distributed|propagation)" && route_skill "tracing"
      prompt_matches "(auth|security|token|injection|xss|csrf|vuln|exploit)" && route_skill "appsec"
      prompt_matches "(slow|perf|performance|leak|memory|cpu|bottleneck|latency)" && route_skill "performance"
      prompt_matches "(circuit|retry|timeout|cascading|outage|flaky|intermittent)" && route_skill "resilience"
      prompt_matches "(connectivit|connexion|connection|network|reseau|r.?seau|\bdns\b|\bmtu\b|traceroute|packet.?loss|perte.*paquet|unreachable|refused|resolv|firewall|\btls\b.*(fail|expire|handshake))" && route_skill "network-troubleshooting"
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
