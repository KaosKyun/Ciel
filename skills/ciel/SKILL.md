---
name: ciel
description: Deep-reasoning orchestrator for coding tasks. Classifies task depth (Trivial/Standard/Critical) and routes to specialized skills across workflow/research/domain/utility categories. Use when starting any non-trivial coding task, when the user types /ciel, or when depth-aware reasoning is needed before implementing. Enforces "Understand before generating. Verify before claiming done."
---

# Ciel — Skills-first Orchestrator

Named after the Primordial Sage from *Tensei Shitara Slime Datta Ken* — the advisor who reasons at infinite speed before Rimuru acts.

Principle: **"Understand before generating. Verify before claiming done."**

This orchestrator is thin on purpose. It classifies the task, then routes to specialized skills. It does NOT replicate their content — each workflow step is its own skill.

For full philosophy, guards table, and the research basis behind Ciel, see `reference.md`.

---

## Depth Gauge — classify BEFORE starting

| Level | Example | Pipeline |
|-------|---------|----------|
| **Trivial** | rename, typo, 1-line fix | `quoi-framer` → `pattern-fitness-check` → `faire-gatekeeper` → `relire-critic` (inline) → push |
| **Standard** | hook, route, component, service | Full pipeline minus `stride-analyzer` + `security-regression-check` |
| **Critical** | auth, DB schema, security, payment | Full pipeline including `stride-analyzer` + `security-regression-check` |

Unsure → Standard. Touching user data or auth → Critical.

Invoke `depth-classifier` if classification is ambiguous (mechanical signals: `auth/`, `security/`, DB table names, diff size, route handlers).

---

## Pipeline — skills to invoke per depth

### Trivial
1. `quoi-framer` — frame goal + NOT-X + definition of done
2. `pattern-fitness-check` — 3-question fitness on any pattern considered
3. `faire-gatekeeper` — enforce FAIRE gates during coding
4. `relire-critic` (inline, no agent fork) — 3 RISQUE + checklist
5. Push, verify no regression
6. `meta-critiquer` — 30s post-task reflection

### Standard (dispatch researcher + explorer IN PARALLEL before FAIRE)

1. `quoi-framer`
2. `avec-quoi-versioner` — read real installed versions, load overlay
3. **researcher agent** → `research-web-sources` + `research-github-issues` + `validate-source-credibility` + `synthesize-findings` + `fact-check-claims`
4. **explorer agent** → `pattern-fitness-check` + `flux-narrator` + domain skill parallel (e.g. `frontend-mastery` when React detected)
5. `evaluer-sizer` — sizing + pre-mortem + recent-churn + alternative + counterfactual
6. `faire-gatekeeper` during coding
7. **critic agent** MODE=RELIRE → `relire-critic` (if 3+ files OR auth/security; else inline)
8. `prouver-verifier` — AVANT/APRÈS evidence + CI gate + PR body gate + issue comment gate + closure gate + staging-verifier
9. `meta-critiquer`

### Critical (all of Standard, PLUS)

- `stride-analyzer` after `avec-quoi-versioner` (PASSE 1 RISK-RANK + PASSE 2 STRIDE + PASSE 3 KILLER CHECKLIST)
- `security-regression-check` between `faire-gatekeeper` and `relire-critic` (attacker eyes on the diff)
- **critic agent** is MANDATORY (no inline fallback)

---

## CRITIQUER mode — when reviewing or auditing existing code

Invoke `critiquer-auditor` directly. It runs the full 7-step audit: `APPRENDRE → COMPRENDRE → QUESTIONNER → COMPARER → COHÉRENCE → SIGNALER → CAPITALISER`.

For a PR/diff review specifically, dispatch the **critic agent** with MODE=CRITIQUER — it routes to `critiquer-auditor` in an isolated context.

---

## Agent dispatch rules

| Agent | Step | Context | Mandatory |
|-------|------|---------|-----------|
| `researcher` | RECHERCHE | Isolated fork — no session bias | Standard + Critical |
| `explorer` | CODEBASE + FLUX | Isolated fork — reads codebase fresh | Standard + Critical |
| `critic` | RELIRE or CRITIQUER | Isolated fork — different blind spots | Critical always; Standard if 3+ files OR auth/security |
| `improver` | Self-improvement (long-running) | Isolated fork — extended token budget | On `/ciel-improve` |

Dispatch `researcher` + `explorer` **IN PARALLEL** before FAIRE.
Dispatch `critic` after FAIRE.
Each agent dispatch costs ~850K tokens on average — reserve accordingly.

**Report quality check**: agent report < 200 tokens on Standard task → suspect truncation. Re-dispatch with narrower scope before proceeding.

---

## Context budget — throughout all steps

| Usage | Signal | Action |
|-------|--------|--------|
| < 50% | Comfortable | Normal depth |
| 50–70% | Caution | Prefer `grep`/signatures over full file reads |
| > 70% | Pressure | No new agents; compress agent prompts |
| > 85% | Critical | Finish current step, commit, open new session |

Lazy reading: `grep -n "^fun \|^class \|^interface \|^object " <file>` before full file read.
Never read the same file twice in a session — note a pointer after first read.
Observation masking: tool outputs from > 3 turns ago that weren't referenced → replace with `[MASKED: ref step X]`.

---

## Self-improvement — Ciel modifies Ciel

Ciel can create and improve its own skills through the `meta/` subsystem:

- `/ciel-improve` → invokes `improver` agent → `ciel-improve` skill → produces patch-set for user approval (never autonomous rewrite)
- `/ciel-eval [skill-name]` → `skill-variant-evaluator` runs binary evals on 2-3 variants, winner = highest aggregate score (tiebreak: lowest token usage)
- `/ciel-create-skill <name> <purpose>` → `skill-creator` generates a valid SKILL.md scaffold
- Session-end hooks (`Stop`, `PreCompact`) → `learnings-capture` appends user corrections to `.claude/learnings.md` or `ciel-overlay.md`

---

## ÉVOLUER — closed feedback loop

- Per-task: `meta-critiquer` (30s) → update Guards or overlay
- Per-session: patterns → new Guards or overlay rules via `learnings-capture`
- Per-month: prune Guards that never fire; check overlay drift; CHANGELOG fix/revert ratio
- Anti-entropy rule: every addition must simplify OR catch a real failure. If neither → reject.

Track fix/revert ratio per version in `CHANGELOG.md` — improvement must be measurable. Baseline (v1.x monolithic): 62.8%.
