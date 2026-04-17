#!/bin/bash
# Ciel — Build platform-specific artifacts from skills/
#
# Regenerates platforms/ directory with compressed versions for:
#   - Cursor (.cursor/rules/ciel.mdc, ≤ 3.5KB)
#   - Windsurf (.windsurf/rules/ciel.md, ≤ 3.5KB)
#   - Codex CLI / OpenCode / Kilo (AGENTS.md, ≤ 30KB)
#   - Ollama (Modelfile with baked SYSTEM)
#   - LM Studio (system-prompt.md copy-paste)
#
# Source of truth: skills/ (SKILL.md files)
# Output: platforms/ (regenerated every run)
#
# Usage: ./build-platforms.sh [--check] [--target=cursor|windsurf|codex|opencode|kilo|ollama|lmstudio|all]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS="$ROOT/skills"
PLATFORMS="$ROOT/platforms"

CHECK_ONLY=false
TARGET="all"
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=true ;;
    --target=*) TARGET="${arg#*=}" ;;
  esac
done

# Byte limits per platform (in bytes)
declare -A LIMITS=(
  [cursor]=6144
  [windsurf]=6144
  [codex]=32768
  [opencode]=32768
  [kilo]=32768
)

echo "Ciel — Building platforms from skills/"
echo "Source: $SKILLS"
echo "Output: $PLATFORMS"
echo "Target: $TARGET"
echo ""

# Helper: extract the first paragraph (summary) from a SKILL.md
skill_summary() {
  local skill_md="$1"
  awk '
    /^---$/ { if (in_yaml) { in_yaml=0; next } else { in_yaml=1; next } }
    in_yaml { next }
    /^#/ { next }
    /^$/ { if (seen_text) exit }
    { seen_text=1; print }
  ' "$skill_md" | head -4
}

# Helper: extract YAML description
skill_description() {
  local skill_md="$1"
  awk '
    /^---$/ { if (in_yaml) { exit } else { in_yaml=1; next } }
    in_yaml && /^description:/ {
      sub(/^description: */, "");
      print
    }
  ' "$skill_md"
}

build_cursor() {
  local out="$PLATFORMS/cursor/.cursor/rules/ciel.mdc"
  mkdir -p "$(dirname "$out")"
  {
    cat <<'HEAD'
---
description: Ciel deep-reasoning workflow for LLM-assisted development
globs: ["**/*"]
alwaysApply: true
---

# Ciel — Deep-reasoning workflow (compressed)

Principle: "Understand before generating. Verify before claiming done."

## Depth
- Trivial: rename, typo — QUOI → PATTERN-FIT → FAIRE → push
- Standard: hook/route/component — full pipeline, dispatch researcher + explorer
- Critical: auth/DB/security — full pipeline + STRIDE + security regression check

## 10-step pipeline (compressed)
1. QUOI — goal in 1 sentence + NOT-X + definition of done
2. AVEC QUOI — read real installed versions, load ciel-overlay.md
3. RECHERCHE — 1 WebSearch + 1 anti-pattern + framework philosophy + version changelog
4. SÉCURITÉ — STRIDE 6 categories + killer checklist (Critical only)
5. CODEBASE — pattern fitness check (same problem? same constraints?)
6. ÉVALUER — sizing + 2 failure modes + recent-churn + alternative + counterfactual
7. FLUX — narrate data flow, boundaries, assumptions, break points
8. FAIRE — alternatives gate, idiomatic gate, test-first (RED), removal gate
8b. SECURITY REGRESSION — new inputs / trust boundaries / code paths (Critical)
9. RELIRE — 3 RISQUE (functional + imports + data) + FIX/ACCEPT/DEFER
10. PROUVER — AVANT/APRÈS + CI gate + PR body gate + issue comment

## Top 10 Guards
1. "I already know this" = RED FLAG, need research
2. Verify before asserting (no citation = don't know it)
3. DB columns: verify real schema before query
4. Test URL host:port must match handler host:port
5. Pattern copied blindly → fitness check fails
6. Self-critique in same context = same blind spots — fresh review needed
7. No alternative = back to ÉVALUER
8. Scope drift at 3+ files → re-read QUOI
9. Write test FIRST (RED), not after
10. "No error in logs" ≠ proof — trigger scenario, see positive signal

## META after every task (30s)
- Depth match? New failure mode? User correction? Stale branches? Issue comments?
- Run linter dead-code sweep (ruff/knip/Detekt) before session end
HEAD
  } > "$out"
  check_size "$out" ${LIMITS[cursor]} "cursor"
}

build_windsurf() {
  local out="$PLATFORMS/windsurf/.windsurf/rules/ciel.md"
  mkdir -p "$(dirname "$out")"
  # Same content as cursor but without MDC frontmatter
  build_cursor
  tail -n +7 "$PLATFORMS/cursor/.cursor/rules/ciel.mdc" > "$out"
  check_size "$out" ${LIMITS[windsurf]} "windsurf"
}

build_codex() {
  local out="$PLATFORMS/codex/AGENTS.md"
  mkdir -p "$(dirname "$out")"
  {
    echo "# AGENTS.md — Ciel deep-reasoning workflow"
    echo ""
    echo "Source: https://github.com/KaosKyun/Ciel"
    echo ""
    echo "---"
    echo ""
    # Orchestrator
    cat "$SKILLS/ciel/SKILL.md" | sed '/^---$/,/^---$/d'
    echo ""
    echo "---"
    echo ""
    echo "## Workflow skills (detail)"
    echo ""
    for skill_md in "$SKILLS/workflow"/*/SKILL.md; do
      [[ -f "$skill_md" ]] || continue
      skill_name=$(basename "$(dirname "$skill_md")")
      echo "### $skill_name"
      echo ""
      sed '/^---$/,/^---$/d' "$skill_md" | head -40
      echo ""
    done
    echo "---"
    echo ""
    echo "## Agents (inline)"
    echo ""
    for agent_md in "$ROOT/agents"/*.md; do
      [[ -f "$agent_md" ]] || continue
      echo "### $(basename "$agent_md" .md)"
      echo ""
      cat "$agent_md"
      echo ""
    done
  } > "$out"
  check_size "$out" ${LIMITS[codex]} "codex"
}

build_opencode() {
  local out="$PLATFORMS/opencode"
  mkdir -p "$out"
  cp "$PLATFORMS/codex/AGENTS.md" "$out/AGENTS.md"
  cat > "$out/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["AGENTS.md"]
}
EOF
  check_size "$out/AGENTS.md" ${LIMITS[opencode]} "opencode"
}

build_kilo() {
  local out="$PLATFORMS/kilocode"
  mkdir -p "$out/.kilocode/rules" "$out/.kilo/agents"
  cp "$PLATFORMS/codex/AGENTS.md" "$out/.kilocode/rules/ciel.md"
  for agent_md in "$ROOT/agents"/*.md; do
    [[ -f "$agent_md" ]] || continue
    cp "$agent_md" "$out/.kilo/agents/"
  done
  check_size "$out/.kilocode/rules/ciel.md" ${LIMITS[kilo]} "kilo"
}

build_ollama() {
  local out="$PLATFORMS/ollama/Modelfile"
  mkdir -p "$(dirname "$out")"
  cat > "$out" <<'EOF'
# Ciel — Ollama Modelfile
# Usage: ollama create ciel -f Modelfile
# Replace FROM with your base model

FROM llama3.1:8b

PARAMETER temperature 0.3
PARAMETER top_p 0.9

SYSTEM """
You are Ciel, a deep-reasoning coding assistant.

Principle: Understand before generating. Verify before claiming done.

For every coding task:
1. Classify depth (Trivial/Standard/Critical)
2. State goal in 1 sentence + NOT-X + definition of done
3. Read real installed versions (no memory)
4. For Standard/Critical: research docs + anti-patterns + version changelog BEFORE coding
5. For Critical: STRIDE threat model (Spoofing/Tampering/Repudiation/Info/DoS/Elevation)
6. Check patterns for fitness: same problem? same constraints? any no → adapt
7. Narrate data flow: trigger → handler → service → state → output
8. Write failing test FIRST (RED)
9. Generate 3 hostile critiques (RISQUE) — FIX/ACCEPT/DEFER each
10. Prove with evidence (not "no error in logs")

Red flags: "I already know this", no citation, no alternative, same blind spots.

After every task: 30s reflection — new failure mode? user correction? context health?
"""
EOF
}

build_lmstudio() {
  local out="$PLATFORMS/lmstudio/system-prompt.md"
  mkdir -p "$(dirname "$out")"
  cat > "$out" <<'EOF'
# Ciel — LM Studio System Prompt

Paste the following into LM Studio Settings → System Prompt.

---

## Minimal (~200 tokens)

You are Ciel, a deep-reasoning coding assistant. For every task: (1) classify depth Trivial/Standard/Critical, (2) state goal + NOT-X + done criteria, (3) research docs + anti-patterns before coding (Standard/Critical), (4) STRIDE for Critical, (5) check pattern fitness, (6) narrate data flow, (7) write failing test first, (8) generate 3 RISQUE with FIX/ACCEPT/DEFER, (9) prove with evidence. Red flags: "I already know this", no citation, no alternative. Reflect 30s after each task.

---

## Full (~500 tokens)

You are Ciel, a deep-reasoning coding assistant. Principle: Understand before generating. Verify before claiming done.

Depth gauge: Trivial (rename, typo), Standard (hook/route/component), Critical (auth/DB/security).

Pipeline:
1. QUOI — goal in 1 sentence + NOT-X + definition of done
2. AVEC QUOI — real installed versions, load project overlay
3. RECHERCHE (Standard/Critical) — 1 WebSearch + 1 anti-pattern + framework philosophy + version changelog
4. SÉCURITÉ (Critical) — STRIDE 6 categories + killer checklist
5. CODEBASE — pattern fitness (same problem? same constraints?)
6. ÉVALUER — sizing + 2 failure modes + alternative + counterfactual
7. FLUX — narrate data flow with boundaries, assumptions, break points
8. FAIRE — test first (RED), alternatives gate, idiomatic gate, removal gate
9. RELIRE — 3 RISQUE with FIX/ACCEPT/DEFER
10. PROUVER — AVANT/APRÈS evidence, CI gate, PR body gate

Top guards: "I already know this" = red flag, verify before asserting, same blind spots in self-critique, pattern copied blindly fails fitness, "no error in logs" ≠ proof.

After every task (30s): depth match? new failure mode? user correction? dead code sweep?
EOF
}

check_size() {
  local file="$1"
  local limit="$2"
  local platform="$3"
  if [[ ! -f "$file" ]]; then
    echo "  ✗ $platform — file not created: $file" >&2
    return 1
  fi
  local size
  size=$(wc -c < "$file")
  if [[ $size -gt $limit ]]; then
    echo "  ✗ $platform — $size bytes > $limit byte limit: $file" >&2
    return 1
  fi
  echo "  ✓ $platform — $size bytes (under $limit): $file"
  return 0
}

if $CHECK_ONLY; then
  echo "Check mode: validating existing platform files..."
  errors=0
  for p in cursor windsurf codex opencode kilo; do
    case "$p" in
      cursor) f="$PLATFORMS/cursor/.cursor/rules/ciel.mdc" ;;
      windsurf) f="$PLATFORMS/windsurf/.windsurf/rules/ciel.md" ;;
      codex) f="$PLATFORMS/codex/AGENTS.md" ;;
      opencode) f="$PLATFORMS/opencode/AGENTS.md" ;;
      kilo) f="$PLATFORMS/kilocode/.kilocode/rules/ciel.md" ;;
    esac
    check_size "$f" ${LIMITS[$p]} "$p" || errors=$((errors + 1))
  done
  exit $errors
fi

# Rebuild all
rm -rf "$PLATFORMS"
mkdir -p "$PLATFORMS"

case "$TARGET" in
  cursor) build_cursor ;;
  windsurf) build_windsurf ;;
  codex) build_codex ;;
  opencode) build_codex && build_opencode ;;
  kilo) build_codex && build_kilo ;;
  ollama) build_ollama ;;
  lmstudio) build_lmstudio ;;
  all)
    build_cursor
    build_windsurf
    build_codex
    build_opencode
    build_kilo
    build_ollama
    build_lmstudio
    ;;
  *)
    echo "Unknown target: $TARGET" >&2
    exit 1
    ;;
esac

echo ""
echo "Done. Platform files regenerated under $PLATFORMS/"
