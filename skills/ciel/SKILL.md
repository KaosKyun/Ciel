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
*(RECHERCHE = external: docs, anti-patterns, versions. Internal file checks belong in CODEBASE.)*
- `□` 1 WebSearch result + 1 documented finding produced
- `□` 1 anti-pattern documented
- `□` Framework philosophy stated — HOW does this framework want me to solve this? Not just what the API does.
- `□` Installed version changelog checked? (breaking changes, deprecations since last major — `[lib] [version] changelog breaking changes`)
- `□` If DB query: real columns verified (migration file or `pg_attribute`)?
- `□` If parsing/scraping: format tested on a real response example?

"I already know this" = the red flag that you NEED to research. Zero output = step not done.

**Domain skill boost** (before or in parallel with researcher agent):
- Detect: is a domain skill available for this technology? (frontend, backend, security, database, etc.)
- If yes → invoke it IN PARALLEL with the researcher agent. Domain skills = verified patterns. Researcher = current docs. Both needed.
- Domain skill findings complement WebSearch — use both, cross-reference conflicts (stale skill vs fresh docs → trust docs).
- If no domain skill exists → WebSearch only. Run `/ciel-recommend` to discover and install community plugins for this stack.

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

**Dispatch explorer agent:**
```
TASK: [description]
FIND: [patterns/functions to locate]
TRACE: [user action to narrate end-to-end]
PROJECT_ROOT: [absolute path]
```

**API surface check** (internal — before writing any call):
- `□` Imports/signatures of every called file read? (read actual file — not memory)

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
- **Recent-churn check**: `git log --oneline --since="7 days" -- <impacted files>` — if 2+ commits on the same module → read those commits before proposing a fix. Same subsystem fixed twice this week = incomplete mental model.
- **Alternative**: "I chose X over Y because [reason]." No Y named → think harder.
- **Counterfactual**: "What if we do NOTHING?" If 'nothing' solves 80% with 0 risk → reconsider scope.

### 7. FLUX *(skip for Trivial)*

Narrate: `"When user does X → Y fires → Z handles → state changes → output"`
- **BOUNDARIES**: where does control pass between layers?
- **ASSUMPTIONS**: what must be true?
- **BREAK POINTS**: where can the flow fail without visible error?

**If writing a test — 4 mandatory additional items:**
- `□` Test level: unit (isolated logic) / integration (layer boundary) / E2E (user flow) — justify the choice
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
2. **What replaces it?** — identify the alternative layer (HTTP cache? TanStack Query? nothing?)
3. **What degrades?** — trace the UX path for offline, slow network, repeat visits
Any "I don't know" → investigate before acting. "It'll probably work" is NOT an answer.

**Alignment checkpoint** (3+ files): re-read QUOI — scope grew? Approach still best?

**Volume gate**: Creating 3+ PRs in the same session → PAUSE. Verify labels + `Closes #XXX` + staging evidence on each PR before opening the next.

**Test gate** (before writing implementation code — no exception):
- `□` Test written BEFORE implementation? (RED first — "I'll add tests after" is not an answer)
- `□` Test verifies observable behavior, not just code execution?
- `□` Failure path tested (negative scenario) at same priority as happy path?

**Before-state capture** (bug fix only — do this NOW, before writing any code):
Capture the broken behavior immediately: log excerpt, curl output, or screenshot showing the failure. Without this, PROUVER's AVANT obligation cannot be satisfied.

**Chunked validation**: after each file — compile? types OK? 2 consecutive fails → STOP.

### 8b. SECURITY REGRESSION CHECK *(Critical only — after FAIRE, before RELIRE)*

- Does this fix introduce NEW inputs, NEW trust boundaries, or NEW code paths that weren't there before?
- grep the diff for: new `val`/`var` from request params, `authenticate { }` blocks removed, new external calls added
- "I fixed A without touching B" is NOT a check — read the diff with attacker eyes.
→ Any new surface found → treat as Critical finding in RELIRE.

### 9. RELIRE *(dispatch `general-purpose` Agent with `agents/critic.md` on Standard/Critical — inline format for Trivial)*

**Standard/Critical — dispatch a `general-purpose` Agent using `agents/critic.md` as its prompt:**
```
MODE: RELIRE
CHANGED_FILES: [list of all modified files]
QUOI_GOAL: [original objective]
IMPLEMENTATION: [what was done — 3-5 sentences]
```
Important: use a `general-purpose` subagent (not `superpowers:code-reviewer` or any other named agent) — load `agents/critic.md` as the agent prompt to preserve Ciel's critique format.

Fresh context = different blind spots (CriticBench 2024: self-critique is the hardest critique mode for LLMs — isolated critic reduces degeneration of thought).

**Trivial — inline Reflexion format (no agent):**

RELIRE-A — Generate 3 specific critiques:
`RISQUE: [what could fail] parce que [root cause] — IMPACT: [consequence]`
Rule: at least 1 must be a **functional risk** (user-facing), not just technical.
Can't generate 3 → you don't understand the code well enough.

RELIRE-B — Resolve each critique:
- **FIX**: correct now · **ACCEPT**: document why risk is acceptable · **DEFER**: TODO with issue ref

**Standard checklist** (always, even Trivial):
- `□` Quality gates respected?
- `□` All new imports exist at stated paths?
- `□` All DB columns referenced exist in real schema?
- `□` Test mocks on same host:port as actual requests?
- `□` Tests could fail independently of implementation? (mentally remove the impl — does the test still make sense and could it still fail?)
- `□` Duplicated logic with existing code?
- `□` Linter clean? (0 new violations vs base branch — Detekt / ESLint)
- `□` Would a staff engineer approve this?

Resolve BLOCKING findings before PROUVER. IMPORTANT → apply if low-risk, defer with issue ref.

### 10. PROUVER

**Trivial — PROUVER allégé:** compile OK + push + verify no regression (no CI gate, no staging mandatory).

**Standard/Critical — Staging verification is MANDATORY.** Push → deploy → trigger → capture evidence → PR.

**AVANT/APRÈS obligation** (any bug fix):
- AVANT: failing test (RED) OR log showing broken behavior — code diff ≠ proof
- APRÈS: staging log, curl, or HTTP status AFTER deploying AND triggering
- "No error in logs" ≠ proof — trigger the scenario, see a POSITIVE signal

**Constraint synthesis** (Critical — write BEFORE checking logs):
1. Functional: `"POST /api/X returns 201 with body.data.id"`
2. Behavioral: `"Log contains '[MESSAGE]' after triggering"`
3. Negative: `"Old error '[ERROR]' no longer appears"`

**Same-source rule**: bug found in logs → verify in logs. Bug in screenshot → verify by screenshot. A curl result is NOT a substitute for the original observation source.

**Attacker perspective test** (security fixes): "If I were an attacker, what test proves my fix blocks me?" Write THAT test. Can't write it → fix isn't proven.

**CI gate** (mandatory — before presenting any report):
- `gh run list --branch $BRANCH --limit 1` → status must be `completed/success` or `in_progress`
- If failed: read failing job (`gh run view --job=ID`), identify root cause, fix before PR
- "CI is running" ≠ done — wait for completion or acknowledge status explicitly

**PR body gate** (before `gh pr create`):
- `□` PR body contains `Closes #XXX` for every linked issue?
- `□` PR title has no WIP marker (`WIP`, `[WIP]`, `wip`)? WIP = not done = don't open PR.
- `□` PR closed after merge? (`gh pr view` — status: merged, not open)

**Issue comment gate** (after staging verify, before PR):
- Add a comment on every linked issue with: staging PID + AVANT/APRÈS evidence. Do NOT wait for post-merge.

**Open PR hygiene** (check at session start and end):
- `gh pr list --state open` — any draft with CI green? → convert to ready (`gh pr ready`)
- Any PR open > 2 days with CI green + no review? → flag to CEO
- Missing comments on linked issues? → add them now

**Closure gate** (before any issue is closed — including auto-close via PR merge):
- `gh issue view <N> --comments` — does a comment with staging PID + AVANT/APRÈS exist?
- No comment → add it NOW before the PR is merged (auto-close will not add it)
- Batch PRs closing multiple issues → each issue gets its own comment individually

**Post-merge issue closure**: close ALL linked issues with evidence comment: (1) what was fixed (1 line), (2) concrete observed evidence from staging (log excerpts, curl responses, DOM values — NOT code diffs), (3) PR/SHA reference. Closure without evidence = not closed.

If PROUVER fails → back to the step that was wrong (usually CODEBASE or RECHERCHE).

---

## CRITIQUER — When reviewing or auditing

**Entry: read the diff/PR first.** Before any step — open the changed files, read every line changed. Without this, all subsequent steps operate on assumptions.

1. **APPRENDRE** — Build expected behavior model BEFORE judging the code.
   - From issue/spec/PR description: "what was this SUPPOSED to do?"
   - Build a checklist of bypass signals for this change type BEFORE scanning code.
   - If external lib involved: WebSearch `[lib] [version] anti-patterns common mistakes` — otherwise skip WebSearch.
   - `□` Expected behavior model written in 1-2 sentences?
   - `□` Bypass signal checklist built (min 3 signals to look for)?

2. **COMPRENDRE** — WHY before judging. Surface 3 assumptions, verify each.
   - Git blame: why was the original code written this way?
   - `□` 3 assumptions surfaced?
   - `□` Each assumption verified against actual code (grep / git blame / read)?

3. **QUESTIONNER** — Does the original reason still hold? Could we do less?
   - `□` "What if we do nothing?" considered?
   - `□` Scope of change proportional to the problem?

4. **COMPARER** — Code vs expected model, idiomatic gate, STRIDE, OPS lens.
   - Code vs expected behavior model: does it actually do what step 1 described?
   - Idiomatic gate: any framework bypass signals from the checklist?
   - STRIDE — check all 6 explicitly (Critical/Important):
     - **S**poofing: can I impersonate someone?
     - **T**ampering: can input be modified in transit?
     - **R**epudiation: can a user deny this action?
     - **I**nfo Disclosure: what leaks (errors, logs, responses)?
     - **D**oS: can this be flooded/exhausted?
     - **E**levation: can I access what I shouldn't?
   - OPS lens: unclosed connections, memory leaks, behavior at 100x volume
   - `□` Code matches expected behavior model?
   - `□` All bypass signals from step 1 checklist checked?
   - `□` STRIDE run (all 6 — mark N/A if not applicable, never skip silently)?

5. **COHÉRENCE** — Same problem solved same way? Layers clean?
   - `□` Grep: is this pattern used consistently elsewhere in the codebase?
   - `□` Layer boundaries respected (no business logic in routes, no DB calls in controllers)?
   - `□` Health thresholds from overlay met (complexity, coverage, etc.)?

6. **SIGNALER** — Report findings with severity.
   - Format: `RISQUE: X parce que Y — IMPACT: Z`
   - **BLOCKING**: must fix before merge — correctness, security, data loss
   - **IMPORTANT**: should fix — degraded behavior, tech debt with near-term risk
   - **MINOR**: nice to fix — style, naming, low-risk improvement
   - **VALIDATED**: explicitly checked and confirmed correct — document what was verified
   - `□` Every finding has RISQUE format?
   - `□` Every BLOCKING has a specific FIX suggested?
   - `□` include NOT-X (what the solution must NOT do)?

7. **CAPITALISER** — Close the loop.
   - New anti-pattern found → add to Guards or overlay.
   - New failure mode → add Guard immediately.
   - `□` Any new Guard to add?
   - `□` Overlay updated if project-specific rule emerged?

---

## META-CRITIQUER *(30s after every task — non-negotiable even for Trivial)*

1. **Depth match?** Over-processed trivial = waste. Under-processed critical = risk.
2. **New failure mode?** → add Guard NOW.
3. **User correction?** → update overlay + lessons.
4. **Stale branches?** `git branch -r | wc -l` — excessive remote branches? Cleanup stale ones. (Project-specific cleanup commands go in overlay.)
5. **Uncovered issues?** `gh issue list --state closed --limit 10 --json number,comments` — any issue with 0 comments? → add evidence comment now before next task.
6. **Context health?** After a Critical task or 3+ agent dispatches: run `/compact` or open a new session before starting the next task. Stacking Critical tasks in one context window degrades output quality.
7. **Session progress file** (Anthropic Engineering recommendation) — at each session boundary (task done, context > 70%, or before `/compact`): write `.claude/session-progress.md` with: current status, completed tasks, **failed approaches + why they failed**, known limitations, next steps. Next session reads this instead of replaying history. Failed approaches are the critical field — prevents re-attempting dead ends.
8. **Dead code sweep?** Vibe coding creates dead code fast. Run often:
   - Python: `ruff check --select F401,F811,F841 .` (unused imports/vars) + `vulture . --min-confidence 80`
   - TypeScript: `npx knip` or manual grep for unused exports
   - Kotlin: Detekt `UnusedPrivateMember` + `UnusedImport` rules
   Fix or remove findings before closing the session.

---

## Guards

| Failure mode | How it manifests | Guard |
|---|---|---|
| Skipping RECHERCHE | "I already know this" / "no lib involved" / zero research output produced | "I already know this" = the red flag you NEED to research. Min: 1 WebSearch + 1 finding. |
| False confidence | "I'm sure this API exists" without evidence — confidence > 90% with no citation | Verify before asserting. If you can't cite a source, you don't know it. |
| Imports missing | Runtime ImportError / "module not found" on first run | API surface: read signatures of every called file before writing |
| DB columns wrong | Query crashes with "column does not exist" in prod | Verify real schema (migration or `pg_attribute`) before any query |
| Test URL mismatch | Test passes locally, fails in CI — MSW intercepts wrong host | FLUX test: trace request host:port vs handler host:port |
| Mock lifecycle error | Mock returns undefined / stale data — executed at wrong time | FLUX test: when does mock execute — module load or function call? |
| Pattern copied blindly | Correct syntax, wrong semantics — REST pagination on WebSocket messages | Fitness check: same problem? same constraints? Any no → adapt |
| Prior AI pattern | Existing code contradicts official docs — inherited anti-pattern from prior session | If pattern contradicts docs → DO NOT FOLLOW. Docs > existing code. |
| Degeneration of thought | Self-critique finds 0 issues — same blind spots reinforced | Dispatch critic agent (fresh context = genuinely different blind spots) |
| Context overflow (silent) | Agent report < 200 tokens on Standard task — suspicious truncation | Re-dispatch with narrower scope. Truncated report = incomplete FAIRE. |
| No alternative | "Obviously the right approach" — first solution = only solution considered | Alternatives gate: name X over Y or back to ÉVALUER |
| Framework bypass | `window.location` in React, `for`+raw SQL, `catch→null`, `as X` cast | Idiomatic gate: justify every bypass signal. "I don't know" → RECHERCHE. |
| Scope drift | "Simple fix" grows to 7 files and a new abstraction | Alignment checkpoint at 3+ files: re-read QUOI |
| Removing without understanding | "This cache wastes resources" → removed → breaks UX nobody tested | Removal gate: Who uses it? What replaces it? What degrades? Any "I don't know" → stop. |
| Proposing without calculating | "Let's cache all 3826 manga" — sounds reasonable, fails arithmetic | ÉVALUER sizing: run back-of-envelope BEFORE proposing. If numbers fail → solution fails. |
| Debugging wrong layer | 3 CSS fixes when the bug was `navigate()` failing silently | 3-layer triage: (1) Is handler called? (2) Simplest action works? (3) Only then CSS/events. |
| Coding without mental model | Code pattern-matches but breaks because data flow isn't understood | FLUX: narrate full data flow before writing. Can't narrate → read more code. |
| First draft = final draft | Code works but messy — CEO sends it back | RELIRE: hostile critic before PROUVER. "Would I approve this PR?" |
| Fixation after failure | Same fix attempted 3 times, same result | After 2 failures: STOP. List 3 completely different approaches. |
| TDD inversion | Tests written after implementation — pass by definition, catch nothing | Write failing test FIRST (RED). "I'll add tests after" = the test will never catch a real bug. |
| Coverage theater | 95% coverage, zero meaningful assertions | Does this test verify behavior, or just execute code? |
| Confirmation bias | Tests only prove it works, never that it fails | Constraint synthesis: write 3 constraints BEFORE checking logs. |
| Over-engineering | Change solves the problem but adds complexity that wasn't needed | Counterfactual: "What if we do NOTHING?" 80% solved with 0 risk → reconsider. |
| Process bloat | SKILL.md grows to 500 lines, steps take longer than the task | Anti-entropy: every addition must simplify OR catch a real failure. |
| Stale overlay | Overlay says React 18, project is on React 19 — RECHERCHE fetches wrong docs | Per-month: check overlay versions vs real installed versions. |
| Security fix adds surface | Fix closes vuln A but opens new endpoint/input/trust boundary unguarded | PASSE 4: grep diff for new params, removed auth blocks, new external calls — attacker eyes on the diff |
| CI ignored | "Staging works" declared while CI is red or running | CI gate in PROUVER: `gh run list --branch $BRANCH --limit 1` — must be success before report |
| Draft PR left open | CI green but PR stays draft — CEO can't review, never merges | META-CRITIQUER: `gh pr list --draft` — CI green + draft → convert to ready immediately |
| Issue comment missing | Fix deployed but no evidence on the issue — CEO sees open issue with no update | Issue comment gate: add staging PID + AVANT/APRÈS on linked issue BEFORE creating PR |
| Version changelog missed | Using Ktor 3.x but researching Ktor 2.x docs — breaking changes missed | RECHERCHE output gate: `□` installed version changelog checked for breaking changes |
| File re-read | Same file read 3 times in a session — each read costs tokens and dilutes context | After first read: note pointer (path + 1-line summary). Re-read only if editing. Memory pointer rule in CONTEXTE. |
| Dead-end loop | Same broken approach attempted in new session — no record of why it failed | Session progress file: write `.claude/session-progress.md` with failed approaches + rationale before closing context. |
| Dead code accumulation | Unused imports, unreachable functions, orphaned variables pile up across sessions | META-CRITIQUER #8: run `ruff check --select F401,F811,F841` + `vulture . --min-confidence 80` (Python), `npx knip` (TS), Detekt unused rules (Kotlin). Fix before session end. |

---

## Agents — Mandatory on Standard/Critical

| Agent | Step | Context | Mandatory |
|-------|------|---------|----------|
| `researcher` | RECHERCHE | Isolated — no session bias | Standard + Critical |
| `explorer` | CODEBASE + FLUX | Isolated — reads codebase fresh | Standard + Critical |
| `critic` | RELIRE | Isolated — different blind spots (CriticBench: fresh context catches what self-review misses) | Critical always; Standard if 3+ files changed |

Dispatch researcher + explorer **IN PARALLEL** before FAIRE.
Dispatch critic after FAIRE — **but only when justified** (see token budget below).
Do NOT re-read files agents already read — use their reports.

**Token budget rule**: each agent dispatch costs ~850K tokens on average. On Standard tasks with < 3 changed files, use inline RELIRE (no critic agent) to save ~850K tokens. Reserve critic agent for: Critical tasks, Standard tasks touching 3+ files, or any auth/security change.

**Agent report quality check**: if a report is < 200 tokens on a Standard task → suspect truncation. Re-dispatch with narrower scope before proceeding.

**Agent result size cap**: dispatch agents with explicit scope: "Return max 150 lines. Summarize if more." If report > 300 lines anyway → re-dispatch with `FOCUS:` narrowed to one specific question. Never paste a > 300-line report verbatim into the next step.

---

## CONTEXTE — Context Budget Management

Apply throughout all steps. Unchecked context growth = degraded output quality on long tasks.

| Usage | Signal | Action |
|-------|--------|--------|
| < 50% | Comfortable | Normal depth |
| 50–70% | Caution | Prefer `grep`/signatures over full file reads; skip optional re-dispatches |
| > 70% | Pressure | No new agents; use Grep/Glob directly; compress agent prompts |
| > 85% | Critical | Finish current step, commit, open new session for next task |

**Lazy reading** — always prefer signatures before full files:
```
grep -n "^fun \|^class \|^interface \|^object " <file>
```
Full file read only when signatures are insufficient. Never read the same file twice in a session.

**Anti-flooding** — each piece of information is injected once per session. When re-dispatching a second agent for the same area: pass the first agent's summary, not the raw context.

**Observation masking** (OpenHands / JetBrains 2025) — tool outputs from >3 turns ago that weren't referenced in subsequent turns: don't re-paste them. Replace with `[MASKED: result from step X — referenced in step Y]`. Zero LLM cost, as effective as summarization for most tasks.

**Anti-silent-consumption** — background cron/loop agents are the #2 token killer after subagents. Before using `/loop` or `/schedule`: estimate daily token cost (runs × ~50K tokens per invocation). A 5-min loop = 288 runs/day = ~14M tokens/day. Prefer event-driven checks (run manually when needed) over polling.

**Memory pointers** (ACON 2025, -40-60% tokens on file-heavy tasks) — after reading a file, note its pointer: `ref: packages/server/…/Foo.kt — SSRF validation, read step 3`. Evict the full content. Re-read only if editing that file again. Never keep full file content in context once it's been acted on.

---

## ÉVOLUER

- Per-task: META-CRITIQUER (30s). Update Guards + overlay.
- Per-session: patterns → Guards or overlay rules.
- Per-month: prune Guards that never fire. Check overlay drift. Check CHANGELOG fix/revert ratio.
- Anti-entropy rule: every addition must simplify OR catch a real failure. If neither → reject.
- Track fix/revert ratio per version in `CHANGELOG.md` — improvement must be measurable.
