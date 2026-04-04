# Ciel — Universal Deep-Reasoning Workflow

Principle: **"Understand before generating. Verify before claiming done."**

Core insight: LLMs code by statistical pattern-matching, not reasoning. Ciel forces understanding — framework philosophy, data flow tracing, alternatives consideration, hostile self-critique — before, during, and after code generation.

A thinking process — not a mechanical checklist. Apply with judgment. Adapt depth to risk.

---

## Depth Gauge

Classify BEFORE starting. Wrong classification = wrong depth.

| Level | Example | Steps | Agents |
|-------|---------|-------|--------|
| **Trivial** | rename, typo, 1-line | QUOI → CODEBASE → FAIRE → PROUVER | None |
| **Standard** | hook, route, component, service | Full CRÉER minus SÉCURITÉ | researcher + explorer + critic — mandatory |
| **Critical** | auth, DB schema, security, payment | Full CRÉER + SÉCURITÉ | All 3 — mandatory, never skip |

If unsure → Standard. If touching user data or auth → Critical.

---

## CRÉER — Before implementing

### 1. QUOI

- Expected result in one sentence
- Optimizing for: `perf` | `maintainability` | `security` | `simplicity`
- **NOT-X**: at least 1 concrete constraint the solution must NOT do
- What counts as "done"? Define before researching.

### 2. AVEC QUOI

- Technologies + REAL installed versions (read package.json / build files — not memory)
- Load `ciel-overlay.md` if present — project-specific versions and rules
- State assumptions explicitly: "I'm assuming X because Y."

### 3. RECHERCHE *(MANDATORY — dispatch `researcher` agent on Standard/Critical)*

**Dispatch researcher agent:**
```
TASK: [1-sentence description]
TECHNOLOGIES: [stack + exact installed versions]
QUESTION: [specific question to answer]
OVERLAY: [ciel-overlay.md content if available]
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

### 4. SÉCURITÉ *(skip for Trivial)*

**PASSE 1 — RISK-RANK** (mechanical signals, not gut feeling):
- **Critical** if ANY: `auth/`, `security/`, DB tables (users, sessions, tokens), `.executeQuery`, `.executeUpdate`, `userId`, `password`, `token`, `secret`
- **Important** if ANY: diff > 5 files, `validate`, `sanitize`, `rateLimit`, route handlers
- **Routine** otherwise
→ Critical = all 3 passes. Important = passes 2+3. Routine = pass 3 only.

**PASSE 2 — STRIDE** (Critical/Important) — 6 categories:
- **S**poofing · **T**ampering · **R**epudiation · **I**nfo Disclosure · **D**oS · **E**levation
- OPS lens: unclosed connections, memory leaks, locks, behavior at 100x volume

**PASSE 3 — KILLER CHECKLIST:**
- `□` Same field = same validation everywhere? (grep to verify)
- `□` Same domain = same auth on ALL transports (REST + WS + SSE)?
- `□` Identity fields resolved server-side, never client-supplied?
- `□` SQL parameterized, never interpolated?
- `□` PII touched = anonymization covered?

Anti-theater rule: show EVIDENCE for each item (file:line or grep output). "Checked" without evidence = not checked.

### 5. CODEBASE *(dispatch `explorer` agent on Standard/Critical)*

**Dispatch explorer agent:**
```
TASK: [description]
FIND: [patterns/functions to locate]
TRACE: [user action to narrate end-to-end]
PROJECT_ROOT: [absolute path]
```

**Pattern fitness check** (for each pattern found):
1. What problem did this pattern solve originally? (git blame)
2. Is MY problem the same problem?
3. Are the constraints the same? (volume, transport, sync/async, single/batch)
→ Any "no" → ADAPT or DO NOT USE.

Prior AI-generated patterns: treat as suggestions, not laws. If they contradict docs → likely anti-patterns.

**Duplication check**: 2+ copies of the pattern you're about to write → extract a shared helper first.

### 6. ÉVALUER *(skip for Trivial)*

- **Sizing**: back-of-envelope — does it fit? (memory, connections, throughput)
- **Pre-mortem**: 2 ways this could fail in production
- **Alternative**: "I chose X over Y because [reason]." No Y named → think harder.

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

**Alignment checkpoint** (3+ files): re-read QUOI — scope grew? Approach still best?

**Chunked validation**: after each file — compile? types OK? 2 consecutive fails → STOP.

### 9. RELIRE *(skip for Trivial — dispatch `critic` agent on Standard/Critical)*

**Dispatch critic agent (MODE=RELIRE):**
```
MODE: RELIRE
CHANGED_FILES: [list of all modified files]
QUOI_GOAL: [original objective]
IMPLEMENTATION: [what was done — 3-5 sentences]
```

Fresh context = different blind spots. Single-agent self-critique reinforces same errors (MAR: degeneration of thought).

- BLOCKING → fix before PROUVER
- IMPORTANT → apply if low-risk, defer with issue ref if out of scope

**Standard checklist** (always, even Trivial):
- `□` Quality gates respected?
- `□` All new imports exist at stated paths?
- `□` All DB columns referenced exist in real schema?
- `□` Test mocks on same host:port as actual requests?
- `□` Duplicated logic with existing code?
- `□` Would a staff engineer approve this?

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

Same-source rule: bug in logs → verify in logs. Bug in screenshot → verify by screenshot.

If PROUVER fails → back to the step that was wrong (usually CODEBASE or RECHERCHE).

---

## CRITIQUER — When reviewing or auditing

1. **APPRENDRE** — Docs + anti-pattern checklist BEFORE reading code. Without this: "grep + gut feeling."
2. **COMPRENDRE** — WHY before judging. Git blame. Surface 3 assumptions, verify each.
3. **QUESTIONNER** — Does the original reason still hold? Could we do less?
4. **COMPARER** — Code vs docs, idiomatic gate, STRIDE (6 categories), OPS lens.
5. **COHÉRENCE** — Same problem solved same way? Layers clean? Health thresholds met?
6. **SIGNALER** — `RISQUE: X parce que Y — IMPACT: Z` · BLOCKING/IMPORTANT/MINOR/VALIDATED · include NOT-X.
7. **CAPITALISER** — Update overlay or memory.

---

## META-CRITIQUER *(30s after every Standard/Critical)*

1. **Depth match?** Over-processed trivial = waste. Under-processed critical = risk.
2. **New failure mode?** → add Guard NOW.
3. **User correction?** → update overlay + lessons.

---

## Guards

| Failure mode | Guard |
|---|---|
| Skipping RECHERCHE | "I already know this" = red flag you NEED to research. Min: 1 WebSearch + 1 finding. |
| Imports missing | API surface: read signatures of every called file before writing |
| DB columns wrong | Verify real schema (migration or `pg_attribute`) before any query |
| Test URL mismatch | FLUX test: trace request host:port vs MSW handler host:port |
| Mock lifecycle error | FLUX test: when does mock execute — module load or function call? |
| Pattern copied blindly | Fitness check: same problem? same constraints? Any no → adapt |
| Degeneration of thought | Dispatch critic agent (fresh context = different blind spots) |
| No alternative | Alternatives gate: name X over Y or back to ÉVALUER |
| Framework bypass | Idiomatic gate: justify every `window.*`, raw SQL, catch→null, `as X` |
| Scope drift | Alignment checkpoint at 3+ files: re-read QUOI |
| Confirmation bias | Constraint synthesis: write 3 constraints BEFORE checking logs |
| Process bloat | Anti-entropy: every addition must simplify OR catch a real failure. |
| Stale overlay | Per-month: check overlay versions vs real installed versions |

---

## Agents — Mandatory on Standard/Critical

| Agent | Step | Context | Mandatory |
|-------|------|---------|----------|
| `researcher` | RECHERCHE | Isolated — no session bias | Standard + Critical |
| `explorer` | CODEBASE + FLUX | Isolated — reads codebase fresh | Standard + Critical |
| `critic` | RELIRE | Isolated — different blind spots | Standard + Critical |

Dispatch researcher + explorer IN PARALLEL before FAIRE.
Dispatch critic after FAIRE.
Do NOT re-read files agents already read — use their reports.

---

## ÉVOLUER

- Per-task: META-CRITIQUER (30s). Update Guards + overlay.
- Per-session: patterns → Guards or overlay rules.
- Per-month: prune Guards that never fire. Check overlay drift.
- Track fix/revert ratio per version in `CHANGELOG.md` — improvement must be measurable.
