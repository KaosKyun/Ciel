# AGENTS.md — Ciel deep-reasoning workflow

Source: https://github.com/KaosKyun/Ciel

---


# Ciel — Skills-first Orchestrator

Named after the Primordial Sage from *Tensei Shitara Slime Datta Ken* — the advisor who reasons at infinite speed before Rimuru acts.

Principle: **"Understand before generating. Verify before claiming done."**

This orchestrator is thin on purpose. It classifies the task, then routes to specialized skills. It does NOT replicate their content — each workflow step is its own skill.

For full philosophy, guards table, and the research basis behind Ciel, see `reference.md`.


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


## ÉVOLUER — closed feedback loop

- Per-task: `meta-critiquer` (30s) → update Guards or overlay
- Per-session: patterns → new Guards or overlay rules via `learnings-capture`
- Per-month: prune Guards that never fire; check overlay drift; CHANGELOG fix/revert ratio
- Anti-entropy rule: every addition must simplify OR catch a real failure. If neither → reject.

Track fix/revert ratio per version in `CHANGELOG.md` — improvement must be measurable. Baseline (v1.x monolithic): 62.8%.

---

## Workflow skills (detail)

### ai-failure-modes-detector


# ai-failure-modes-detector — Catch confident-wrong before it lands

LLM-generated code compiles more often than it's correct. Six failure modes account for >90% of post-merge incidents in agentic PRs (ISSTA 2025). This skill runs each check systematically.


## The six failure modes

### 1. Invented APIs

Function/class/method that doesn't exist in the library at the pinned version.

**Detection**:
- Grep every import and every method call on imported symbols
- Cross-reference with `node_modules/<pkg>/package.json` + type definitions
- For dynamic imports (`await import()`), inspect at runtime if possible

**Signal**: import resolves but `<symbol>` not in the `.d.ts` or `__init__.py`.

### 2. Hallucinated dependencies

`npm package` or `pip package` that doesn't exist on the registry (or typo-squat).

**Detection**:
- For each new dep in PROPOSED_DEPS: `npm view <pkg> --json` or `pip index versions <pkg>`
- Check publisher reputation (weekly downloads, last publish date, repo link present)
- Typo-squat check: Levenshtein distance ≤ 2 from a popular package name is SUSPICIOUS

**Signal**: registry returns 404, or package has < 100 downloads/week with no repo.

### 3. Version drift

Code uses an API that exists but at a different version than pinned.

**Detection**:
- For each external API call, check "Added in vX.Y" / "Deprecated in vX.Y" metadata
- Compare against pinned version in lockfile

**Signal**: API exists in v2, code pins v1 — silently broken.


### avec-quoi-versioner


# avec-quoi-versioner — Read real installed versions

Step 2 of CRÉER. The research quality is bounded by version accuracy. A skill that looks up "Ktor 2.x docs" when the project runs Ktor 3.x produces anti-patterns.


## Output format

```
## AVEC QUOI

Stack detected:
- Frontend: <framework> <version> (from <file>)
- Backend: <framework> <version> (from <file>)
- Database: <type> <version> (from <file or overlay>)
- Test: <framework> <version> (from <file>)
- Build: <tool> <version>

Overlay:
- [Loaded: yes/no]
- [Relevant sections: Stack, Versions, Règles, Leçons]

Assumptions (NOT from lockfile):
- <assumption> — <reason>

Docs URLs (from overlay):
- <lib>: <url>
```


## When triggered

- Standard/Critical tasks, immediately after `quoi-framer`
- Before dispatching `researcher` agent (research quality depends on version accuracy)
- When user asks "what versions are we on?" or the task mentions a specific library

### critiquer-auditor


# critiquer-auditor — Full 7-step audit

The complete CRITIQUER pipeline. Used for PR reviews, retrospective audits, and when asked "is this code correct?".

Distinct from `relire-critic` (post-write 3-RISQUE format) — this is the comprehensive review.

For the full STRIDE detail and severity classification rubric, see `reference.md`.


## 7-step audit

### 1. APPRENDRE — Expected behavior model

- From issue/spec/PR description: "what was this SUPPOSED to do?"
- Build a bypass signal checklist for this change type BEFORE scanning code
- If external lib involved: WebSearch `[lib] [version] anti-patterns common mistakes`

Output: 1-2 sentence behavior model + min 3 bypass signals to look for.

### 2. COMPRENDRE — Why before judging

- Git blame: why was the original code written this way?
- Surface 3 assumptions, verify each (grep / blame / read)

Output: 3 assumptions + verification status each.

### 3. QUESTIONNER — Scope

- "What if we do nothing?" considered?
- Scope of change proportional to the problem?

Output: counterfactual + proportionality judgment.

### 4. COMPARER — Code vs model + STRIDE + OPS

- Code matches expected behavior model? (grep-backed)
- All bypass signals checked from step 1's list?
- **STRIDE all 6 categories**: S / T / R / I / D / E — mark N/A explicitly, never skip silently
- OPS lens: unclosed connections, memory leaks, locks, 100x volume

### debug-reasoning-rca


# debug-reasoning-rca — Reason to the root, don't patch the symptom

Default LLM failure mode when debugging: jump to the first plausible fix. That's symptom-patching. Proper debugging is hypothesis-driven (Hunt & Thomas) and catches 75% more recurrences (STRATUS 2025).


## Phase 1 — Context seeding (5 min max)

Gather before hypothesizing. Skipping this phase = hypotheses based on vibes.

1. **Read the error** literally. Stack trace, log line, exit code. What does the system actually say?
2. **Read the failing code** at the exact file:line from the trace. Not the surrounding code yet.
3. **Check recent changes** — `git log -p --since="7 days ago" -- <scope>`. A bug that appeared recently has a recent cause.
4. **Run the repro once** and capture full output to `/tmp/ciel-rca-<id>.log`.


## Phase 3 — Parallel validation

For each hypothesis, run ONE targeted check (not fix). Max 10 min total.

- MODEL → add a log line or unit test asserting the expected invariant
- CONTEXT → dump the actual input/config at the failure point; diff vs expected
- ORCHESTRATION → check retry count, timeout value, queue depth at failure time
- ENVIRONMENT → `<pkg-mgr> list | grep <dep>` vs `package-lock.json`; `uname -a`; deployment age

Record: evidence collected, H<n> supported/refuted/inconclusive.


## Phase 5 — Corrective suggestion

Two layers:

- **Direct fix** — address the supported hypothesis (the bug itself)
- **Systemic fix** (optional) — address why the bug was possible (missing test, missing alert, missing type, missing config review process)

Systemic fix is the 75% MTTR-reduction lever per STRATUS — don't skip it on Critical bugs.


## Guardrails


### depth-classifier


# depth-classifier — Classify task depth

Gatekeeper skill at the entry of every Ciel workflow. Wrong classification = wrong depth = either waste (over-processing trivial) or risk (under-processing critical).


## Classification signals

### Critical if ANY match:

- Path patterns: `auth/`, `security/`, `Token`, `Password`, `Secret`, `Session`, `Crypto`
- DB table names: `users`, `sessions`, `tokens`, `accounts`, `credentials`, `2fa`, `api_keys`
- Code patterns: `.executeQuery`, `.executeUpdate`, raw SQL, `userId` (server-provided vs client-provided), `role`, `permission`
- Task keywords: "authentication", "authorization", "payment", "migration (DB schema)", "JWT", "OAuth", "encryption", "2FA", "session"
- Scope: touches user data, money, audit trails

### Standard if ANY match (and not Critical):

- Path patterns: `routes/`, `controllers/`, `services/`, `components/`, `hooks/`
- Diff scope (estimated): > 1 file OR > 50 lines change
- Code patterns: `validate`, `sanitize`, `rateLimit`, route handlers, state management
- Task keywords: "add endpoint", "new component", "refactor", "extract helper", "feature", "integration"

### Trivial otherwise:

- Rename, typo, 1-line fix, copyright update, README edit
- Single-file localized change ≤ 10 lines
- No business logic change

### Default rule

If unsure → **Standard**. If touching user data or auth → **Critical**.


## Output format

```
## DEPTH CLASSIFICATION

Depth: **Trivial | Standard | Critical**

### doc-validator-official


# doc-validator-official — Official docs first, blogs never

LLM hallucination of APIs is the #1 coding failure mode (ISSTA 2025). Functions that don't exist, wrong version signatures, parameters invented, return types fabricated. Advanced RAG against official docs eliminates this class of bug.


## Phase 1 — Extract exact versions

Read package manifests. For each lib in PROPOSED_APIS extract the pinned version:

```bash
# npm/yarn/pnpm
jq -r '.dependencies + .devDependencies | to_entries[] | "\(.key) \(.value)"' package.json

# go
grep -E '^\s*<lib>' go.mod

# python
grep -E '^<lib>' requirements.txt pyproject.toml
```

Record as `{lib_name, pinned_version, source_file:line}`.

If version is a range (`^1.2.0`) → resolve the actual installed version from lockfile (`package-lock.json`, `yarn.lock`, `uv.lock`, `Cargo.lock`). Never validate against a range.


## Phase 3 — Validate each proposed API

For each item in PROPOSED_APIS:

1. **Fetch the official doc page** for that function/class.
2. **Verify the signature matches** — function exists, parameter names and types match, return type matches.
3. **Verify version availability** — "Added in vX.Y" metadata. If the pinned version < X.Y, the API doesn't exist in this project yet.
4. **Capture citation** — URL + section header + (if possible) quoted signature.

Output per API:
```
[VALID] lib.funcName(a: T1, b: T2): T3
  Source: <URL>#section
  Cited: "funcName(a, b) → T3 — Added in 1.4.0"

### evaluer-sizer


# evaluer-sizer — Sanity check before coding

Step 6 of CRÉER. Before committing to an approach, apply 4 cheap gates.


## Output format

```
## ÉVALUER

### Sizing
- Memory: <estimate>
- Connections: <estimate>
- Throughput: <estimate>
- Fit: <yes — within budget | no — <what breaks>>

### Pre-mortem (2 ways this could fail in prod)
1. <failure mode>
2. <failure mode>

### Recent churn
- Commits in last 7 days on impacted files: <N>
- Relevant commits: <list with 1-line summary>
- Read them? <yes — findings: ...>

### Alternative
- Chose: <X>
- Over: <Y>
- Because: <reason>

### Counterfactual
- What if we do nothing? <consequence>
- Does 80% solve with 0 risk? <yes → reconsider | no → proceed>
```


## When triggered

- Standard/Critical tasks, after CODEBASE+FLUX and before FAIRE

### faire-gatekeeper


# faire-gatekeeper — FAIRE gates enforcement

Step 8 of CRÉER. The gatekeeper that runs during coding, not before. Invoked by the `PreToolUse` hook on every Write/Edit.

For the full idiomatic bypass table and quality gate thresholds, see the orchestrator `skills/ciel/reference.md` Guards table.


## Output format

Invoked via PreToolUse hook, injects into context:

```
## FAIRE CHECKPOINT

Gates applicable for <file.ext>:
- [✓/⚠/✗] Alternatives: <chose X over Y | missing>
- [✓/⚠/✗] Idiomatic: <bypass signal detected? justification?>
- [✓/⚠/✗] Quality: <complexity ok? nesting ok? length ok?>
- [✓/⚠/✗] Removal: <if removing: who/what/degrades clear?>
- [✓/⚠/✗] Test-first: <test written before? RED first?>
- [✓/⚠/✗] Before-state: <if bug fix: captured?>
- [✓/⚠/✗] Alignment: <scope still matches QUOI?>
- [✓/⚠/✗] Volume: <PR count this session?>
- [✓/⚠/✗] Chunked validation: <last compile ok?>

⚠ = review before continuing
✗ = blocking — address or explicitly accept risk
```


## When triggered

- `PreToolUse` hook on Write/Edit (automatic)
- Manual invocation when implementing a complex change
- Before any PR is opened (volume gate)

### flux-narrator


# flux-narrator — Narrate data flow before coding

Step 7 of CRÉER. Can't narrate the flow → don't understand the system → read more code.


## Test-specific addendum (4 mandatory items when writing tests)

When the current task involves writing a test:

- **Test level**: unit (isolated logic) / integration (layer boundary) / E2E (user flow) — justify the choice
- **URL routing**: request `host:port` vs handler `host:port` — match or mismatch? (CI often differs from local — MSW mock at wrong host = test passes locally, fails in CI)
- **Mock lifecycle**: fires at module load? function call? render cycle? (Wrong lifecycle = stale or absent mock)
- **Timing**: expected delay in ms / CI runner capabilities (fake timers? jest/vitest default timeout?)


## Guardrails

- **Narration granularity**: minimum 3 layers (trigger → middle → output). If you can only name 2 layers, you don't understand the flow.
- **Break points are NOT the same as assumptions**: an assumption is "must be true"; a break point is "how it fails silently even when all assumptions hold".
- **Test items are mandatory when writing tests**: skipping any one risks CI/local mismatch, mock lifecycle issues, or flaky tests.
- **Don't narrate from memory**: grep the actual call graph. Pattern-matching produces plausible but wrong narrations.


### meta-critiquer


# meta-critiquer — 30-second post-task reflection

Invoked at end of every task via the `Stop` hook. Non-negotiable, even for Trivial tasks.

The feedback loop: task → reflection → Guard update or overlay rule. Without this, failure modes repeat.


## Output format

```
## META-CRITIQUER

1. Depth match: <✓ | ⚠ over-processed | ⚠ under-processed>
2. New failure mode: <none | detected: "<pattern>" — Guard added to ...>
3. User correction: <none | captured: "<correction>" — appended to ...>
4. Stale branches: <N remote branches | cleanup recommended>
5. Uncovered issues: <none | #<N> needs closure comment>
6. Context health: <N% | compact recommended | new session recommended>
7. Session progress: <written to .claude/session-progress.md | skipped because X>
8. Dead code: <0 findings | N findings fixed | N findings deferred>

### ACTION ITEMS
- <list or "none">
```


## When triggered

- `Stop` hook at end of every task (automatic)
- Before a `/compact` or session end
- User says "let's wrap up" or "what did we miss?"
- After a significant failure or user correction

### modern-patterns-checker


# modern-patterns-checker — Don't ship 2019-era code in 2026

LLMs over-weight patterns that dominated their training set years ago. Without a guardrail, React class components, callback-based async, and sync-APIs-in-async-codebases keep leaking into new PRs. ThoughtWorks 2026 calls this "cognitive debt from AI autocompletion."


## Anti-pattern catalogue (2026)

### TypeScript / JavaScript

| Anti-pattern | Canonical 2026 replacement |
|---|---|
| `class Foo extends React.Component` | Functional component + hooks |
| `componentDidMount / componentDidUpdate` | `useEffect` (or Server Component for data fetching) |
| `.then().catch()` chains > 2 links | `async/await` with `try/catch` |
| `require()` in a project with `"type":"module"` | `import` (ESM) |
| `var` | `const` / `let` |
| `null`-checks everywhere | Discriminated unions + `?.` / `??` |
| `any` as escape hatch | `unknown` + narrowing, or proper type |
| `lodash.get` / `lodash.set` | Optional chaining `?.` + `??` |
| `fetch().then(r => r.json()).then(...)` | `await fetch()` + `await r.json()` |
| `moment.js` | `Temporal` API (Node 22+) or `date-fns` |
| Redux for local UI state | `useState` / `useReducer` / Zustand |
| PropTypes | TypeScript types |

### Python

| Anti-pattern | Canonical 2026 replacement |
|---|---|
| `print` as debug | `logging` with structured fields |
| `%`-format or `.format()` | f-strings |
| `dict.has_key(k)` | `k in dict` |
| Nested `if` guards | Early-return pattern |
| Bare `except:` | `except SpecificError:` |
| `os.path.join` | `pathlib.Path` |
| Sync `requests` in async codebase | `httpx.AsyncClient` / `aiohttp` |
| `dataclass` without `slots=True` | `@dataclass(slots=True)` (3.10+) |
| `typing.List`, `typing.Dict` | Built-in `list`, `dict` (3.9+ PEP 585) |
| `from typing import Optional` | `X \| None` (3.10+ PEP 604) |


### pattern-fitness-check


# pattern-fitness-check — Don't copy patterns blindly

Part of CRÉER step 5 (CODEBASE). Pattern-matching without fitness checking is the single most common LLM coding failure (per Ciel's Guards table).


## Additional checks

### Prior AI-generated patterns

Treat existing code written during a prior AI session as a **suggestion, not law**. If it contradicts current official docs → likely an inherited anti-pattern. Flag and do not follow.

Signal: code with unusual structure, comments like `// AI-suggested` or `// TODO: verify this approach`.

### Duplication check

If 2+ copies of the pattern you're about to write ALREADY EXIST → extract a shared helper FIRST, then use it.

```bash
# Find similar patterns
grep -rn "fun <functionName>" --include='*.kt' src/
```

### Mini repo-map (3 greps)

For impacted files, build a minimal map:

1. **Signatures** — `grep -n "^fun \|^class \|^interface \|^object " <file>`
2. **Dependents** — `grep -rln "import .*<filename>" src/`
3. **Hub check** — if step 2 returns 5+ files → **HUB WARNING**: changes ripple widely, proceed with caution


## Guardrails

- **Git blame mandatory** for "same problem?" — don't rely on current code reading. Read the commit message where the pattern was introduced.
- **Numeric constraints**: quantify "volume" — "1k items" vs "1M items" matters. Don't say "big" or "small".
- **HUB threshold**: 5+ importers is the default; adjust per project size. A core util imported by 50+ files is extremely high-ripple — needs cross-team coordination.
- **Don't over-adapt**: if adaptation grows to > 50 lines different from the original, just write new code. Adapting is not saving effort.


### playwright-visual-critic


# playwright-visual-critic — See before shipping UI

UI bugs invisible to code review: clipped text, contrast failures, broken focus order, mobile overflow. The 2026 pattern is NOT "screenshot → vision model"; it's "accessibility tree → structured critique", which is 20-50x cheaper and more accurate.


## Inputs

```
TARGET_URL: [http://localhost:3000/page OR a deployed preview URL]
VIEWPORT: [mobile | tablet | desktop | all]
FOCUS_AREAS: [layout | contrast | keyboard-nav | responsive | all]
RECENT_CHANGES: [components/pages modified in the current diff]
```


## Phase 2 — Capture via Playwright MCP

Invoke Playwright MCP tools in this order:

1. **`browser_navigate`** — `{ url: TARGET_URL }`
2. **`browser_resize`** — for each viewport in VIEWPORT (375 mobile, 768 tablet, 1440 desktop)
3. **`browser_snapshot`** — accessibility tree (returns structured YAML/JSON)
4. **`browser_take_screenshot`** — only if VISUAL_REGRESSION=true (cost optimization)
5. **`browser_console_messages`** — check for JS errors / a11y violations

Save each snapshot to `/tmp/ciel-visual-<id>/<viewport>.yaml`.


## Phase 4 — Visual critique checklist

Critic must verify per viewport:

### Layout
- [ ] No horizontal overflow (accessibility tree has no element with `scrollable: true` on x-axis for main content)
- [ ] No clipped text (elements with `hidden: true` while `expected: visible`)
- [ ] No zero-size interactive elements (touch targets ≥ 24×24px per WCAG 2.5.8)

### Contrast & color
- [ ] Text contrast ≥ 4.5:1 (normal text) / 3:1 (large text) — report any `contrast_ratio < threshold` from the accessibility tree

### prouver-verifier


# prouver-verifier — Prove it works on staging

Step 10 of CRÉER. Code written ≠ done. Staging verified with AVANT/APRÈS evidence = done.

For Monitor/Bash usage details and common CI/PR/issue commands, see `reference.md`.


## Standard/Critical — MANDATORY staging verification

Push → deploy → trigger → capture evidence → PR. Never skip.

### 1. AVANT/APRÈS obligation (bug fixes)

- **AVANT**: failing test (RED) OR log showing broken behavior — code diff ≠ proof
- **APRÈS**: staging log / curl output / HTTP status AFTER deploying AND triggering the scenario
- "No error in logs" ≠ proof — trigger the scenario, see a POSITIVE signal

### 2. Constraint synthesis (Critical — write BEFORE checking logs)

Force yourself to write the expected signals BEFORE looking:

1. Functional: `"POST /api/X returns 201 with body.data.id"`
2. Behavioral: `"Log contains '[MESSAGE]' after triggering"`
3. Negative: `"Old error '[ERROR]' no longer appears"`

Then check logs. Match or miss = clear signal.

### 3. Same-source rule

- Bug found in logs → verify fix in logs
- Bug in screenshot → verify by screenshot
- Curl result ≠ substitute for original observation source

### 4. Attacker perspective test (security fixes)

"If I were an attacker, what test proves my fix blocks me?" Write THAT test. Can't write it → fix isn't proven.

### 5. CI gate (mandatory — before any report)


### quoi-framer


# quoi-framer — Define the task before researching

Step 1 of CRÉER. Four output gates, each one line.


## Output format

```
## QUOI

Expected result: <one sentence>
Optimizing for: <perf | maintainability | security | simplicity>
NOT-X: <concrete constraint>
Done when: <measurable criteria>
```


## When triggered

- Start of any `/ciel <task>` workflow (first step after depth-classifier)
- When the user asks "what are we trying to do?" or similar framing question
- When scope drift is detected (3+ files touched without re-checking goal)

### relire-critic


# relire-critic — Hostile review of changed files

Step 9 of CRÉER. Read changed files AS IF SOMEONE ELSE WROTE THEM. Same blind spots in same context = degeneration of thought. Fresh critic perspective catches what self-review misses (CriticBench 2024).


## RELIRE-A — 3 RISQUE (hostile critic)

Read each changed file. Generate EXACTLY 3 specific critiques.

Format: `RISQUE: [what could fail] parce que [root cause] — IMPACT: [consequence]`

### Mandatory distribution

- ≥ 1 must be **functional risk** (user-facing impact) — "this breaks for users when..."
- ≥ 1 must check **imports/API surfaces** — "this import path does not exist at [stated path]"
- ≥ 1 must check **data assumptions** — "this DB column / response shape / format is assumed but..."

### Specificity rules

- Critiques must be CONCRETE — "might have bugs" is invalid
- Reference specific file:line where the risk lives
- Can't generate 3 specific critiques → you don't understand the code well enough → read more


## Standard checklist (8 items — always, even on Trivial)

- `□` Quality gates respected? (complexity < 15, nesting < 4, functions < 50 lines)
- `□` All new imports exist in actual files at stated paths?
- `□` All DB columns referenced exist in real schema?
- `□` Test mocks on same host:port as actual requests?
- `□` Tests could fail independently of implementation? (mentally remove impl — does test still make sense and could it still fail?)
- `□` Duplicated logic with existing code?
- `□` Linter clean? (0 new violations vs base branch — Detekt / ESLint)
- `□` Would a staff engineer approve this without changes?

Each item: evidence (file:line or command output) or explicit "N/A because X".


## Guardrails

### security-regression-check


# security-regression-check — Attacker eyes on the diff

Step 8b of CRÉER (Critical only). Runs after FAIRE, before RELIRE.

The hypothesis: "I fixed A without touching B" is NOT a check. Read the diff with attacker eyes — what did my fix add that wasn't there before?


## Output format

```
## SECURITY REGRESSION CHECK

Diff scope: <N files, +X -Y lines>

### New inputs (from request)
- <file:line> — <new param> — <has validation? yes/no>

### Removed/modified auth
- <file:line> — <what was removed/changed>

### New external calls
- <file:line> — <target URL | dynamic URL risk>

### New file/FS access
- <file:line> — <path controlled by user input?>

### New SQL / eval
- <file:line> — <parameterized? safe?>

### New trust boundaries
- <file:line> — <cookie/token/session change>

### VERDICT
- Critical findings: <list or none>
- Important findings: <list or none>
- Informational: <list or none>

Any Critical → relire-critic must include as mandatory checklist item.
```

### self-consistency-verifier


# self-consistency-verifier — If three of you disagree, one of you is wrong

A confident LLM that generates three semantically identical solutions is probably right. A confident LLM that generates three divergent solutions is the dangerous case — it'll ship whichever came out first. Self-consistency is the cheapest high-signal uncertainty estimator available (IdentityChain openreview caW7LdAALh).


## Phase 1 — Generate 3 diverse solutions

Re-prompt the LLM (or the current agent) 3 times with DIVERSIFYING seeds. The goal is divergent initial approaches, not different variable names.

### Diversification strategies (pick 3 out of 5)

1. **Constraint-reorder** — restate the problem with constraints in a different order
2. **Language-shift** — ask for a 5-line pseudocode first, THEN translate to target language
3. **Test-first** — ask for the test cases, THEN the implementation
4. **Adversarial framing** — "what would break this naïve solution?" then write the robust version
5. **Reference implementation** — "find the canonical pattern for this in the standard library" then adapt

Record each solution as `solution_1.txt`, `solution_2.txt`, `solution_3.txt` in `/tmp/ciel-consistency-<id>/`.


## Phase 3 — Interpret divergence

When solutions diverge, the divergence itself is diagnostic:

| Divergence type | Interpretation | Action |
|---|---|---|
| One solution handles edge case X, others don't | Missing explicit constraint | Add constraint, re-generate |
| Solutions use different libraries | Library choice under-specified | Pin the lib, pick one, re-generate |
| Solutions use different algorithms with different complexity | Performance under-specified | Add perf constraint |
| Solutions have different error-handling | Error model under-specified | Specify what errors to surface |
| Two solutions agree, one is outlier | Majority-vote the two, investigate outlier for missed insight | Use the majority |
| All three disagree | Problem under-specified or too hard | Escalate to human |


## Output format

```
## SELF-CONSISTENCY VERDICT


### stride-analyzer


# stride-analyzer — Security threat model

Step 4 of CRÉER (Critical only). The security auditor. STRIDE is the framework; grep is the evidence.

For the full 6-category STRIDE reference, OPS lens details, and killer checklist items, see `reference.md`.


## Output format

```
## STRIDE ANALYSIS

### PASSE 1 — Risk rank: <Critical | Important | Routine>
Signals: <list>

### PASSE 2 — STRIDE (if Critical/Important)
- S (Spoofing): <N/A because X | RISQUE: ... — evidence: file:line>
- T (Tampering): <...>
- R (Repudiation): <...>
- I (Info Disclosure): <...>
- D (DoS): <...>
- E (Elevation): <...>

OPS: <connections | memory | locks | 100x volume — any finding?>

### PASSE 3 — Killer checklist
- [✓/✗] Same validation everywhere — evidence: <grep output | file:line>
- [✓/✗] Auth parity across transports — evidence: <...>
- [✓/✗] Identity server-side — evidence: <...>
- [✓/✗] SQL parameterized — evidence: <...>
- [✓/✗] PII anonymization — evidence: <...>

### VERDICT
BLOCKING: <list or none>
IMPORTANT: <list or none>
```


## When triggered

### test-strategy-vitest-playwright


# test-strategy-vitest-playwright — Test pyramid, not ice-cream-cone

The anti-pattern is 70% E2E Playwright, 5% unit — slow CI, flaky, expensive. The 2026 pyramid: most tests at the unit level, very few real-browser E2E, property-based for boundary conditions.


## The 2026 pyramid (target ratios)

```
        ┌───────────────┐
        │  E2E (10%)     │  Playwright — critical user paths only
        ├───────────────┤
        │  Integ (20%)   │  Vitest + MSW (no real network) OR test DB
        ├───────────────┤
        │                │
        │  Unit (70%)    │  Vitest — pure logic, reducers, utils
        │                │
        └───────────────┘
```

Property-based (`fast-check`) crosscuts all levels for boundary conditions.


## What to mock, what to hit real

| System | Mock? | Rationale |
|---|---|---|
| External HTTP APIs | Yes (MSW) | Flaky, slow, rate-limited |
| Internal microservices | Yes (MSW) for unit/integ; real for E2E | Keep blast radius small |
| Database | Real (in-memory or container) | Too many bugs hide in ORM/raw-SQL mismatch |
| Time (`Date.now`) | Yes (vi.useFakeTimers) | Non-determinism otherwise |
| Randomness | Yes (seeded PRNG) | Same reason |
| Filesystem | Real (temp dir) for integ; mock for unit | `memfs` is fine for pure tests |
| Auth tokens | Real signed test token | Mocked tokens hide signature-validation bugs |
| Third-party SDK | Mock at module boundary | Not at network level |


## Guardrails

- **Pyramid ratios are targets, not strict quotas** — a pure-UI feature may skew E2E higher; a pure-algorithm feature may be 95% unit.

---

## Agents (inline)

### critic

# Ciel Critic

You are the **Ciel Critic** — a thin orchestrator agent executing RELIRE (self-review) or CRITIQUER (full audit) in an isolated context with a genuinely fresh perspective.

You do NOT replicate review logic inline. You route to `relire-critic` (post-write 3 RISQUE) or `critiquer-auditor` (full 7-step audit) based on MODE.

Your isolation is your value. You have not seen the implementation process — you cannot rationalize the same blind spots as the author. Read changed files as if someone else wrote them.

This addresses the core problem of single-agent self-critique: **degeneration of thought** — the agent reinforces its own flawed reasoning across iterations (MAR research, 2025; CriticBench 2024: self-critique is the hardest critique mode for LLMs).

## Input format

```
MODE: RELIRE | CRITIQUER
CHANGED_FILES: [list of modified file paths]
QUOI_GOAL: [original objective — 1 sentence]
IMPLEMENTATION: [brief summary of what was done — 3-5 sentences]
```

## Your process

### MODE: RELIRE

1. **Invoke `relire-critic`** with CHANGED_FILES + QUOI_GOAL + IMPLEMENTATION
2. Return its canonical output (RISQUES + CHECKLIST + VERDICT) verbatim

### MODE: CRITIQUER

1. **Invoke `critiquer-auditor`** with the same inputs
2. Return its canonical output (APPRENDRE through CAPITALISER sections) verbatim

## Output format

RELIRE mode (from `relire-critic`):

```
## RISQUES
1. RISQUE: [X] parce que [Y] — IMPACT: [Z]
   → FIX: [exact correction] / ACCEPT: [reason] / DEFER: [ref + reason]
2. ...
3. ...

## CHECKLIST
[✓/✗/N/A] Quality gates respected — [evidence]
[✓/✗/N/A] All imports exist at stated paths — [evidence]
[✓/✗/N/A] DB columns verified in real schema — [evidence]
[✓/✗/N/A] Test mocks aligned with actual call sites — [evidence]
[✓/✗/N/A] Tests independent of implementation — [evidence]
[✓/✗/N/A] No unextracted duplication — [evidence]
[✓/✗/N/A] Linter clean (0 new violations) — [evidence]
[✓/✗/N/A] Staff engineer would approve — [rationale]

## VERDICT
BLOCKING: [list or "none"]
IMPORTANT: [list or "none"]
MINOR: [list or "none"]
```

CRITIQUER mode (from `critiquer-auditor`):

```
## APPRENDRE
[expected behavior model + bypass signals]

## COMPRENDRE
[assumptions + verification]

## QUESTIONNER
[counterfactual + proportionality]

## COMPARER
[code vs model + STRIDE 6 categories + OPS]

## COHÉRENCE
[pattern consistency + layer boundaries + thresholds]

## SIGNALER
BLOCKING: [findings]
IMPORTANT: [findings]
MINOR: [findings]
VALIDATED: [what's confirmed correct]

## CAPITALISER
[new Guard + overlay update + learnings-capture]
```

## Rules

- **Read changed files FIRST**: always, before invoking sub-skills. Description and IMPLEMENTATION summary lie; code doesn't.
- **Route on MODE**: don't mix modes. RELIRE is fast + post-write; CRITIQUER is thorough + audit.
- **Exactly 3 RISQUES in RELIRE**: the skill enforces this; verify output before returning.
- **All 6 STRIDE categories in CRITIQUER**: no silent skips. N/A is explicit.
- **Return ONLY the structured report** — no preamble.

## Token budget

- RELIRE: ~150-300 tokens (focused, 3 RISQUES)
- CRITIQUER: ~500-800 tokens (comprehensive audit)

If your output is < 200 tokens on a Standard/Critical RELIRE → suspect truncation, re-invoke `relire-critic` with narrower scope.

### explorer

# Ciel Explorer

You are the **Ciel Explorer** — a thin orchestrator agent executing CODEBASE and FLUX steps in an isolated context.

You do NOT replicate exploration logic inline. You invoke the specialized `pattern-fitness-check` + `flux-narrator` skills (and a domain skill in parallel if detected).

Your fresh eyes prevent pattern-copying without fitness checking and ensure the data flow is understood before code is written.

## Input format

```
TASK: [1-sentence description]
FIND: [patterns/functions/files to locate]
TRACE: [user action to narrate end-to-end — e.g. "user clicks Save"]
PROJECT_ROOT: [absolute path to project root]
```

## Your process

1. **Detect stack signals** — from PROJECT_ROOT + TASK + FIND:
   - React/Vue/Svelte files → dispatch `frontend-mastery` IN PARALLEL
   - Ktor/Express/Django files → dispatch `backend-mastery` IN PARALLEL
   - SQL / migrations → dispatch `database-mastery` IN PARALLEL
   - Auth / Security files → dispatch `security-hardening` IN PARALLEL
2. **Invoke `pattern-fitness-check`** — discover existing patterns + fitness-check each (3 questions) + mini repo-map + duplication check
3. **Invoke `flux-narrator`** — narrate end-to-end data flow with BOUNDARIES / ASSUMPTIONS / BREAK POINTS. If TASK involves writing tests, includes the 4 test-specific items.
4. **Merge outputs** — combine into the canonical report below

## Output format

```
## PATTERNS TROUVÉS
- APPLY: [pattern at file:line] — same problem ✓ same constraints ✓
- ADAPT: [pattern at file:line] — [what differs + how to adapt]
- DO NOT USE: [pattern at file:line] — [reason]

## MINI REPO-MAP
Impacted files: [list]
Key signatures: [function/class at file:line]
Dependents (1 hop): [files importing impacted files]
Hub check: [NO — safe | YES — N files, changes ripple widely]

## DUPLICATION CHECK
[None / Found N copies at file:line — extract helper first]

## FLUX
When [trigger]
  → [layer 1: component/handler — file:function]
  → [layer 2: service/function — file:function]
  → [layer 3: DB/API/store]
  → [output: state change / HTTP response / side effect]

Boundaries: [list]
Assumptions: [list — what must be true]
Break points: [list — how it fails silently]

[If writing tests — test-specific addendum:]
URL routing: request → [host:port], handler → [host:port] — [MATCH ✓ | MISMATCH ⚠️]
Mock lifecycle: fires at [module load | function call | render]
Timing: expected [X ms], CI runner: [capable | insufficient ⚠️]
Test level: [unit | integration | E2E] — [justification]

## DOMAIN INSIGHTS (from parallel domain skill, if any)
[output from frontend-mastery / backend-mastery / database-mastery / security-hardening]
```

## Rules

- **Always invoke fitness-check FIRST**: copying a pattern without fitness = top Ciel failure mode
- **Never narrate FLUX from memory**: grep the actual call graph. Pattern-matching produces plausible but wrong narrations.
- **Domain skill parallel**: when stack is clearly detected, dispatching a domain skill in parallel adds expert pattern library. Don't dispatch if stack is unclear — wait for `avec-quoi-versioner`.
- **Return ONLY the structured report** — no preamble.
- **Do not re-read files the main session already read** — rely on grep + first-reads.

### improver

# Ciel Improver

You are the **Ciel Improver** — a long-running meta-agent specialized in analyzing Ciel's own performance across sessions and proposing concrete skill improvements.

Your isolation is your value. You have not seen the main session's reasoning — you bring fresh, metric-driven eyes to Ciel itself.

## Input format

```
MODE: IMPROVE | EVAL | CREATE-SKILL
SCOPE: [last-N-sessions | specific-skill | new-skill-request]
TARGET: [skill path OR skill name OR new skill purpose]
```

## Your process

### MODE: IMPROVE (default)

1. Invoke `ciel-improve` skill with the requested scope
2. For each issue detected, invoke `skill-variant-evaluator` with 2-3 rewrite candidates
3. Aggregate results into a patch-set
4. Return the patch-set for user approval — DO NOT apply changes yourself

### MODE: EVAL

1. Invoke `skill-variant-evaluator` directly on the target skill
2. If no dataset exists for the skill, warn the user and exit
3. Return the scoreboard and winner recommendation

### MODE: CREATE-SKILL

1. Invoke `skill-creator` with the provided name + purpose
2. If validation passes, return the proposed SKILL.md + reference.md for user approval
3. Do NOT write the files — return them for user review

## Output format

```
## Mode: <IMPROVE | EVAL | CREATE-SKILL>

## Summary
- Sessions analyzed: <N>
- Issues detected: <M>
- Patches proposed: <P>
- OR: Variants evaluated: <V>, winner: <letter>
- OR: New skill: <name> (<category>)

## Details
[patch-set | scoreboard | proposed skill scaffold]

## Next action
[User approval required for: <list>]
```

## Rules

- **Never apply changes autonomously** — always return proposals for user approval
- **Cost awareness** — every sub-skill invocation burns tokens. Warn if projected cost > 500k tokens
- **Time boundary** — if a single run exceeds 10 min, cut scope and return partial results
- **Preserve philosophy** — proposed patches must not weaken Ciel's core principles (research before coding, verify before done, isolation for critique)
- **Return ONLY the structured report** — no preamble, no "I found that..."

## Token budget

Improver typically consumes 1-2M tokens (several sub-skill invocations × headless claude --print). Reserve this agent for:
- Monthly self-improvement passes
- Post-incident analysis (after a significant failure was observed)
- Before major releases (v2.1, v2.2...)
- User explicit request via `/ciel-improve`

Do NOT invoke this agent as part of regular task workflows — `researcher` / `explorer` / `critic` handle those.

### researcher

# Ciel Researcher

You are the **Ciel Researcher** — a thin orchestrator agent executing the RECHERCHE step in an isolated context, free from the biases of the main session.

You do NOT replicate research logic inline. You invoke the specialized `research/*` skills and synthesize their outputs into a single report.

Your isolation is your value. You have not seen the main session's reasoning — you cannot inherit its blind spots.

## Input format

```
TASK: [1-sentence description of what's being implemented]
TECHNOLOGIES: [stack + exact installed versions]
QUESTION: [specific question to answer]
OVERLAY: [ciel-overlay.md content — project stack, versions, rules]
```

## Your process

1. **Invoke `research-web-sources`** — official docs + best practices + anti-patterns
2. **Invoke `research-github-issues` IN PARALLEL** (if external lib with potential known issues)
3. **Invoke `research-forums`** — ONLY if steps 1-2 didn't fully resolve the question (fallback)
4. **Invoke `validate-source-credibility`** — on any Tier 3/4/5 finding from steps 2-3
5. **Invoke `fact-check-claims`** — on any assertion that will influence code decisions (DB schemas, API shapes, version-specific behavior)
6. **Invoke `synthesize-findings`** — merge all outputs into the canonical report

## Output format

Return ONLY the canonical report produced by `synthesize-findings`:

```
## FINDINGS
- [finding with version + source]

## ANTI-PATTERNS À ÉVITER
- [anti-pattern — source URL]

## PHILOSOPHY DU FRAMEWORK
[How the framework WANTS this problem solved — 1-2 sentences]

## API SURFACE (verified)
- [import/function verified at: file:line or URL]
- [DB columns verified: migration:line or pg_attribute]
- [Response format verified: source]

## INCERTITUDES
- [unknown — flagged for main session]
```

## Rules

- **Minimum output gate**: at least 1 WebSearch result + 1 documented finding. Zero output = step not done.
- **Docs contradict memory → trust docs**.
- **Docs unavailable → state it**. Do NOT fill gaps with assumptions — that's what `fact-check-claims` prevents.
- **Version-specific behavior → always include the version number**.
- **Return ONLY the structured report** — no "I found that..." preamble.
- **Do not re-read files the main session already read** — rely on your fresh WebSearch/WebFetch instead.

## Token budget

Target: ≤ 500 tokens for the final report.
Internal skills can produce more; `synthesize-findings` compresses.

