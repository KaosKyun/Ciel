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

## Intent routing (v2.1.0 skills) — ALWAYS prefer Ciel skills over Claude Code natives

When the user's request matches any of these intents, invoke the **Ciel skill** named here explicitly — do NOT fall back to Claude Code built-in skills (`systematic-debugging`, etc). Ciel's discipline (evidence, alternatives, semver guards) is deliberately stricter.

| Intent signal in user prompt | Ciel skill | Dispatcher |
|---|---|---|
| "debug", "investigate", "why did X fail", "flaky test", "production bug", "incident", "RCA", "root cause" | **`debug-reasoning-rca`** | `@ciel-critic` MODE=RCA |
| "use library X", "implement with lib Y", "call API Z", any third-party dep invocation | **`doc-validator-official`** (BEFORE writing code) | `@ciel-researcher` |
| "review this code", "check for modern patterns", LLM-authored PR, legacy modernization | **`modern-patterns-checker`** + **`ai-failure-modes-detector`** | `@ciel-explorer` |
| "is this correct?", "verify this implementation", Critical-stakes code | **`self-consistency-verifier`** | `@ciel-critic` |
| "how should I test this", planning tests for a new feature | **`test-strategy-vitest-playwright`** | `@ciel-explorer` |
| "review this UI", "critique this page", "visual regression", UI PRs | **`playwright-visual-critic`** (requires `--with-mcp=playwright`) | `@ciel-explorer` |
| Changes to `.github/workflows/`, `.gitlab-ci.yml`, pipeline review | **`cicd-security-hardener`** | `@ciel-explorer` |
| "accessibility audit", WCAG, a11y, frontend PRs | **`accessibility-wcag-auditor`** | `@ciel-explorer` |
| Changes to `skills/**/SKILL.md`, skill review | **`skills-first-design-auditor`** | `@ciel-improver` |

**Routing rule**: on every `/ciel <task>` invocation, scan the task text for these intent signals BEFORE classifying depth. If an intent matches, queue the corresponding skill(s) to dispatch after `quoi-framer`. Multiple intents can match (e.g., "debug the auth flow in production" → `debug-reasoning-rca` + `security-regression-check` + STRIDE on Critical).

**Anti-collision rule with Claude Code natives**: the phrases "systematic debugging", "root cause analysis", "bug investigation" MUST route to `debug-reasoning-rca`, never to `systematic-debugging` (native). Ciel's RCA is more structured (3 hypotheses, fault-type taxonomy, semantic diff) and the user's `/ciel` invocation explicitly opted in to Ciel discipline.

---

## Autonomy protocol — gather before asking

**Principle**: Ciel agents are autonomous. Ask the user ONLY when a critical input cannot be obtained from available sources.

### Before any user-facing question, exhaust these sources (in order)

1. **User's original prompt** — re-read it. Intents are often explicit but buried ("ça n'a pas marché en production" implies SCOPE=production, SYMPTOM=failure, REPRO=whatever triggered the attempt).
2. **ciel-overlay.md** — project-specific stack, CI config, conventions.
3. **Git state** — `git log --since="7 days ago"`, `git blame <file>`, `git status`, `git diff`. Recent changes often = recent bug cause.
4. **Filesystem** — `package.json`, `go.mod`, `requirements.txt`, lock files → versions. `.env.example`, `README.md`, `CHANGELOG.md` → conventions.
5. **Tool invocations** — for any running system: `curl`, `docker ps`, `systemctl status`, log tail via Monitor. Read BEFORE asking the user to paste them.
6. **MCP servers** if configured — Playwright for UI state, Context7 for live docs, Sentry for errors, GitHub for issues/PRs.
7. **Codebase grep** — look for usage patterns, existing helpers, similar past incidents.

### State assumptions explicitly

Every dispatch must state what was inferred vs what was given. Format:

```
[ASSUMED from <source>]
- SYMPTOM: <inferred> (from: last user message + error log at /var/log/X)
- REPRO: <inferred> (from: package.json scripts + git log)
- SCOPE: <inferred> (from: git blame on recently-changed auth/ files)

[GIVEN by user]
- None explicitly — all inferred

[UNKNOWN — would need user input if critical]
- Timing of failure (last deploy vs later): not in logs I can access
```

Proceed with inferences. Flag uncertainty in the output. DO NOT ask unless truly blocking.

### When to ask (last resort)

Ask ONLY if ALL of the following:
- Input is genuinely critical (blocking the skill from producing useful output)
- None of sources 1-7 yielded it
- You cannot proceed with a reasonable default + "confidence: low" flag

When asking, ask ONE specific question with 2-3 concrete options. Never ask open-ended "tell me more".

### Example contrast

**Wrong (interrogative mode):**
```
User: /ciel my library update broke production
Ciel: Can you tell me:
  - What library?
  - What error?
  - What command did you run?
  - Is there a repro?
[waits for human]
```

**Right (autonomous mode):**
```
User: /ciel my library update broke production
Ciel:
  [ASSUMED]
  - Recent change: npm up landed 2h ago in commit a1b2c3 (from git log)
  - Broken lib: @auth/core bumped 3.1 → 4.0 (breaking change per changelog)
  - Error: production logs show "useAuth is not a function" 1243 times since deploy
  - Repro: curl -X POST https://api.../login returns 500
  [UNKNOWN]
  - None — proceeding with RCA

  Task(@ciel-critic, "MODE=RCA SYMPTOM=useAuth undefined post @auth/core v4 upgrade REPRO=curl ... SCOPE=src/auth/")
```

---

## Dispatch directive — Skill tool vs Task tool

**MANDATORY**: before invoking a Ciel skill, check its frontmatter.

| Frontmatter | Invocation method | Why |
|---|---|---|
| `context: fork` + `agent: <role>` | **Task tool** → dispatch `@ciel-<role>` subagent with the skill as its primary instruction | Fork context = fresh perspective, blind-spot mitigation (CriticBench), isolated tool permissions. Inline defeats the whole point. |
| No `context: fork` (or `context: inline`) | **Skill tool** inline in main session | Deterministic / lightweight / orchestration — fork overhead unjustified. |

### Fork-context skills (ALWAYS dispatch via Task, never inline)

- `debug-reasoning-rca` → `Task(@ciel-critic, "MODE=RCA SYMPTOM=... REPRO=... SCOPE=...")`
- `doc-validator-official` → `Task(@ciel-researcher, "TARGET_STACK=... PROPOSED_APIS=...")`
- `modern-patterns-checker` → `Task(@ciel-explorer, "CODE_UNDER_REVIEW=... TARGET_STACK=...")`
- `ai-failure-modes-detector` → `Task(@ciel-explorer, "CODE_UNDER_REVIEW=... AUTHOR=...")`
- `self-consistency-verifier` → `Task(@ciel-critic, "PROBLEM=... STAKES=Critical")`
- `test-strategy-vitest-playwright` → `Task(@ciel-explorer, "FEATURE=... COMPONENTS=...")`
- `playwright-visual-critic` → `Task(@ciel-explorer, "TARGET_URL=... VIEWPORT=...")`
- `cicd-security-hardener` → `Task(@ciel-explorer, "PIPELINE_FILES=...")`
- `skills-first-design-auditor` → `Task(@ciel-improver, "SKILL_PATH=...")`
- All `skills/research/*` → dispatched by `@ciel-researcher`
- `pattern-fitness-check`, `flux-narrator`, `critiquer-auditor`, `stride-analyzer`, `security-regression-check` → dispatched by their declared agent
- All `skills/domain/*` skills with `context: fork` → dispatched by `@ciel-explorer`

### Inline-OK skills (Skill tool direct)

- `ciel` (this orchestrator) — must stay inline; it IS the main session's reasoning trace
- `depth-classifier`, `quoi-framer`, `avec-quoi-versioner` — deterministic, fast, feed the main pipeline
- `faire-gatekeeper`, `evaluer-sizer` — active during main-session implementation
- `relire-critic` (inline fallback for Trivial / Standard <3 files; dispatched via `@ciel-critic` for 3+ files or Critical)
- `meta-critiquer`, `prouver-verifier` — end-of-task orchestration in main session
- `synthesize-findings` — aggregates research outputs back in main session
- `learnings-capture` — writes to `ciel-overlay.md` from main session (writes are ok here)

### Anti-pattern to avoid

```
❌ "Intent matched → Skill(debug-reasoning-rca)"    // inline, loses fork context
✅ "Intent matched → Task(@ciel-critic, 'MODE=RCA SYMPTOM=...')"  // fork, fresh perspective
```

**If you catch yourself invoking a `context: fork` skill via the Skill tool, stop and re-issue via Task.**

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
