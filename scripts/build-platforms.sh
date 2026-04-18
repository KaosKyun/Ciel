#!/bin/bash
# Ciel — Build platform-specific artifacts from skills/
#
# Regenerates platforms/ directory for:
#   - Cursor   (.cursor/rules/ciel.mdc, ≤ 6KB) — compressed rules
#   - Windsurf (.windsurf/rules/ciel.md, ≤ 6KB) — compressed rules
#   - Codex    (AGENTS.md, ≤ 32KB)
#   - OpenCode (.opencode/plugins/ + agents/ + commands/ + AGENTS.md) — NATIVE primitives
#   - Kilo     (.kilocode/rules/ciel.md + .kilo/agents/, ≤ 32KB)
#   - Ollama   (Modelfile with baked SYSTEM)
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
CIEL_VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION" 2>/dev/null || echo "0.0.0")"

CHECK_ONLY=false
TARGET="all"
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=true ;;
    --target=*) TARGET="${arg#*=}" ;;
  esac
done

# Byte limits per platform (in bytes)
# (Portable across bash 3.2 — no associative arrays)
LIMIT_cursor=6144
# Windsurf native: per-skill ≤64KB, per-workflow ≤16KB, per-rule ≤6KB, rules total ≤12KB
LIMIT_windsurf_skill=65536
LIMIT_windsurf_workflow=16384
LIMIT_windsurf_rule=6144
LIMIT_windsurf_rules_total=12288
LIMIT_codex=32768          # AGENTS.md (compact, not a full dump)
LIMIT_codex_agent=65536
LIMIT_codex_command=16384
LIMIT_opencode=32768
LIMIT_kilo_agents_md=6144  # Compact orchestrator + dispatch table
LIMIT_kilo_rule=6144
LIMIT_kilo_agent=65536
LIMIT_opencode_agents_md=6144
# Bumped 8192 → 12288 in v2.5.1 to fit the dispatch-gate counter port
# (tool.execute.before hook + closure state + defense-in-depth). Plugin body
# loads once per session, so ~4KB headroom is not a per-turn cost.
LIMIT_opencode_plugin=12288
LIMIT_opencode_agent=65536
# Command bodies are loaded only on slash invocation, not in session baseline,
# so per-command byte count doesn't compound. 16KB gives headroom for /ciel-init
# (platform-aware branches, ~12KB) and /ciel-audit.
LIMIT_opencode_command=16384

limit_for() {
  local var="LIMIT_$1"
  eval "echo \${$var:-0}"
}

# Ciel hook regex — single source of truth, shared between bash hooks, PS1 hooks,
# and the OpenCode TS plugin. Keep these in sync with hooks/*.sh source.
CIEL_CODE_EXT_RE='\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql)$'
CIEL_CRITICAL_FILE_RE='(auth|Auth|security|Security|Route|Service|Controller|Repository|Gateway|Middleware|Proxy|Token|Session|Password|Secret)'
CIEL_CRITICAL_KEYWORD_RE='\b(auth|authenti|author|jwt|oauth|password|secret|token|session|payment|credit.card|migration.*schema|2fa|mfa|encryption|credential|cookie.*security)\b'
CIEL_TRIVIAL_KEYWORD_RE='\b(rename|typo|copyright|comment|readme|1-line|one.line|fix.typo|spelling)\b'

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
  check_size "$out" "$(limit_for cursor)" "cursor"
}

build_windsurf() {
  local out="$PLATFORMS/windsurf"
  mkdir -p "$out/.windsurf/rules"

  # Skills — orchestrator + 4 agent skills (bundled inline: sub-skills not native outside Claude Code)
  emit_windsurf_ciel_skill "$out/.windsurf/skills/ciel/SKILL.md"
  emit_windsurf_agent_skill "$ROOT/agents/researcher.md" "$out/.windsurf/skills/ciel-researcher/SKILL.md" researcher
  emit_windsurf_agent_skill "$ROOT/agents/explorer.md"   "$out/.windsurf/skills/ciel-explorer/SKILL.md"   explorer
  emit_windsurf_agent_skill "$ROOT/agents/critic.md"     "$out/.windsurf/skills/ciel-critic/SKILL.md"     critic
  emit_windsurf_agent_skill "$ROOT/agents/improver.md"   "$out/.windsurf/skills/ciel-improver/SKILL.md"   improver

  # Workflows — /ciel wrapper + all commands/*.md + ciel-improve from skills/meta
  mkdir -p "$out/.windsurf/workflows"
  emit_windsurf_workflow_wrapper "$out/.windsurf/workflows/ciel.md" "ciel" \
    "Invoke the Ciel deep-reasoning orchestrator. Classifies depth, routes pipeline, dispatches @ciel-* skills."
  for cmd_md in "$ROOT/commands"/*.md; do
    [[ -f "$cmd_md" ]] || continue
    local wfname; wfname=$(basename "$cmd_md")
    emit_windsurf_workflow "$cmd_md" "$out/.windsurf/workflows/$wfname"
  done
  # ciel-improve: source from skills/meta (no root commands/ entry)
  emit_windsurf_workflow "$SKILLS/meta/ciel-improve/SKILL.md" "$out/.windsurf/workflows/ciel-improve.md"

  # Rules — compact (≤4KB per file, ≤12KB aggregate)
  # Strip MDC frontmatter from cursor rules for Windsurf compatibility
  build_cursor
  {
    printf '# Ciel — Rules (Windsurf)\n\n'
    tail -n +7 "$PLATFORMS/cursor/.cursor/rules/ciel.mdc"
  } > "$out/.windsurf/rules/ciel.md"

  # Size checks
  for skill_f in "$out"/.windsurf/skills/*/SKILL.md; do
    [[ -f "$skill_f" ]] || continue
    local sname; sname=$(basename "$(dirname "$skill_f")")
    check_size "$skill_f" "$(limit_for windsurf_skill)" "windsurf-skill:$sname"
  done
  for wf_f in "$out"/.windsurf/workflows/*.md; do
    [[ -f "$wf_f" ]] || continue
    check_size "$wf_f" "$(limit_for windsurf_workflow)" "windsurf-workflow:$(basename "$wf_f")"
  done
  check_size "$out/.windsurf/rules/ciel.md" "$(limit_for windsurf_rule)" "windsurf-rule"
  check_total_size "$out/.windsurf/rules" "$(limit_for windsurf_rules_total)" "windsurf-rules-total"
}

build_codex() {
  local out="$PLATFORMS/codex"
  mkdir -p "$out/.codex/hooks" "$out/.codex/commands" "$out/.codex/agents"

  # Compact AGENTS.md (≤32KB — orchestrator overview + pointer to .codex/ primitives)
  emit_codex_agents_md "$out/AGENTS.md"

  # Hooks — userpromptsubmit depth classification + dispatch gate
  emit_codex_hooks "$out/.codex"

  # Commands — source commands/*.md verbatim + ciel-improve from skills/meta
  for cmd_md in "$ROOT/commands"/*.md; do
    [[ -f "$cmd_md" ]] || continue
    cp "$cmd_md" "$out/.codex/commands/$(basename "$cmd_md")"
  done
  cp "$SKILLS/meta/ciel-improve/SKILL.md" "$out/.codex/commands/ciel-improve.md"

  # 4 subagents (skills bundled inline — no skills primitive on Codex)
  emit_codex_agent "$ROOT/agents/researcher.md" "$out/.codex/agents/ciel-researcher.md" researcher
  emit_codex_agent "$ROOT/agents/explorer.md"   "$out/.codex/agents/ciel-explorer.md"   explorer
  emit_codex_agent "$ROOT/agents/critic.md"     "$out/.codex/agents/ciel-critic.md"     critic
  emit_codex_agent "$ROOT/agents/improver.md"   "$out/.codex/agents/ciel-improver.md"   improver

  # Size checks
  check_size "$out/AGENTS.md" "$(limit_for codex)" "codex-agents-md"
  for a in "$out"/.codex/agents/*.md; do
    [[ -f "$a" ]] || continue
    check_size "$a" "$(limit_for codex_agent)" "codex-agent:$(basename "$a")"
  done
  for c in "$out"/.codex/commands/*.md; do
    [[ -f "$c" ]] || continue
    check_size "$c" "$(limit_for codex_command)" "codex-command:$(basename "$c")"
  done
}

build_opencode() {
  local out="$PLATFORMS/opencode"
  mkdir -p "$out/.opencode/plugins" "$out/.opencode/agents" "$out/.opencode/commands"

  # Compact AGENTS.md (≤6KB — no 907-line dump; the logic lives in agents/plugin)
  emit_opencode_agents_md "$out/AGENTS.md"

  # opencode.json — registers plugin + instructions
  emit_opencode_config "$out/opencode.json"

  # Plugin (TS port of hooks/*.sh)
  emit_opencode_plugin "$out/.opencode/plugins/ciel.ts"

  # 4 subagents (skills bundled inline — no skills primitive on OpenCode)
  emit_opencode_agent "$ROOT/agents/researcher.md" "$out/.opencode/agents/ciel-researcher.md" researcher
  emit_opencode_agent "$ROOT/agents/explorer.md"   "$out/.opencode/agents/ciel-explorer.md"   explorer
  emit_opencode_agent "$ROOT/agents/critic.md"     "$out/.opencode/agents/ciel-critic.md"     critic
  emit_opencode_agent "$ROOT/agents/improver.md"   "$out/.opencode/agents/ciel-improver.md"   improver

  # 6 slash commands (source commands/*.md — currently 6 after v2.4.2 deleted
  # ciel.md + ciel-improve.md on the Claude side)
  for cmd_md in "$ROOT/commands"/*.md; do
    [[ -f "$cmd_md" ]] || continue
    local name
    name=$(basename "$cmd_md")
    emit_opencode_command "$cmd_md" "$out/.opencode/commands/$name"
  done

  # OpenCode-specific /ciel and /ciel-improve slash wrappers.
  # Claude Code auto-routes /<name> → skill of same name, so the command files
  # were deleted in v2.4.2 to remove the duplicate entry. OpenCode's slash
  # routing is not confirmed to do the same — to guarantee /ciel and
  # /ciel-improve remain typeable in OpenCode, emit thin wrappers that
  # explicitly invoke the skill via the Skill tool.
  emit_opencode_skill_wrapper \
    "$out/.opencode/commands/ciel.md" \
    "ciel" \
    "Slash trigger for the Ciel orchestrator skill on OpenCode."
  emit_opencode_skill_wrapper \
    "$out/.opencode/commands/ciel-improve.md" \
    "ciel-improve" \
    "Slash trigger for the ciel-improve skill on OpenCode."

  # Size checks
  check_size "$out/AGENTS.md"                 "$(limit_for opencode_agents_md)" "opencode-agents-md"
  check_size "$out/.opencode/plugins/ciel.ts" "$(limit_for opencode_plugin)"    "opencode-plugin"
  for a in "$out"/.opencode/agents/*.md; do
    check_size "$a" "$(limit_for opencode_agent)" "opencode-agent:$(basename "$a")"
  done
  for c in "$out"/.opencode/commands/*.md; do
    check_size "$c" "$(limit_for opencode_command)" "opencode-command:$(basename "$c")"
  done
}

build_kilo() {
  local out="$PLATFORMS/kilocode"
  mkdir -p "$out/.kilocode/rules" "$out/.kilo/agents"

  # Compact AGENTS.md (≤6KB) — orchestrator overview + subagent dispatch table
  emit_kilo_agents_md "$out/AGENTS.md"

  # Rules (≤6KB) — principle + Top-10 guards + prose hook equivalents
  emit_kilo_rules "$out/.kilocode/rules/ciel.md"

  # 4 subagents — ciel-prefixed (NOT raw agent names; replaces broken pre-v2.9 pointers)
  emit_kilo_agent "$ROOT/agents/researcher.md" "$out/.kilo/agents/ciel-researcher.md" researcher
  emit_kilo_agent "$ROOT/agents/explorer.md"   "$out/.kilo/agents/ciel-explorer.md"   explorer
  emit_kilo_agent "$ROOT/agents/critic.md"     "$out/.kilo/agents/ciel-critic.md"     critic
  emit_kilo_agent "$ROOT/agents/improver.md"   "$out/.kilo/agents/ciel-improver.md"   improver

  # Size checks
  check_size "$out/AGENTS.md" "$(limit_for kilo_agents_md)" "kilo-agents-md"
  check_size "$out/.kilocode/rules/ciel.md" "$(limit_for kilo_rule)" "kilo-rule"
  for a in "$out"/.kilo/agents/*.md; do
    [[ -f "$a" ]] || continue
    check_size "$a" "$(limit_for kilo_agent)" "kilo-agent:$(basename "$a")"
  done
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

Depth gauge: Trivial (rename/typo) → Standard (hook/route/component) → Critical (auth/DB/security/payment).

10-step pipeline:
1. QUOI — 1-sentence goal + NOT-X + definition of done
2. AVEC QUOI — read real installed versions (no memory)
3. RECHERCHE (Standard+Critical) — research docs + anti-patterns BEFORE coding
   Simulate @ciel-researcher: official docs → anti-patterns → framework philosophy → version changelog
4. SÉCURITÉ (Critical) — STRIDE: Spoofing/Tampering/Repudiation/Info/DoS/Elevation
5. CODEBASE — pattern fitness: same problem? same constraints? any no → adapt
   Simulate @ciel-explorer: pattern-fitness-check + flux-narrator
6. ÉVALUER — sizing + 2 failure modes + alternative + counterfactual
7. FLUX — narrate trigger → handler → service → state → output
8. FAIRE — write failing test FIRST (RED); alternatives gate; idiomatic gate; removal gate
9. RELIRE — 3 RISQUE (functional/imports/data) — FIX/ACCEPT/DEFER each
   Simulate @ciel-critic: hostile critiques from a different perspective
10. PROUVER — AVANT/APRÈS evidence; trigger the scenario; see a positive signal

4-agent model (simulate when dispatching sub-tasks):
- @ciel-researcher: isolated web research, no session bias
- @ciel-explorer: codebase pattern fitness + data flow narration
- @ciel-critic: hostile 3-RISQUE audit (MODE=RELIRE or MODE=CRITIQUER)
- @ciel-improver: meta-skill self-improvement on /ciel-improve

Top guards: "I already know this" = red flag; no citation = don't know it; pattern copied blindly fails fitness; self-critique in same context = same blind spots; "no error in logs" ≠ proof.

After every task (30s): depth match? new failure mode? user correction? context health?
"""
EOF
}

build_lmstudio() {
  local dir="$PLATFORMS/lmstudio"
  mkdir -p "$dir"

  # system-prompt.md — two versions for copy-paste into LM Studio system prompt field
  cat > "$dir/system-prompt.md" <<'EOF'
# Ciel — LM Studio System Prompt

Paste one of the following into LM Studio Settings → System Prompt.

---

## Minimal (~200 tokens)

You are Ciel, a deep-reasoning coding assistant. For every task: (1) classify depth Trivial/Standard/Critical, (2) state goal + NOT-X + done criteria, (3) research docs + anti-patterns before coding (Standard/Critical), (4) STRIDE for Critical, (5) check pattern fitness, (6) narrate data flow: trigger → handler → service → state → output, (7) write failing test first (RED), (8) generate 3 RISQUE with FIX/ACCEPT/DEFER, (9) prove with evidence — trigger the scenario, see a positive signal. 4-agent model: @ciel-researcher (research), @ciel-explorer (codebase), @ciel-critic (audit), @ciel-improver (meta). Red flags: "I already know this", no citation, no alternative. Reflect 30s after each task.

---

## Full (~600 tokens)

You are Ciel, a deep-reasoning coding assistant. Principle: Understand before generating. Verify before claiming done.

Depth gauge: Trivial (rename/typo), Standard (hook/route/component/service), Critical (auth/DB schema/security/payment).

10-step pipeline:
1. QUOI — goal in 1 sentence + NOT-X + definition of done
2. AVEC QUOI — real installed versions (not memory); load ciel-overlay.md
3. RECHERCHE (Standard/Critical) — simulate @ciel-researcher: official docs + anti-patterns + framework philosophy + version changelog. No citation = don't know it.
4. SÉCURITÉ (Critical) — STRIDE 6 categories (Spoofing/Tampering/Repudiation/Info/DoS/Elevation) + killer checklist
5. CODEBASE — simulate @ciel-explorer: pattern fitness (same problem? same constraints? any no → adapt) + flux-narrator
6. ÉVALUER — sizing + 2 failure modes + alternative + counterfactual
7. FLUX — narrate: trigger → handler → service → state → output (with boundaries + assumptions)
8. FAIRE — write failing test FIRST (RED); alternatives gate; idiomatic gate; removal gate
9. RELIRE — simulate @ciel-critic MODE=RELIRE: 3 RISQUE (functional/imports/data flow) — FIX/ACCEPT/DEFER each
10. PROUVER — AVANT/APRÈS evidence; trigger the scenario; see a positive signal

4-agent model (simulate when you spawn sub-tasks):
- @ciel-researcher: isolated research fork, no session bias, WebFetch+WebSearch only
- @ciel-explorer: codebase-only fork, pattern fitness + data flow
- @ciel-critic: audit fork, 3 RISQUE hostile critiques from a fresh perspective
- @ciel-improver: meta-agent, runs on /ciel-improve only

Top guards: "I already know this" = red flag; verify before asserting; pattern copied blindly fails fitness; self-critique in same context = same blind spots → simulate @ciel-critic; no alternative considered → back to ÉVALUER; scope drift at 3+ files → re-read QUOI; "no error in logs" ≠ proof.

After every task (30s): depth match? new failure mode? user correction? context health?
EOF

  # ciel.preset.json — LM Studio preset (verified format: operation.fields[] with dot-notation keys)
  # System prompt field key: llm.prediction.systemPrompt
  # Storage: ~/.lmstudio/config-presets/ (LM Studio 0.3.x format)
  # Note: temperature/topP are included but may be ignored via API (bug #1389 in lmstudio-bug-tracker).
  # To apply: open LM Studio → top-right preset selector → import this file or create manually.
  local sys_prompt
  sys_prompt="You are Ciel, a deep-reasoning coding assistant. Principle: Understand before generating. Verify before claiming done. For every task: (1) classify depth Trivial/Standard/Critical, (2) QUOI: goal + NOT-X + done criteria, (3) RECHERCHE: research docs + anti-patterns before coding (Standard/Critical), (4) SÉCURITÉ: STRIDE for Critical, (5) CODEBASE: pattern fitness + flux-narrator, (6) ÉVALUER: sizing + 2 failure modes, (7) FAIRE: test first (RED), alternatives gate, (8) RELIRE: 3 RISQUE with FIX/ACCEPT/DEFER, (9) PROUVER: trigger the scenario, see a positive signal. 4-agent model: @ciel-researcher (research), @ciel-explorer (codebase), @ciel-critic (audit), @ciel-improver (meta). Red flags: no citation, no alternative, same blind spots. Reflect 30s after each task."
  cat > "$dir/ciel.preset.json" <<EOF
{
  "identifier": "@local:ciel",
  "name": "Ciel",
  "changed": true,
  "operation": {
    "fields": [
      { "key": "llm.prediction.temperature", "value": 0.3 },
      { "key": "llm.prediction.topPSampling", "value": { "checked": true, "value": 0.9 } },
      { "key": "llm.prediction.systemPrompt", "value": "$sys_prompt" }
    ]
  },
  "load": { "fields": [] }
}
EOF
}

# ============================================================================
# OpenCode-specific helpers — generate native primitives (plugin, agents,
# commands) instead of dumping a compressed rules file.
# ============================================================================

# Strip YAML frontmatter from a SKILL.md (keep body only)
strip_yaml() {
  local file="$1"
  awk '
    BEGIN { in_yaml=0; done=0 }
    /^---$/ {
      if (!done) {
        if (in_yaml) { in_yaml=0; done=1; next }
        else { in_yaml=1; next }
      }
    }
    !in_yaml { print }
  ' "$file"
}

# Bundle multiple SKILL.md files inline with ### headers.
# Usage: bundle_skills_inline <skill_md_path> [<skill_md_path> ...]
bundle_skills_inline() {
  for skill_md in "$@"; do
    [[ -f "$skill_md" ]] || continue
    local name
    name=$(basename "$(dirname "$skill_md")")
    echo ""
    echo "---"
    echo ""
    echo "### Skill: \`$name\`"
    echo ""
    strip_yaml "$skill_md"
  done
}

# Bundle skills in compact form: YAML description + paths glob + first 20 body lines.
# Used for domain skills inside the explorer bundle — the full skill body is ~100 lines
# and only one domain skill is relevant per task. Loading all 8 fully on every dispatch
# wastes ~25KB = ~6250 tokens. Compact keeps the trigger signals + main checks,
# points to the full skill for edge cases.
#
# Usage: bundle_skills_compact <skill_md_path> [<skill_md_path> ...]
bundle_skills_compact() {
  for skill_md in "$@"; do
    [[ -f "$skill_md" ]] || continue
    local name desc paths
    name=$(basename "$(dirname "$skill_md")")
    desc=$(skill_yaml_field "$skill_md" description)
    paths=$(skill_yaml_field "$skill_md" paths)

    echo ""
    echo "---"
    echo ""
    echo "### Skill (compact): \`$name\`"
    echo ""
    [[ -n "$paths" ]] && echo "**Triggers on paths:** \`$paths\`"
    [[ -n "$desc" ]] && echo ""
    [[ -n "$desc" ]] && echo "**Purpose:** $desc"
    echo ""
    echo "**Key checks** (excerpt — full skill available on Claude Code at \`skills/domain/$name/\`):"
    echo ""
    # First 20 lines of body (after YAML), skipping the intro H1 line
    strip_yaml "$skill_md" | sed '/^# /d' | head -20
  done
}

# Extract a YAML field's value from a SKILL.md
skill_yaml_field() {
  local file="$1"
  local field="$2"
  awk -v f="$field" '
    BEGIN { in_yaml=0 }
    /^---$/ { if (in_yaml) { exit } else { in_yaml=1; next } }
    in_yaml {
      if (match($0, "^" f ":[[:space:]]*")) {
        val = substr($0, RLENGTH + 1)
        print val
        exit
      }
    }
  ' "$file"
}

# Emit an OpenCode agent file: frontmatter + source agent body + bundled skills.
# Usage: emit_opencode_agent <source_agent_md> <out_path> <role>
#   role: researcher | explorer | critic | improver
emit_opencode_agent() {
  local src="$1"
  local out="$2"
  local role="$3"

  local desc
  desc=$(skill_yaml_field "$src" "description")
  [[ -z "$desc" ]] && desc=$(grep '^# ' "$src" | head -1 | sed 's/^# *//')
  [[ -z "$desc" ]] && desc="Ciel $role — isolated-context subagent"

  # Per-role configuration — defaults favour token economy.
  # Model choice is graded by task difficulty vs dispatch frequency:
  #   researcher → Haiku 4.5  (retrieval + structured synthesis, no subtle
  #                            reasoning; ~3x cheaper than Sonnet, ~15x
  #                            cheaper than Opus; dispatched on every
  #                            Standard+ task so savings compound)
  #   explorer   → Sonnet 4.6 (flux-narrator needs call-graph tracing)
  #   critic     → Sonnet 4.6 (blind-spot hunting — keep a safety margin;
  #                            override to Opus 4.7 for audit-critical work)
  #   improver   → Sonnet 4.6 (long-running aggregation; override to Opus
  #                            for deep self-improvement passes if budget
  #                            allows — 1-2M tokens/run)
  #
  # OpenCode users can override any of these post-install by editing the
  # `model:` line in .opencode/agents/ciel-*.md. Available model IDs:
  #     anthropic/claude-haiku-4-5-20251001
  #     anthropic/claude-sonnet-4-6
  #     anthropic/claude-opus-4-7
  #
  # Tool permissions are as tight as the role allows — no bash/glob/grep
  # unless the agent genuinely needs them, to prevent uncontrolled context
  # expansion and keep the blast radius of a subagent small.
  local tools_block=""
  local model_id="anthropic/claude-sonnet-4-6"
  case "$role" in
    researcher)
      # Pure read-only web research: no codebase, no shell.
      # Haiku 4.5: retrieval + synthesis is its sweet spot, structured
      # output (≤500 tokens target) doesn't benefit from Sonnet's deeper
      # reasoning. Override to sonnet-4-6 if you see hallucinated findings.
      tools_block=$'tools:\n  write: false\n  edit: false\n  bash: false\n  read: true\n  glob: false\n  grep: false\n  webfetch: true\n  websearch: true'
      model_id="anthropic/claude-haiku-4-5-20251001"
      ;;
    explorer)
      # Codebase-only: no web, no shell. Read+glob+grep for navigation.
      tools_block=$'tools:\n  write: false\n  edit: false\n  bash: false\n  read: true\n  glob: true\n  grep: true\n  webfetch: false\n  websearch: false'
      ;;
    critic)
      # Audit-only: read+grep changed files. Bash for git diff / log.
      tools_block=$'tools:\n  write: false\n  edit: false\n  bash: true\n  read: true\n  glob: true\n  grep: true\n  webfetch: false\n  websearch: false'
      ;;
    improver)
      # Long-running meta-agent: reads session logs + web docs for benchmarks.
      tools_block=$'tools:\n  write: false\n  edit: false\n  bash: true\n  read: true\n  glob: true\n  grep: true\n  webfetch: true\n  websearch: true'
      ;;
  esac

  {
    echo "---"
    echo "description: $desc"
    echo "mode: subagent"
    echo "model: $model_id"
    echo "temperature: 0.2"
    echo "$tools_block"
    echo "---"
    echo ""
    strip_yaml "$src"
    echo ""
    echo "---"
    echo ""
    echo "## Skills invoked (bundled inline)"
    echo ""
    echo "> The following skills are bundled here because OpenCode has no native 'skills' primitive."
    echo "> Each skill below is a complete procedure you invoke by following its \"process\" section."
    echo "> These bundles replace the skill references in the process above — same semantics, inline."

    # Shared skill-bundle emitter (see _emit_agent_bundled_skills above).
    # Note: improver gets an extra OpenCode-specific note appended below.
    _emit_agent_bundled_skills "$role"

    if [[ "$role" == "improver" ]]; then
      echo ""
      echo "---"
      echo ""
      echo "## OpenCode note"
      echo ""
      echo "The \`skill-variant-evaluator\` and \`skill-creator\` skills require \`claude --print\` headless mode to run their full binary-eval / scaffold-generation cycle. On OpenCode, they operate in degraded mode: the improver produces patch-sets and skill scaffolds as *proposals* only — you manually save the generated files. For the full eval harness, run \`/ciel-eval\` from Claude Code."
    fi
  } > "$out"
}

# Emit an OpenCode command file from a source commands/*.md.
# Adds OpenCode frontmatter (description, agent, subtask).
# Usage: emit_opencode_command <source_cmd_md> <out_path>
emit_opencode_command() {
  local src="$1"
  local out="$2"
  local name
  name=$(basename "$src" .md)

  local desc
  # Extract italic summary from first 3 lines; fallback to H1 title
  desc=$(sed -n '1,3p' "$src" | grep -oE '^\*.*\*$' | head -1 | sed 's/^\*//; s/\*$//' 2>/dev/null || true)
  if [[ -z "$desc" ]]; then
    desc=$(head -1 "$src" | sed 's/^# *//' 2>/dev/null || true)
  fi
  [[ -z "$desc" ]] && desc="Ciel command: $name"

  local agent="" subtask="false"
  case "$name" in
    ciel)             agent="" ; subtask="false" ;;
    ciel-improve)     agent="ciel-improver"   ; subtask="true"  ;;
    ciel-eval)        agent="ciel-improver"   ; subtask="true"  ;;
    ciel-create-skill) agent="ciel-improver"  ; subtask="true"  ;;
    ciel-recommend)   agent="ciel-researcher" ; subtask="true"  ;;
    ciel-update)      agent=""                ; subtask="false" ;;
  esac

  {
    echo "---"
    echo "description: ${desc:-Ciel command: $name}"
    [[ -n "$agent" ]] && echo "agent: $agent"
    echo "subtask: $subtask"
    echo "---"
    echo ""
    case "$name" in
      ciel-improve|ciel-eval|ciel-create-skill)
        echo "> **OpenCode note**: This command requires \`claude --print\` headless mode for full functionality (binary evals, skill scaffold generation). On OpenCode it runs in degraded mode — the improver agent returns proposals only. For the full harness, use Claude Code."
        echo ""
        ;;
    esac
    cat "$src"
  } > "$out"
}

# Emit a thin slash-command wrapper that invokes a same-named skill via the
# Skill tool. Used for /ciel and /ciel-improve on OpenCode (on Claude Code,
# the command file is intentionally absent — Claude Code auto-routes
# /<name> → skill of the same name).
# Usage: emit_opencode_skill_wrapper <out_path> <skill_name> <description>
emit_opencode_skill_wrapper() {
  local out="$1"
  local skill_name="$2"
  local desc="$3"
  {
    echo "---"
    echo "description: $desc"
    echo "---"
    echo ""
    echo "Invoke the \`$skill_name\` skill via the Skill tool with the user's arguments:"
    echo ""
    echo '```'
    echo '$ARGUMENTS'
    echo '```'
    echo ""
    echo "If \`\$ARGUMENTS\` is empty, invoke the skill with no argument — it will classify the current context and prompt for a task if needed."
    echo ""
    echo "The full logic (depth classifier, intent routing, pipeline selection, agent dispatch rules) lives in the \`$skill_name\` skill itself. This command file is a thin trigger; modify the skill, not this file, to change behavior."
  } > "$out"
}

# Emit a compact AGENTS.md for OpenCode (≤6KB) referencing the agents/commands
# that are installed as native OpenCode primitives. $CIEL_VERSION is injected into
# the title via a first-line echo so users can verify installed version at a glance;
# the rest of the file uses a literal heredoc to preserve backticks.
emit_opencode_agents_md() {
  local out="$1"
  echo "# AGENTS.md — Ciel deep-reasoning workflow (OpenCode, v${CIEL_VERSION})" > "$out"
  cat >> "$out" <<'EOF'

Source: https://github.com/KaosKyun/Ciel

Principle: **"Understand before generating. Verify before claiming done."**

Ciel is installed as OpenCode-native primitives:

- **Plugin** (`.opencode/plugins/ciel.ts`) — pre/post-write hooks + depth classification on user prompts.
- **Subagents** (`.opencode/agents/ciel-*.md`) — dispatch with `@ciel-researcher`, `@ciel-explorer`, `@ciel-critic`, `@ciel-improver`.
- **Commands** (`.opencode/commands/ciel*.md`) — run with `/ciel`, `/ciel-improve`, `/ciel-refresh`, `/ciel-audit`, `/ciel-init`, `/ciel-eval`, `/ciel-create-skill`, `/ciel-recommend`, `/ciel-update`.

---

## Depth gauge — classify BEFORE starting

| Level | Example | Pipeline |
|-------|---------|----------|
| **Trivial** | rename, typo, 1-line fix | `quoi-framer` → `pattern-fitness-check` → `faire-gatekeeper` → inline review → push |
| **Standard** | hook, route, component, service | Full pipeline, dispatch `@ciel-researcher` + `@ciel-explorer` in parallel before coding |
| **Critical** | auth, DB schema, security, payment | Full pipeline + STRIDE threat model + `@ciel-critic` mandatory |

Unsure → Standard. Touching user data or auth → Critical.

---

## 10-step pipeline (condensed)

1. **QUOI** — 1-sentence goal + NOT-X + definition of done
2. **AVEC QUOI** — read installed versions (not memory), load overlay
3. **RECHERCHE** — `@ciel-researcher` (Standard+Critical): official docs + anti-patterns + version changelog
4. **SÉCURITÉ** — STRIDE + killer checklist (Critical only)
5. **CODEBASE + FLUX** — `@ciel-explorer`: pattern fitness + data flow narration
6. **ÉVALUER** — sizing + 2 failure modes + alternatives + counterfactual
7. **FAIRE** — test-first (RED), alternatives gate, idiomatic gate, removal gate
8. **RELIRE** — `@ciel-critic` MODE=RELIRE: 3 RISQUE (functional + imports + data) + FIX/ACCEPT/DEFER
9. **PROUVER** — AVANT/APRÈS evidence + CI gate + PR body + issue comment
10. **META** — 30s post-task reflection: depth match? failure mode? user correction?

---

## Top 10 Guards

1. "I already know this" = red flag — need research
2. Verify before asserting (no citation = don't know it)
3. DB columns: verify real schema before query
4. Test URL host:port must match handler host:port
5. Pattern copied blindly → fitness check fails
6. Self-critique in same context = same blind spots — dispatch `@ciel-critic`
7. No alternative considered = back to ÉVALUER
8. Scope drift at 3+ files → re-read QUOI
9. Write test FIRST (RED), not after
10. "No error in logs" ≠ proof — trigger scenario, see positive signal

---

## Agent dispatch rules

| Agent | When | Context | Permissions |
|-------|------|---------|-------------|
| `@ciel-researcher` | RECHERCHE step (Standard + Critical) | Isolated fork — no session bias | webfetch allowed, no edit |
| `@ciel-explorer` | CODEBASE + FLUX (Standard + Critical) | Isolated fork — reads codebase fresh | bash/read, no edit |
| `@ciel-critic` | RELIRE after FAIRE / CRITIQUER on diff | Isolated fork — different blind spots | bash/read, no edit |
| `@ciel-improver` | On `/ciel-improve` only | Extended token budget | webfetch allowed, no edit |

Dispatch `@ciel-researcher` + `@ciel-explorer` **IN PARALLEL** before writing code.

---

## Automatic context injection (plugin hooks)

The `ciel.ts` plugin injects depth classification on every user prompt and RELIRE reminders after every `Write`/`Edit` on code files. You don't need to remember to invoke Ciel — the plugin fires on the right events.

---

## MCP integration (opt-in)

Ciel ships a `.mcp.json` template at the repo root with two opt-in servers: `playwright` (visual critique) and `context7` (live official docs). Register them via:

```bash
bash ~/.claude/plugins/ciel/scripts/install.sh --with-mcp=playwright,context7
```

**Important** — OpenCode issue #2319: plugin hooks (`tool.execute.before/after`) do NOT fire for MCP tool calls. The `playwright-visual-critic` skill orchestrates the flow explicitly (navigate → snapshot → dispatch `@ciel-critic`) rather than relying on auto-triggered hooks. When you use a visual-critique workflow, dispatch the critic agent yourself after capture.
EOF
}

# Emit the OpenCode TS plugin (port of hooks/*.sh).
#
# API reference (verified against @opencode-ai/plugin/dist/index.d.ts):
#   - tool.execute.before(input, output: { args })            — CANNOT inject
#     model context. `output.args` is the tool arg object only; it's rewritten
#     into the tool call, never surfaced to the model. console.log here is
#     terminal-only and useless for reminders. Not used.
#   - tool.execute.after(input, output: { title, output, metadata })
#                                                             — CAN inject. The
#     `output.output` string is the tool result shipped to the model on its
#     next turn. Appending to it lands in the tool-call result part.
#   - experimental.chat.system.transform(input, output: { system: string[] })
#                                                             — CAN inject. Runs
#     every turn. Pushing to `output.system` adds a system-prompt segment for
#     that turn. This is the correct home for per-turn depth hints and
#     sticky RELIRE reminders.
#   - chat.params.output is { temperature, topP, topK, maxOutputTokens, options }
#     — NO `system` field. The previous implementation's
#     `output.system.push(hint)` was a silent no-op.
#
# `experimental.*` hooks are marked experimental by OpenCode; the API may
# shift. Keep the generator in one place so a re-spin is a single file edit.
emit_opencode_plugin() {
  local out="$1"
  # Inject the regex globals into the TS source so there is a single source of truth.
  cat > "$out" <<EOF
// Ciel — OpenCode plugin (v${CIEL_VERSION})
// Ported from hooks/*.sh (Claude Code). Pure TS, no shell dependency.
//
// Injection model (verified against @opencode-ai/plugin/dist/index.d.ts):
//   - experimental.chat.system.transform → push depth hint + sticky RELIRE
//     notice into the system-prompt array each turn. Both are visible to
//     the model on the following turn.
//   - tool.execute.after (write|edit)    → append a per-file FAIRE/RELIRE
//     reminder to the tool result string so the model reads it on its
//     next turn attached to that tool call.
//   - session.created (event)            → console banner only (no
//     model-visible injection needed at session start).
//
// Why not tool.execute.before? Its output shape is { args } only — no way
// to inject context, and console.log goes to terminal/plugin log, not the
// model.
//
// Why not chat.params? Its output has no \`system\` field; pushing to it
// is a silent no-op. Depth hints belong in experimental.chat.system.transform.
//
// The experimental.* hooks may shift between OpenCode releases. Regenerate
// this file with \`scripts/build-platforms.sh --target=opencode\` after any
// upstream plugin API change.

import type { Plugin } from "@opencode-ai/plugin";

const CODE_EXT_RE = /${CIEL_CODE_EXT_RE}/i;
const CRITICAL_FILE_RE = /${CIEL_CRITICAL_FILE_RE}/;
const CRITICAL_KEYWORD_RE = /${CIEL_CRITICAL_KEYWORD_RE}/i;
const TRIVIAL_KEYWORD_RE = /${CIEL_TRIVIAL_KEYWORD_RE}/i;

const ciel: Plugin = async ({ \$ }) => {
  // Per-session state. Reset when the plugin module is re-instantiated
  // (once per OpenCode session).
  const writtenFiles = new Set<string>();
  const remindedFiles = new Set<string>();
  let relireSticky = false; // once true, every turn re-injects the RELIRE notice
  let lastDepthHint: string | null = null;

  // Dispatch-gate counter (v2.5.1) — Claude Code parity. Per-session count
  // of inline bash|read|grep|glob calls; reset on task dispatch. At 5+ the
  // tool.execute.before hook throws to reject the next tool call AND
  // mutates output.args into an invalid form so the tool fails loud even
  // if throw-to-reject is swallowed by the runtime (defense in depth).
  //
  // Session key: best-effort from any input field that looks like a
  // session id; falls back to a single "__default" bucket if absent.
  // (input shape for tool.execute.* hooks is not fully documented; one
  // bucket means the counter is effectively global when no sessionID is
  // exposed — acceptable because OpenCode runs one session per plugin
  // module instance in practice.)
  const dispatchCounter = new Map<string, number>();
  const INLINE_GATHER_TOOLS = new Set(["bash", "read", "grep", "glob"]);
  const getSessionKey = (input: any): string =>
    input?.sessionID ?? input?.session_id ?? input?.sessionId ?? "__default";

  return {
    event: async ({ event }) => {
      if (event.type === "session.created") {
        // Terminal-only banner. Model context is handled by the transform hook.
        console.log("[CIEL] Session started — depth-aware reasoning active. Use /ciel, @ciel-researcher, @ciel-explorer, @ciel-critic.");
      }
    },

    // Per-turn system-prompt injection. This hook runs on every model turn
    // so we get a reliable "inject once per turn" surface without having to
    // manage cross-hook message state ourselves.
    "experimental.chat.system.transform": async (_input, output) => {
      if (lastDepthHint && Array.isArray(output?.system)) {
        output.system.push(lastDepthHint);
      }
      if (relireSticky && Array.isArray(output?.system)) {
        const changed = Array.from(writtenFiles);
        output.system.push(
          \`[CIEL RELIRE REQUIRED] \${changed.length} code files changed this session (\${changed.slice(0, 6).join(", ")}\${changed.length > 6 ? ", ..." : ""}). Dispatch @ciel-critic MODE=RELIRE — 3 RISQUES + FIX/ACCEPT/DEFER. Do not declare done before verdict.\`
        );
      }
    },

    // Full message-list transform — read the most recent user text and
    // reclassify depth every turn. Keeps lastDepthHint fresh; the actual
    // injection happens in the system.transform hook above.
    "experimental.chat.messages.transform": async (_input, output) => {
      const msgs = output?.messages;
      if (!Array.isArray(msgs) || msgs.length === 0) return;
      // Find the most recent user text part.
      let prompt = "";
      for (let i = msgs.length - 1; i >= 0 && !prompt; i--) {
        const m = msgs[i];
        if (m?.info?.role !== "user") continue;
        const parts = m?.parts;
        if (!Array.isArray(parts)) continue;
        for (let j = parts.length - 1; j >= 0; j--) {
          const p = parts[j];
          if (p?.type === "text" && typeof p.text === "string") {
            prompt = p.text;
            break;
          }
        }
      }
      if (!prompt) return;

      let depth: string | null = null;
      let reason = "";
      if (CRITICAL_KEYWORD_RE.test(prompt)) {
        depth = "Critical";
        reason = "auth/security/payment keyword detected";
      } else if (TRIVIAL_KEYWORD_RE.test(prompt)) {
        depth = "Trivial";
        reason = "rename/typo/docs keyword detected";
      }
      lastDepthHint = depth
        ? \`[CIEL] Depth: \${depth} (\${reason}). Route the pipeline accordingly.\`
        : null;
    },

    tool: {
      execute: {
        // Dispatch-gate counter (v2.5.1) — Claude Code parity. Throws at
        // N>=5 to reject the 6th+ inline bash|read|grep|glob call AND
        // mutates args to a clearly-invalid form so the tool fails loud
        // if the runtime swallows the throw. WARNING: OpenCode's
        // throw-from-before semantic is not formally documented — the
        // args mutation is the belt-and-suspenders fallback.
        before: async (input, output) => {
          if (!INLINE_GATHER_TOOLS.has(input.tool)) return;
          const sid = getSessionKey(input);
          const count = dispatchCounter.get(sid) ?? 0;
          if (count < 5) return;

          const msg = \`[CIEL HARD-STOP] Dispatch gate exceeded (\${count} inline calls without a Task() on a Standard+ task). Dispatch @ciel-researcher / @ciel-explorer / @ciel-critic now with [ASSUMED] markers for unresolved inputs. Further investigation belongs INSIDE the fork, not in the main session.\`;
          console.error(msg);
          // Belt: nullify the tool args so the tool call errors out if
          // throw is swallowed. OpenCode tool.execute.before output is
          // { args } — mutating it flows to the tool invocation.
          if (output && typeof output === "object") {
            (output as any).args = { __ciel_hardstop__: msg };
          }
          // Suspenders: throw to reject (assumed semantic).
          throw new Error(msg);
        },

        // Append FAIRE/RELIRE reminder to the tool result text. OpenCode's
        // tool.execute.after output is { title, output, metadata } — the
        // \`output\` field is the tool result string surfaced to the model.
        // Mutation here is the ONLY way to inject per-tool context.
        //
        // Also maintains the v2.5.1 dispatch-gate counter: increment on
        // bash|read|grep|glob, reset on task. Runs BEFORE the existing
        // write|edit branch; both paths are independent (same handler,
        // different early-return gates).
        after: async (input, output) => {
          // Counter maintenance — incremented on tool SUCCESS (post-hoc),
          // read by tool.execute.before next time around.
          const sid = getSessionKey(input);
          if (input.tool === "task") {
            dispatchCounter.delete(sid);
            return;
          }
          if (INLINE_GATHER_TOOLS.has(input.tool)) {
            dispatchCounter.set(sid, (dispatchCounter.get(sid) ?? 0) + 1);
            return;
          }

          if (!["write", "edit"].includes(input.tool)) return;
          const args: any = (input as any).args ?? {};
          const filePath: string = args.file_path ?? args.path ?? "";
          if (!filePath || !CODE_EXT_RE.test(filePath)) return;

          writtenFiles.add(filePath);

          const isCritical = CRITICAL_FILE_RE.test(filePath);
          if (writtenFiles.size >= 3 || isCritical) {
            relireSticky = true;
          }

          // Per-file FAIRE reminder fires once per path to avoid burning
          // ~50 tokens × N edits on the same file.
          if (remindedFiles.has(filePath)) return;
          remindedFiles.add(filePath);

          const reminder = isCritical
            ? \`\\n\\n[CIEL CRITIQUE] \${filePath} — FAIRE gates + stride-analyzer + flux-narrator + test-first (RED). Dispatch @ciel-critic MODE=RELIRE before declaring done.\`
            : \`\\n\\n[CIEL] \${filePath} — FAIRE gates: alternatives, idiomatic, test-first. Ensure @ciel-researcher + @ciel-explorer ran.\`;

          if (typeof output?.output === "string") {
            output.output += reminder;
          } else if (output) {
            // Defensive: if output.output is missing/nullish, create it so
            // the reminder still lands on the model.
            (output as any).output = reminder.trimStart();
          }
        },
      },
    },
  };
};

export default ciel;
EOF
}

# Emit the opencode.json that registers the plugin + AGENTS.md.
emit_opencode_config() {
  local out="$1"
  cat > "$out" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["AGENTS.md"],
  "plugin": ["./.opencode/plugins/ciel.ts"]
}
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

# Check aggregate byte size of all *.md files in a directory.
check_total_size() {
  local dir="$1"
  local limit="$2"
  local platform="$3"
  local total=0 count=0
  for f in "$dir"/*.md; do
    [[ -f "$f" ]] || continue
    local s; s=$(wc -c < "$f")
    total=$((total + s))
    count=$((count + 1))
  done
  if [[ $total -gt $limit ]]; then
    echo "  ✗ $platform — $count files total $total bytes > $limit byte limit" >&2
    return 1
  fi
  echo "  ✓ $platform — $count files total $total bytes (under $limit)"
  return 0
}

# ============================================================================
# Shared skill bundle emitter — platform-agnostic.
# Emits "## Skills invoked (bundled inline)" section for a given role.
# Used by emit_opencode_agent, emit_codex_agent, emit_windsurf_agent_skill,
# emit_kilo_agent — avoids duplicating 100+ lines of bundle logic.
# ============================================================================
_emit_agent_bundled_skills() {
  local role="$1"
  echo ""
  echo "---"
  echo ""
  echo "## Skills invoked (bundled inline)"
  echo ""
  echo "> The following skills are referenced in the process above but do not exist"
  echo "> as platform-native primitives. Each skill below is a complete procedure;"
  echo "> follow its steps inline to execute the skill."

  case "$role" in
    researcher)
      bundle_skills_inline \
        "$SKILLS/research/research-web-sources/SKILL.md" \
        "$SKILLS/research/research-github-issues/SKILL.md" \
        "$SKILLS/research/research-forums/SKILL.md" \
        "$SKILLS/research/validate-source-credibility/SKILL.md" \
        "$SKILLS/research/synthesize-findings/SKILL.md" \
        "$SKILLS/research/fact-check-claims/SKILL.md" \
        "$SKILLS/workflow/doc-validator-official/SKILL.md"
      ;;
    explorer)
      bundle_skills_inline \
        "$SKILLS/workflow/pattern-fitness-check/SKILL.md" \
        "$SKILLS/workflow/flux-narrator/SKILL.md" \
        "$SKILLS/workflow/modern-patterns-checker/SKILL.md" \
        "$SKILLS/workflow/ai-failure-modes-detector/SKILL.md"

      echo ""
      echo "---"
      echo ""
      echo "## Conditional workflow skills (compact — invoke when triggers match)"
      echo ""
      bundle_skills_compact \
        "$SKILLS/workflow/test-strategy-vitest-playwright/SKILL.md" \
        "$SKILLS/workflow/playwright-visual-critic/SKILL.md"

      echo ""
      echo "---"
      echo ""
      echo "## Domain skills (compact — one dispatched IN PARALLEL based on stack signals)"
      echo ""
      echo "> Match the detected stack to the skill whose \`paths\` glob applies, then apply its checks."
      bundle_skills_compact \
        "$SKILLS/domain/frontend-mastery/SKILL.md" \
        "$SKILLS/domain/backend-mastery/SKILL.md" \
        "$SKILLS/domain/database-mastery/SKILL.md" \
        "$SKILLS/domain/security-hardening/SKILL.md" \
        "$SKILLS/domain/api-architecture/SKILL.md" \
        "$SKILLS/domain/observability/SKILL.md" \
        "$SKILLS/domain/performance-engineering/SKILL.md" \
        "$SKILLS/domain/refactoring-patterns/SKILL.md" \
        "$SKILLS/domain/cicd-security-hardener/SKILL.md" \
        "$SKILLS/domain/accessibility-wcag-auditor/SKILL.md"
      ;;
    critic)
      bundle_skills_inline \
        "$SKILLS/workflow/relire-critic/SKILL.md" \
        "$SKILLS/workflow/critiquer-auditor/SKILL.md" \
        "$SKILLS/workflow/stride-analyzer/SKILL.md" \
        "$SKILLS/workflow/security-regression-check/SKILL.md" \
        "$SKILLS/workflow/debug-reasoning-rca/SKILL.md" \
        "$SKILLS/workflow/self-consistency-verifier/SKILL.md"
      ;;
    improver)
      bundle_skills_inline \
        "$SKILLS/meta/ciel-improve/SKILL.md" \
        "$SKILLS/meta/skill-creator/SKILL.md" \
        "$SKILLS/meta/skill-variant-evaluator/SKILL.md" \
        "$SKILLS/meta/learnings-capture/SKILL.md" \
        "$SKILLS/meta/skills-first-design-auditor/SKILL.md"
      ;;
  esac
}

# ============================================================================
# Windsurf-specific helpers
# ============================================================================

# Emit the Ciel orchestrator as a Windsurf skill (source: skills/ciel/SKILL.md).
emit_windsurf_ciel_skill() {
  local out="$1"
  local desc
  desc=$(skill_yaml_field "$SKILLS/ciel/SKILL.md" "description")
  [[ -z "$desc" ]] && desc="Deep-reasoning coding orchestrator — classify depth, route pipeline, invoke @ciel-* skills."
  mkdir -p "$(dirname "$out")"
  {
    echo "---"
    echo "name: ciel"
    echo "description: $desc"
    echo "---"
    echo ""
    strip_yaml "$SKILLS/ciel/SKILL.md"
  } > "$out"
}

# Emit a Windsurf agent skill file (name+description frontmatter, skills bundled inline).
# Usage: emit_windsurf_agent_skill <source_agent_md> <out_path> <role>
emit_windsurf_agent_skill() {
  local src="$1"
  local out="$2"
  local role="$3"

  local name desc
  name="ciel-$role"
  desc=$(skill_yaml_field "$src" "description")
  [[ -z "$desc" ]] && desc=$(grep '^# ' "$src" | head -1 | sed 's/^# *//')
  [[ -z "$desc" ]] && desc="Ciel $role — isolated-context subagent"

  mkdir -p "$(dirname "$out")"
  {
    echo "---"
    echo "name: $name"
    echo "description: $desc"
    echo "---"
    echo ""
    strip_yaml "$src"
    _emit_agent_bundled_skills "$role"
  } > "$out"
}

# Emit a Windsurf workflow file from a source command/skill .md.
# Usage: emit_windsurf_workflow <source_md> <out_path>
emit_windsurf_workflow() {
  local src="$1"
  local out="$2"
  local name; name=$(basename "$out" .md)

  local desc
  desc=$(sed -n '1,3p' "$src" | grep -oE '^\*.*\*$' | head -1 | sed 's/^\*//; s/\*$//' 2>/dev/null || true)
  if [[ -z "$desc" ]]; then
    desc=$(grep '^# ' "$src" | head -1 | sed 's/^# *//' 2>/dev/null || true)
  fi
  [[ -z "$desc" ]] && desc="Ciel workflow: $name"

  local desc_from_yaml
  desc_from_yaml=$(skill_yaml_field "$src" "description")
  [[ -n "$desc_from_yaml" ]] && desc="$desc_from_yaml"

  mkdir -p "$(dirname "$out")"
  {
    echo "---"
    echo "name: $name"
    echo "description: $desc"
    echo "---"
    echo ""
    strip_yaml "$src"
  } > "$out"
}

# Emit a thin Windsurf workflow wrapper that invokes the named Ciel skill.
# Usage: emit_windsurf_workflow_wrapper <out_path> <skill_name> <description>
emit_windsurf_workflow_wrapper() {
  local out="$1"
  local skill_name="$2"
  local desc="$3"
  mkdir -p "$(dirname "$out")"
  {
    echo "---"
    echo "name: $skill_name"
    echo "description: $desc"
    echo "---"
    echo ""
    echo "Invoke the \`$skill_name\` skill with the user's arguments:"
    echo ""
    echo '```'
    echo '$ARGUMENTS'
    echo '```'
    echo ""
    echo "If \`\$ARGUMENTS\` is empty, invoke the skill with no argument — it will classify the current context."
    echo ""
    echo "The full logic (depth classifier, intent routing, pipeline selection) lives in the \`$skill_name\` skill. Modify the skill, not this workflow, to change behavior."
  } > "$out"
}

# ============================================================================
# Codex-specific helpers
# ============================================================================

# Emit a compact AGENTS.md for Codex (≤32KB) pointing to .codex/ primitives.
emit_codex_agents_md() {
  local out="$1"
  echo "# AGENTS.md — Ciel deep-reasoning workflow (Codex, v${CIEL_VERSION})" > "$out"
  cat >> "$out" <<'EOF'

Source: https://github.com/KaosKyun/Ciel

Principle: **"Understand before generating. Verify before claiming done."**

Ciel is installed as Codex-native primitives:

- **Hook** (`.codex/hooks.json`) — `UserPromptSubmit` injects depth-classification hint into every prompt.
- **Subagents** (`.codex/agents/ciel-*.md`) — spawn with `@ciel-researcher`, `@ciel-explorer`, `@ciel-critic`, `@ciel-improver`.
- **Commands** (`.codex/commands/ciel*.md`) — invoke with `/ciel`, `/ciel-improve`, `/ciel-eval`, `/ciel-create-skill`, `/ciel-recommend`, `/ciel-update`.

---

## Depth gauge — classify BEFORE starting

| Level | Example | Pipeline |
|-------|---------|----------|
| **Trivial** | rename, typo, 1-line fix | quoi-framer → pattern-fitness-check → faire-gatekeeper → inline review → push |
| **Standard** | hook, route, component, service | Full pipeline, spawn @ciel-researcher + @ciel-explorer in parallel before coding |
| **Critical** | auth, DB schema, security, payment | Full pipeline + STRIDE threat model + @ciel-critic mandatory |

Unsure → Standard. Touching user data or auth → Critical.

---

## 10-step pipeline (condensed)

1. **QUOI** — 1-sentence goal + NOT-X + definition of done
2. **AVEC QUOI** — read installed versions (not memory), load overlay
3. **RECHERCHE** — `@ciel-researcher` (Standard+Critical): official docs + anti-patterns + version changelog
4. **SÉCURITÉ** — STRIDE + killer checklist (Critical only)
5. **CODEBASE + FLUX** — `@ciel-explorer`: pattern fitness + data flow narration
6. **ÉVALUER** — sizing + 2 failure modes + alternatives + counterfactual
7. **FAIRE** — test-first (RED), alternatives gate, idiomatic gate, removal gate
8. **RELIRE** — `@ciel-critic` MODE=RELIRE: 3 RISQUE (functional + imports + data) + FIX/ACCEPT/DEFER
9. **PROUVER** — AVANT/APRÈS evidence + CI gate + PR body + issue comment
10. **META** — 30s post-task reflection: depth match? failure mode? user correction?

---

## Top 10 Guards

1. "I already know this" = red flag — research first
2. Verify before asserting — no citation = don't know it
3. DB columns: verify real schema before query
4. Test URL host:port must match handler host:port
5. Pattern copied blindly → fitness check fails
6. Self-critique in same context = same blind spots → spawn @ciel-critic
7. No alternative considered → back to ÉVALUER
8. Scope drift at 3+ files → re-read QUOI
9. Write test FIRST (RED), not after
10. "No error in logs" ≠ proof — trigger scenario, see positive signal

---

## Automatic context injection (hook)

The `.codex/hooks.json` `UserPromptSubmit` hook classifies depth from your prompt and appends a hint via `additionalContext`. The hint fires on every prompt — you don't need to invoke Ciel manually.
EOF
}

# Emit Codex hooks — hooks.json + user-prompt-submit.sh.
# Schema verified: developers.openai.com/codex/hooks (April 2026).
# Three-level structure: event → matcher-group → handlers[].
# UserPromptSubmit stdin: { session_id, turn_id, prompt, cwd, hook_event_name, model, transcript_path }
# Augment: respond with { "additionalContext": "..." }
# Block: exit 2 with message on stderr (or { "decision": "block", "reason": "..." })
emit_codex_hooks() {
  local out_dir="$1"

  cat > "$out_dir/hooks.json" <<'EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".codex/hooks/user-prompt-submit.sh",
            "statusMessage": "Ciel depth-classification gate"
          }
        ]
      }
    ]
  }
}
EOF

  cat > "$out_dir/hooks/user-prompt-submit.sh" <<'HOOKEOF'
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
HOOKEOF
  chmod +x "$out_dir/hooks/user-prompt-submit.sh"
}

# Emit a Codex agent file: description-only frontmatter + agent body + bundled skills.
# Usage: emit_codex_agent <source_agent_md> <out_path> <role>
emit_codex_agent() {
  local src="$1"
  local out="$2"
  local role="$3"

  local desc
  desc=$(skill_yaml_field "$src" "description")
  [[ -z "$desc" ]] && desc=$(grep '^# ' "$src" | head -1 | sed 's/^# *//')
  [[ -z "$desc" ]] && desc="Ciel $role — isolated-context subagent"

  mkdir -p "$(dirname "$out")"
  {
    echo "---"
    echo "description: $desc"
    echo "---"
    echo ""
    strip_yaml "$src"
    _emit_agent_bundled_skills "$role"
  } > "$out"
}

# ============================================================================
# Kilo Code-specific helpers
# ============================================================================

# Emit a compact AGENTS.md for Kilo Code (≤6KB).
emit_kilo_agents_md() {
  local out="$1"
  echo "# AGENTS.md — Ciel deep-reasoning workflow (Kilo Code, v${CIEL_VERSION})" > "$out"
  cat >> "$out" <<'EOF'

Source: https://github.com/KaosKyun/Ciel

Principle: **"Understand before generating. Verify before claiming done."**

Ciel is installed as Kilo Code-native primitives:

- **Rules** (`.kilocode/rules/ciel.md`) — always-on depth guards + prose hook equivalents.
- **Subagents** (`.kilo/agents/ciel-*.md`) — invoke with `@ciel-researcher`, `@ciel-explorer`, `@ciel-critic`, `@ciel-improver`.
- **No hooks** — pre/post-write behavior is documented as prose guards in the rules file.

---

## Depth gauge

| Level | Example | Pipeline |
|-------|---------|----------|
| **Trivial** | rename, typo, 1-line fix | quoi-framer → pattern-fitness-check → inline review → push |
| **Standard** | hook, route, component | Full pipeline, dispatch @ciel-researcher + @ciel-explorer in parallel |
| **Critical** | auth, DB schema, security | Full pipeline + STRIDE + @ciel-critic mandatory |

---

## 10-step pipeline (condensed)

1. QUOI — 1-sentence goal + NOT-X + definition of done
2. AVEC QUOI — real installed versions (not memory)
3. RECHERCHE — `@ciel-researcher` (Standard+Critical)
4. SÉCURITÉ — STRIDE (Critical only)
5. CODEBASE + FLUX — `@ciel-explorer`
6. ÉVALUER — sizing + 2 failure modes + alternatives
7. FAIRE — test-first (RED); alternatives gate; idiomatic gate
8. RELIRE — `@ciel-critic` MODE=RELIRE: 3 RISQUE + FIX/ACCEPT/DEFER
9. PROUVER — AVANT/APRÈS evidence + CI gate
10. META — 30s reflection

---

## Dispatch rules

| Agent | When |
|-------|------|
| `@ciel-researcher` | RECHERCHE (Standard+Critical) — isolated, no session bias |
| `@ciel-explorer` | CODEBASE+FLUX (Standard+Critical) — reads codebase fresh |
| `@ciel-critic` | RELIRE after FAIRE (Critical always; Standard if 3+ files or auth/security) |
| `@ciel-improver` | On `/ciel-improve` only |

Dispatch `@ciel-researcher` + `@ciel-explorer` **IN PARALLEL** before writing code.
EOF
}

# Emit a compact rules file for Kilo Code (≤6KB) — principle + guards + prose hooks.
emit_kilo_rules() {
  local out="$1"
  cat > "$out" <<'EOF'
# Ciel — Rules (Kilo Code)

Principle: **"Understand before generating. Verify before claiming done."**

---

## Top 10 Guards

1. "I already know this" = red flag — research first before asserting
2. No citation = don't know it — verify via @ciel-researcher
3. DB columns: verify real schema before writing a query
4. Test URL host:port must match handler host:port
5. Pattern copied blindly → fitness check fails → adapt or reject
6. Self-critique in same context = same blind spots → dispatch @ciel-critic
7. No alternative considered → back to ÉVALUER step
8. Scope drift at 3+ files → re-read QUOI goal statement
9. Write test FIRST (RED) — test after is too late to catch design flaws
10. "No error in logs" ≠ proof — trigger the scenario, see a positive signal

---

## Prose hook equivalents (Kilo Code has no native hooks)

**On every code file write** (auth|security|Route|Service|Controller|Repository|Gateway|Middleware):
→ Pause. Dispatch `@ciel-critic MODE=RELIRE` before declaring done.
→ Do NOT mark the task complete without a critic verdict.

**When 3+ code files changed in a session:**
→ Dispatch `@ciel-critic MODE=RELIRE` — same-context critique = same blind spots.

**On session start:**
→ Read `ciel-overlay.md` (if present) for project-specific stack, versions, rules.
→ Read `AGENTS.md` for the full 10-step pipeline.

**Before using any external library or API:**
→ Dispatch `@ciel-researcher` to verify current docs — "I already know the API" is a red flag.

---

## Depth quick-reference

- **Trivial**: rename, typo, comment, 1-line fix → skip RECHERCHE + STRIDE
- **Standard**: hook, route, component, service → RECHERCHE + CODEBASE required
- **Critical**: auth, DB schema, security, payment → all 10 steps + STRIDE mandatory

Unsure → Standard. Touching user data or auth → Critical.
EOF
}

# Emit a Kilo Code agent file: Kilo-specific frontmatter + agent body + bundled skills.
# Kilo frontmatter: description, mode: subagent, step_limits: 20
# Usage: emit_kilo_agent <source_agent_md> <out_path> <role>
emit_kilo_agent() {
  local src="$1"
  local out="$2"
  local role="$3"

  local desc
  desc=$(skill_yaml_field "$src" "description")
  [[ -z "$desc" ]] && desc=$(grep '^# ' "$src" | head -1 | sed 's/^# *//')
  [[ -z "$desc" ]] && desc="Ciel $role — isolated-context subagent"

  mkdir -p "$(dirname "$out")"
  {
    echo "---"
    echo "description: $desc"
    echo "mode: subagent"
    echo "step_limits: 20"
    echo "---"
    echo ""
    strip_yaml "$src"
    _emit_agent_bundled_skills "$role"
  } > "$out"
}

if $CHECK_ONLY; then
  echo "Check mode: validating existing platform files..."
  errors=0

  # Cursor
  check_size "$PLATFORMS/cursor/.cursor/rules/ciel.mdc" "$(limit_for cursor)" "cursor" || errors=$((errors + 1))

  # Windsurf — native: skills + workflows + rules
  for skill_f in "$PLATFORMS/windsurf"/.windsurf/skills/*/SKILL.md; do
    [[ -f "$skill_f" ]] || continue
    check_size "$skill_f" "$(limit_for windsurf_skill)" "windsurf-skill:$(basename "$(dirname "$skill_f")")" || errors=$((errors + 1))
  done
  for wf_f in "$PLATFORMS/windsurf"/.windsurf/workflows/*.md; do
    [[ -f "$wf_f" ]] || continue
    check_size "$wf_f" "$(limit_for windsurf_workflow)" "windsurf-workflow:$(basename "$wf_f")" || errors=$((errors + 1))
  done
  [[ -f "$PLATFORMS/windsurf/.windsurf/rules/ciel.md" ]] && \
    check_size "$PLATFORMS/windsurf/.windsurf/rules/ciel.md" "$(limit_for windsurf_rule)" "windsurf-rule" || errors=$((errors + 1))
  check_total_size "$PLATFORMS/windsurf/.windsurf/rules" "$(limit_for windsurf_rules_total)" "windsurf-rules-total" || errors=$((errors + 1))

  # Codex — native: AGENTS.md + .codex/agents + .codex/commands
  [[ -f "$PLATFORMS/codex/AGENTS.md" ]] && \
    check_size "$PLATFORMS/codex/AGENTS.md" "$(limit_for codex)" "codex-agents-md" || errors=$((errors + 1))
  for a in "$PLATFORMS/codex"/.codex/agents/*.md; do
    [[ -f "$a" ]] || continue
    check_size "$a" "$(limit_for codex_agent)" "codex-agent:$(basename "$a")" || errors=$((errors + 1))
  done
  for c in "$PLATFORMS/codex"/.codex/commands/*.md; do
    [[ -f "$c" ]] || continue
    check_size "$c" "$(limit_for codex_command)" "codex-command:$(basename "$c")" || errors=$((errors + 1))
  done

  # OpenCode — native primitives
  if [[ -d "$PLATFORMS/opencode" ]]; then
    check_size "$PLATFORMS/opencode/AGENTS.md" "$(limit_for opencode_agents_md)" "opencode-agents-md" || errors=$((errors + 1))
    [[ -f "$PLATFORMS/opencode/.opencode/plugins/ciel.ts" ]] && \
      check_size "$PLATFORMS/opencode/.opencode/plugins/ciel.ts" "$(limit_for opencode_plugin)" "opencode-plugin" || errors=$((errors + 1))
    for a in "$PLATFORMS/opencode"/.opencode/agents/*.md; do
      [[ -f "$a" ]] || continue
      check_size "$a" "$(limit_for opencode_agent)" "opencode-agent:$(basename "$a")" || errors=$((errors + 1))
    done
    for c in "$PLATFORMS/opencode"/.opencode/commands/*.md; do
      [[ -f "$c" ]] || continue
      check_size "$c" "$(limit_for opencode_command)" "opencode-command:$(basename "$c")" || errors=$((errors + 1))
    done
  fi

  # Kilo — native: AGENTS.md + rules + .kilo/agents
  [[ -f "$PLATFORMS/kilocode/AGENTS.md" ]] && \
    check_size "$PLATFORMS/kilocode/AGENTS.md" "$(limit_for kilo_agents_md)" "kilo-agents-md" || errors=$((errors + 1))
  [[ -f "$PLATFORMS/kilocode/.kilocode/rules/ciel.md" ]] && \
    check_size "$PLATFORMS/kilocode/.kilocode/rules/ciel.md" "$(limit_for kilo_rule)" "kilo-rule" || errors=$((errors + 1))
  for a in "$PLATFORMS/kilocode"/.kilo/agents/*.md; do
    [[ -f "$a" ]] || continue
    check_size "$a" "$(limit_for kilo_agent)" "kilo-agent:$(basename "$a")" || errors=$((errors + 1))
  done

  exit $errors
fi

# Rebuild — only wipe the targeted platform(s) so partial rebuilds don't
# destroy the output of other platforms.
purge_target() {
  local name="$1"
  case "$name" in
    cursor)   rm -rf "$PLATFORMS/cursor"   ;;
    windsurf) rm -rf "$PLATFORMS/windsurf" ;;
    codex)    rm -rf "$PLATFORMS/codex"    ;;
    opencode) rm -rf "$PLATFORMS/opencode" ;;
    kilo)     rm -rf "$PLATFORMS/kilocode" ;;
    ollama)   rm -rf "$PLATFORMS/ollama"   ;;
    lmstudio) rm -rf "$PLATFORMS/lmstudio" ;;
  esac
}

mkdir -p "$PLATFORMS"

case "$TARGET" in
  cursor)   purge_target cursor   && build_cursor   ;;
  windsurf) purge_target windsurf && build_windsurf ;;
  codex)    purge_target codex    && build_codex    ;;
  opencode) purge_target opencode && build_opencode ;;
  kilo)     purge_target kilo && build_kilo ;;
  ollama)   purge_target ollama   && build_ollama   ;;
  lmstudio) purge_target lmstudio && build_lmstudio ;;
  all)
    rm -rf "$PLATFORMS"
    mkdir -p "$PLATFORMS"
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
