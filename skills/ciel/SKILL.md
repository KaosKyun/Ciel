# Ciel — Universal Deep-Reasoning Workflow

Principle: **"Understand before generating. Verify before claiming done."**

Core insight: LLMs code by statistical pattern-matching, not reasoning. Ciel forces understanding — framework philosophy, data flow tracing, alternatives consideration, hostile self-critique — before, during, and after code generation.

A thinking process — not a mechanical checklist. Apply with judgment. Adapt depth to risk.

---

## Depth Gauge

Classify BEFORE starting. Wrong classification = wrong depth.

| Level | Example | CRÉER steps | CRITIQUER steps | Agents |
|-------|---------|-------------|-----------------|--------|
| **Trivial** | rename, typo, 1-line | QUOI → CODEBASE → FAIRE → PROUVER | COMPRENDRE → SIGNALER | None |
| **Standard** | hook, route, component, service | Full CRÉER minus SÉCURITÉ | Full CRITIQUER | researcher + explorer + critic — mandatory |
| **Critical** | auth, DB schema, security, payment | Full CRÉER + SÉCURITÉ | Full CRITIQUER + multi-pass | All 3 — mandatory, never skip |

If unsure → Standard. If touching user data or auth → Critical.

---

## CRÉER — Before implementing

### 1. QUOI

- Expected result in one sentence
- Optimizing for: `perf` | `maintainability` | `security` | `simplicity`
- **NOT-X**: at least 1 concrete constraint the solution must NOT do
- What counts as "done"? Define before researching.

**Task decomposition gate** (SWE-Bench Pro 2026 — planning failure is the primary cascade origin):
If the task touches 3+ files → decompose into atomic sub-tasks NOW, before RECHERCHE:
- State each sub-task independently: "File A: change X. File B: change Y."
- Can't state a file's change in isolation → the decomposition is wrong → think again.
- "It's all one change" is not decomposition. Multi-file = multiple atomic intents.

**Assumption inventory**: list your top 3 assumptions about the current state of the codebase.
Example: "(1) Table `users` has column `uuid`. (2) MSW handler is registered at `/api/manga`. (3) Redis is on DB0."
You will verify each at RELIRE.

### 2. AVEC QUOI

- Technologies + REAL installed versions (read package.json / build files — not memory)
- Load `ciel-overlay.md` if present — project-specific versions and rules
- State assumptions explicitly: "I'm assuming X because Y."

### 3. RECHERCHE *(MANDATORY — dispatch `researcher` agent on Standard/Critical)*

**Dispatch researcher agent — typed schema** (MAST 2026: free-form messages = 37% coordination failures):
```
TYPE: request
AGENT: researcher
TASK: [1-sentence description]
TECHNOLOGIES: [stack + exact installed versions]
QUESTION: [specific question — one question, not a list]
OVERLAY: [ciel-overlay.md content if available]
EXPECTED_OUTPUT: findings(bullets) + anti_patterns(1+) + philosophy(1) + api_surface(imports/signatures) + uncertainties
```

**Output gate — ALL required before continuing:**
- `□` 1 WebSearch result + 1 documented finding produced
- `□` 1 anti-pattern documented
- `□` Framework philosophy stated
- `□` Imports/signatures of every called file read?
- `□` If DB query: real columns verified (migration file or `pg_attribute`)?
- `□` If parsing/scraping: format tested on a real response example?

"I already know this" = the red flag that you NEED to research. Zero output = step not done.

**GitHub Issues search** (when external lib involved):
- `site:github.com/[lib]/issues [symptom]` — open? closed with workaround?
- Check incompatibilities between installed versions of co-dependencies.

### 4. SÉCURITÉ *(skip for Trivial)*

**PASSE 1 — RISK-RANK** (mechanical signals, not gut feeling):
- **Critical** if ANY: `auth/`, `security/`, DB tables (users, sessions, tokens), `.executeQuery`, `.executeUpdate`, `userId`, `password`, `token`, `secret`
- **Important** if ANY: diff > 5 files, `validate`, `sanitize`, `rateLimit`, route handlers
- **Routine** otherwise
→ Critical = all 3 passes. Important = passes 2+3. Routine = pass 3 only.

**PASSE 2 — STRIDE** (Critical/Important) — 6 categories:
- **S**poofing · **T**ampering · **R**epudiation · **I**nfo Disclosure · **D**oS · **E**levation
- OPS lens: unclosed connections, memory leaks, locks, behavior at 100x volume
- Multi-PR: delegate 2nd pass to a subagent (same reviewer = same blind spots)

**PASSE 3 — KILLER CHECKLIST:**
- `□` Same field = same validation everywhere? (grep to verify)
- `□` Same domain = same auth on ALL transports (REST + WS + SSE)?
- `□` Identity fields resolved server-side, never client-supplied?
- `□` SQL parameterized, never interpolated?
- `□` PII touched = anonymization covered?

Checklist hygiene: rotate items after incidents. If an item catches nothing in 10+ reviews → replace it.
Anti-theater rule: show EVIDENCE for each item (file:line or grep output). "Checked" without evidence = not checked.

### 5. CODEBASE *(dispatch `explorer` agent on Standard/Critical)*

**Dispatch explorer agent — typed schema:**
```
TYPE: request
AGENT: explorer
TASK: [description]
FIND: [patterns/functions to locate — specific, not "everything"]
TRACE: [user action to narrate end-to-end — one action]
PROJECT_ROOT: [absolute path]
EXPECTED_OUTPUT: patterns(APPLY/ADAPT/DO_NOT_USE) + repo_map(signatures+dependents+hub_check) + flux_narration + assumptions + break_points
```

**Mini repo-map** (explorer does this for Standard/Critical — do manually for Trivial):
1. `grep -n "^fun \|^class \|^interface \|^object " <file>` — list key signatures in impacted files
2. `grep -r "import.*<filename>" src/` — list dependents (1 hop out)
3. Hub check: if step 2 returns 5+ files → hub. Changes ripple widely, proceed with caution.

**Pattern fitness check** (for each pattern found):
1. What problem did this pattern solve originally? (git blame)
2. Is MY problem the same problem?
3. Are the constraints the same? (volume, transport, sync/async, single/batch)
→ Any "no" → ADAPT or DO NOT USE.

Prior AI-generated patterns: treat as suggestions, not laws. If they contradict docs → likely anti-patterns from a prior session. DO NOT FOLLOW THEM.

**Duplication check**: 2+ copies of the pattern you're about to write → extract a shared helper first.

### 6. ÉVALUER *(skip for Trivial)*

- **Sizing**: back-of-envelope — does it fit? (memory, connections, throughput)
- **Pre-mortem**: 2 ways this could fail in production
- **Alternative**: "I chose X over Y because [reason]." No Y named → think harder.
- **Counterfactual**: "What if we do NOTHING?" If 'nothing' solves 80% with 0 risk → reconsider scope.

### 7. FLUX *(skip for Trivial)*

Narrate: `"When user does X → Y fires → Z handles → state changes → output"`
- **BOUNDARIES**: where does control pass between layers?
- **ASSUMPTIONS**: what must be true?
- **BREAK POINTS**: where can the flow fail without visible error?

**If writing a test — 3 mandatory additional items:**
- `□` URL routing: request host:port vs handler host:port — match or mismatch?
- `□` Mock lifecycle: executes at module load? function call? render?
- `□` Timing: expected delay vs CI runner capabilities?

Can't narrate the flow → don't understand the system → read more code.

### 8. FAIRE

**Alternatives gate**: "I chose X over Y because [reason]." No Y → back to ÉVALUER.

**Idiomatic gate** — justify any bypass:
- `window.*` / `document.*` in React → why not hook/ref/router?
- `for` + raw SQL → why not batch/ORM?
- `catch(e) { return null }` → why not Result/sealed class?
- `as X` without type guard → why not `is X`?
- Copying block for 3rd+ time → why not extract a helper?

**Quality gates**: complexity < 15 · nesting < 4 · function < 50 lines

**Removal gate** (before removing/reducing any cache, feature, config, or dependency):
1. **Who uses it?** — grep all consumers
2. **What replaces it?** — identify the alternative layer
3. **What degrades?** — trace the UX path for offline, slow network, repeat visits
Any "I don't know" → investigate before acting.

**Alignment checkpoint** (3+ files): re-read QUOI — scope grew? Approach still best?

**Chunked validation**: after each file — compile? types OK? 2 consecutive fails → STOP.

### 9. RELIRE *(dispatch `critic` agent on Standard/Critical — inline format for Trivial)*

**Standard/Critical — dispatch critic agent — typed schema:**
```
TYPE: request
AGENT: critic
MODE: RELIRE
CHANGED_FILES: [list of all modified files]
QUOI_GOAL: [original objective from step 1]
IMPLEMENTATION: [what was done — 3-5 sentences, specific]
ASSUMPTION_INVENTORY: [the 3 assumptions from QUOI — verify each]
EXPECTED_OUTPUT: findings(BLOCKING/IMPORTANT/MINOR/VALIDATED) + resolutions(FIX/ACCEPT/DEFER) + assumption_verification
```

Fresh context = different blind spots (CriticBench 2024: isolated critic outperforms self-critique. MAST 2026: typed structured messages cut coordination failures by ~37%).

**Trivial — inline Reflexion format (no agent):**

RELIRE-A — Generate 3 specific critiques:
`RISQUE: [what could fail] parce que [root cause] — IMPACT: [consequence]`
Rule: at least 1 must be a **functional risk** (user-facing), not just technical.
Can't generate 3 → you don't understand the code well enough.

RELIRE-B — Resolve each critique:
- **FIX**: correct now · **ACCEPT**: document why risk is acceptable · **DEFER**: TODO with issue ref

**Assumption verification** (from QUOI inventory):
For each assumption listed in step 1 — verify it still holds NOW after writing.
Changed codebase = invalidated assumptions = silent failures (SWE-EVO 2026).

**Standard checklist** (always, even Trivial):
- `□` Quality gates respected?
- `□` All new imports exist at stated paths?
- `□` All DB columns referenced exist in real schema?
- `□` Test mocks on same host:port as actual requests?
- `□` Duplicated logic with existing code?
- `□` Would a staff engineer approve this?

Resolve BLOCKING findings before PROUVER. IMPORTANT → apply if low-risk, defer with issue ref.

### 10. PROUVER

**Staging verification is MANDATORY.** Push → deploy → trigger → capture evidence → PR.

**AVANT/APRÈS obligation** (any bug fix):
- AVANT: failing test (RED) OR log showing broken behavior — code diff ≠ proof
- APRÈS: staging log, curl, or HTTP status AFTER deploying AND triggering
- "No error in logs" ≠ proof — trigger the scenario, see a POSITIVE signal

**Constraint synthesis** (Critical — write BEFORE checking logs):
1. Functional: `"POST /api/X returns 201 with body.data.id"`
2. Behavioral: `"Log contains '[MESSAGE]' after triggering"`
3. Negative: `"Old error '[ERROR]' no longer appears"`

**Same-source rule**: bug found in logs → verify in logs. Bug in screenshot → verify by screenshot.

**Attacker perspective test** (security fixes): "If I were an attacker, what test proves my fix blocks me?" Write THAT test. Can't write it → fix isn't proven.

**Post-merge issue closure**: close ALL linked issues with evidence comment: (1) what was fixed (1 line), (2) concrete observed evidence from staging (log excerpts, curl responses, DOM values — NOT code diffs), (3) PR/SHA reference. Closure without evidence = not closed.

If PROUVER fails → back to the step that was wrong (usually CODEBASE or RECHERCHE).

---

## CRITIQUER — When reviewing or auditing

1. **APPRENDRE** — Docs + anti-pattern checklist BEFORE reading code. Without this: "grep + gut feeling."
   - WebSearch: "[framework] [version] anti-patterns common mistakes"
   - Build checklist of bypass signals BEFORE scanning code.
2. **COMPRENDRE** — WHY before judging. Git blame. Surface 3 assumptions, verify each.
3. **QUESTIONNER** — Does the original reason still hold? Could we do less?
4. **COMPARER** — Code vs docs, idiomatic gate, STRIDE (6 categories), OPS lens. Re-read for Critical.
5. **COHÉRENCE** — Same problem solved same way? Layers clean? Health thresholds met?
6. **SIGNALER** — `RISQUE: X parce que Y — IMPACT: Z` · BLOCKING/IMPORTANT/MINOR/VALIDATED · include NOT-X.
7. **CAPITALISER** — Route learnings to the right memory type (see ÉVOLUER).

---

## META-CRITIQUER *(30s after every task — non-negotiable even for Trivial)*

1. **Depth match?** Over-processed trivial = waste. Under-processed critical = risk.
2. **New failure mode?** → add Guard NOW. Note which Guard (if any) was triggered this session.
3. **User correction?** → route to right memory type + check SICA validator before persisting.

---

## Guards

| Failure mode | How it manifests | Guard |
|---|---|---|
| Skipping RECHERCHE | "I already know this" / "no lib involved" / zero research output produced | "I already know this" = the red flag you NEED to research. Min: 1 WebSearch + 1 finding. |
| False confidence | "I'm sure this API exists" without evidence — confidence > 90% with no citation | Verify before asserting. If you can't cite a source, you don't know it. |
| Imports missing | Runtime ImportError / "module not found" on first run | API surface: read signatures of every called file before writing |
| DB columns wrong | Query crashes with "column does not exist" in prod | Verify real schema (migration or `pg_attribute`) before any query |
| Assumption invalidation | Code written against old schema/API — silent failures when codebase changed under you | QUOI inventory + RELIRE verification: list top 3 assumptions → verify each still holds after writing. |
| Test URL mismatch | Test passes locally, fails in CI — MSW intercepts wrong host | FLUX test: trace request host:port vs handler host:port |
| Mock lifecycle error | Mock returns undefined / stale data — executed at wrong time | FLUX test: when does mock execute — module load or function call? |
| Pattern copied blindly | Correct syntax, wrong semantics — REST pagination on WebSocket messages | Fitness check: same problem? same constraints? Any no → adapt |
| Prior AI pattern | Existing code contradicts official docs — inherited anti-pattern from prior session | If pattern contradicts docs → DO NOT FOLLOW. Docs > existing code. |
| Degeneration of thought | Self-critique finds 0 issues — same blind spots reinforced | Dispatch critic agent (fresh context = genuinely different blind spots) |
| Agent coordination failure | Agents produce contradictory or duplicate findings — free-form prompt ambiguity | Typed agent dispatch schema: TYPE + AGENT + TASK + EXPECTED_OUTPUT. One question per agent. |
| Context overflow (silent) | Agent report < 200 tokens on Standard task — suspicious truncation | Re-dispatch with narrower scope. Truncated report = incomplete FAIRE. |
| Poor task decomposition | "Simple fix" touches 8 files with cascading changes — planning failure | QUOI decomposition gate: 3+ files → decompose into atomic sub-tasks before RECHERCHE. |
| No alternative | "Obviously the right approach" — first solution = only solution considered | Alternatives gate: name X over Y or back to ÉVALUER |
| Framework bypass | `window.location` in React, `for`+raw SQL, `catch→null`, `as X` cast | Idiomatic gate: justify every bypass signal. "I don't know" → RECHERCHE. |
| Scope drift | "Simple fix" grows to 7 files and a new abstraction | Alignment checkpoint at 3+ files: re-read QUOI |
| Removing without understanding | "This cache wastes resources" → removed → breaks UX nobody tested | Removal gate: Who uses it? What replaces it? What degrades? Any "I don't know" → stop. |
| Proposing without calculating | "Let's cache all 3826 manga" — sounds reasonable, fails arithmetic | ÉVALUER sizing: run back-of-envelope BEFORE proposing. If numbers fail → solution fails. |
| Debugging wrong layer | 3 CSS fixes when the bug was `navigate()` failing silently | 3-layer triage: (1) Is handler called? (2) Simplest action works? (3) Only then CSS/events. |
| Coding without mental model | Code pattern-matches but breaks because data flow isn't understood | FLUX: narrate full data flow before writing. Can't narrate → read more code. |
| First draft = final draft | Code works but messy — CEO sends it back | RELIRE: hostile critic before PROUVER. "Would I approve this PR?" |
| Fixation after failure | Same fix attempted 3 times, same result | After 2 failures: STOP. List 3 completely different approaches. |
| Coverage theater | 95% coverage, zero meaningful assertions | Does this test verify behavior, or just execute code? |
| Confirmation bias | Tests only prove it works, never that it fails | Constraint synthesis: write 3 constraints BEFORE checking logs. |
| Over-engineering | Change solves the problem but adds complexity that wasn't needed | Counterfactual: "What if we do NOTHING?" 80% solved with 0 risk → reconsider. |
| Self-improvement regression | New Guard prevents latest correction but re-enables an older failure mode | SICA validator: before persisting any Guard/rule change, verify it doesn't conflict with the last 3 user corrections. |
| Process bloat | SKILL.md grows to 500 lines, steps take longer than the task | Anti-entropy: every addition must simplify OR catch a real failure. |
| Stale overlay | Overlay says React 18, project is on React 19 — RECHERCHE fetches wrong docs | Per-month: check overlay versions vs real installed versions. |

---

## Agents — Mandatory on Standard/Critical

| Agent | Step | Context | Mandatory |
|-------|------|---------|----------|
| `researcher` | RECHERCHE | Isolated — no session bias | Standard + Critical |
| `explorer` | CODEBASE + FLUX | Isolated — reads codebase fresh | Standard + Critical |
| `critic` | RELIRE | Isolated — different blind spots (CriticBench: fresh context catches what self-review misses) | Standard + Critical |

Dispatch researcher + explorer **IN PARALLEL** before FAIRE.
Dispatch critic after FAIRE.
Do NOT re-read files agents already read — use their reports.
Use typed schema for all dispatches (see step 3/5/9) — unstructured prompts produce coordination failures.

**Agent report quality check**: if a report is < 200 tokens on a Standard task → suspect truncation. Re-dispatch with narrower scope before proceeding.

---

## ÉVOLUER — 4-type memory model

Route every learning to the correct memory type. Wrong routing = context drift or loss.

| Memory type | What goes here | Location |
|---|---|---|
| **Procedural** | HOW to work — workflow steps, gates, Guards | `SKILL.md` (this file) |
| **Semantic** | Project FACTS — stack, versions, CI, rules, lessons | `ciel-overlay.md` |
| **Episodic** | WHAT happened — versions, incidents, metrics | `CHANGELOG.md` |
| **Working** | IN-SESSION context — current task, agent reports | In-context only (ephemeral) |

**Rules:**
- User correction on HOW to work → Procedural (Guard or step change in SKILL.md)
- User correction on a project fact → Semantic (overlay)
- Incident or metric → Episodic (CHANGELOG)
- Never mix: don't put project facts in SKILL.md, don't put Guards in overlay

**SICA validator** (before persisting any Procedural change — SICA 2025: 17→53% improvement):
Before adding/modifying a Guard or step, validate against last 3 user corrections:
1. Does this rule prevent the SAME class of error as the correction?
2. Does it conflict with any prior correction? (Goodhart's Law: optimizing for latest = regressing on earlier)
3. If conflict → synthesize a rule that covers both, or ask.

**Self-cleaning cycle:**
- Per-task: note which Guard (if any) fired. Log in META-CRITIQUER.
- Per-month: count Guard trigger frequency. Guards with 0 triggers in 10+ sessions → candidate for removal. Run past 3 corrections to confirm it's truly stale before deleting.
- Never remove a Guard solely because "it feels obvious" — obvious Guards exist because the failure is subtle.

**Per-task**: META-CRITIQUER (30s). Route learning to correct memory type.
**Per-session**: patterns → Guards (Procedural) or overlay updates (Semantic).
**Per-month**: prune stale Guards. Verify overlay versions. Check CHANGELOG fix/revert ratio.
**Anti-entropy rule**: every addition must simplify OR catch a real failure. If neither → reject.
