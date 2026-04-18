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
| **Standard** | hook, route, component, service, **review open PRs + fix blocking CI** | Full pipeline minus `stride-analyzer` + `security-regression-check` |
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
3. **Project management setup** (if fix/feature intent — skippable with `--no-pm` if user explicit):
   - `issue-creator` — GitHub issue with RCA / feature spec / acceptance criteria
   - `branch-setup` — `fix/<N>-<slug>` or `feat/<N>-<slug>` branch from fresh origin/main
4. **researcher agent** → `research-web-sources` + `research-github-issues` + `validate-source-credibility` + `synthesize-findings` + `fact-check-claims`
5. **explorer agent** → `pattern-fitness-check` + `flux-narrator` + domain skill parallel (e.g. `frontend-mastery` when React detected)
6. `evaluer-sizer` — sizing + pre-mortem + recent-churn + alternative + counterfactual
7. `faire-gatekeeper` during coding → `commit-writer` adds `Refs #<N>` footers
8. **critic agent** MODE=RELIRE → `relire-critic` (if 3+ files OR auth/security; else inline)
9. `prouver-verifier` — AVANT/APRÈS evidence + CI gate + PR body gate + issue comment gate + closure gate + staging-verifier. **MUST complete before `gh pr merge --auto` — auto-merge is the consequence of this gate passing, not a parallel shortcut. Enabling auto-merge without first running prouver-verifier skips the evidence capture and blurs accountability when CI flakes mid-queue.**
10. `pr-opener` — opens PR with `Closes #<N>`, body composed by `pr-body-generator`
11. `ci-watcher` — streams CI for this PR, distinguishes flaky vs real failures (≥15% fail rate on main = flaky → `gh run rerun --failed`, else hand off to `debug-reasoning-rca`)
12. `pr-review-responder` — if reviewers post comments (reviewDecision=CHANGES_REQUESTED), respond per thread (accept → fix + SHA ref, reject → rebuttal, clarify → defer), mark resolved, re-request review
13. `pr-merger` — reads branch protection, flips draft→ready, picks squash/rebase/merge from repo settings, `gh pr merge --auto`. Blocked until `prouver-verifier` VERDICT=DONE + `ci-watcher` green + all threads resolved
14. `issue-closer` — post-merge, adds evidence comment + closes issue
15. `branch-cleaner` — deletes merged branch locally + prunes remote-tracking refs
16. `changelog-updater` — on version-bump PRs, appends Keep-a-Changelog entry
17. `release-publisher` — on version bump post-merge, creates signed tag + GitHub Release with auto-notes + Sigstore attestations (if `cicd-security-hardener` configured them)
18. `meta-critiquer`

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
| "create CI/CD", "set up pipeline", "add GitHub Actions", greenfield CI/CD, CI/CD migration | **`cicd-pipeline-designer`** → **`cicd-security-hardener`** (audit generated) | inline → `@ciel-explorer` |
| Changes to `.github/workflows/`, `.gitlab-ci.yml`, pipeline review (existing) | **`cicd-security-hardener`** | `@ciel-explorer` |
| "accessibility audit", WCAG, a11y, frontend PRs | **`accessibility-wcag-auditor`** | `@ciel-explorer` |
| Changes to `skills/**/SKILL.md`, skill review | **`skills-first-design-auditor`** | `@ciel-improver` |
| "fix", "bug fix", "feature", "implement", after any RCA verdict | **`issue-creator`** → **`branch-setup`** → (FAIRE work) → **`pr-opener`** → **`ci-watcher`** → **`pr-merger`** → **`issue-closer`** → **`branch-cleaner`** | inline (all utility skills) |
| "merge PR", "enable auto-merge", "land this PR", "squash and merge" | **`pr-merger`** (after `prouver-verifier` + `ci-watcher` green) | inline |
| "respond to review", "reviewer commented", "CHANGES_REQUESTED", "address PR feedback" | **`pr-review-responder`** | inline |
| "watch CI", "is CI green?", "CI is flaky", "rerun failed jobs", "CI stuck" | **`ci-watcher`** | inline |
| "clean up branches", "delete merged branches", "prune stale branches" | **`branch-cleaner`** | inline |
| "publish release", "create release", "tag v*", "ship the release", "release notes" | **`release-publisher`** (after `changelog-updater`) | inline |
| "mcp server", "mcp config", ".mcp.json", "claude mcp", "serveurs mcp" | **`debug-reasoning-rca`** (config drift + failures) + `stride-analyzer` if secrets found | `@ciel-explorer` for config read → `@ciel-critic` MODE=RCA |

**Routing rule**: on every `/ciel <task>` invocation, scan the task text for these intent signals BEFORE classifying depth. If an intent matches, queue the corresponding skill(s) to dispatch after `quoi-framer`. Multiple intents can match (e.g., "debug the auth flow in production" → `debug-reasoning-rca` + `security-regression-check` + STRIDE on Critical).

**Anti-collision rule with Claude Code natives**: the phrases "systematic debugging", "root cause analysis", "bug investigation" MUST route to `debug-reasoning-rca`, never to `systematic-debugging` (native). Ciel's RCA is more structured (3 hypotheses, fault-type taxonomy, semantic diff) and the user's `/ciel` invocation explicitly opted in to Ciel discipline.

**Mid-session re-routing rule** (added v2.4.1): the routing table above is **not one-shot at invocation**. Re-scan it on every `Edit` / `Write` tool call using the **target file path** as the signal (in addition to the prompt-text scan done at invocation). Examples:

- First edit targets `.github/workflows/ci.yml` → row 7 matches → dispatch `cicd-security-hardener` via `@ciel-explorer` **before writing the edit**, even if the original prompt was "review open PRs".
- First edit targets `skills/**/SKILL.md` → row 9 matches → dispatch `skills-first-design-auditor` via `@ciel-improver` before writing.

A task that **starts** as "PR review" can drift into "CI hardening" mid-session — the routing table must catch that drift. Not re-routing here is the failure mode documented in the 2026-04-17 audit (intent routing miss on `cicd-security-hardener`).

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

### Dispatch gate — STOP gathering, START forking

**Hard rule**: gather ONLY the inputs the target skill declares in its INPUTS section. As soon as all declared fields are filled (with `[ASSUMED]` or `[UNKNOWN]` markers where auto-inference failed), **IMMEDIATELY dispatch via the Task tool**. Further investigation belongs INSIDE the fork, not in the main session.

**Budget**: max 5 Bash/Read/Grep calls OR 2 minutes of gathering — whichever comes first. Past that threshold, dispatch with whatever you have and let the fork drill down.

**[DISPATCH GATE] hard-stop** (added v2.4.1 after PR-review audit): on the **5th** inline Bash/Read/Grep call of a Standard+ task, emit a visible checkpoint to the user:

```
[DISPATCH GATE] Budget exhausted (5 inline calls). Dispatching @ciel-researcher + @ciel-explorer now with [ASSUMED] markers for unresolved inputs. Further investigation continues inside the forks.
```

Then **immediately** issue the Task() dispatches on the same turn. No "one more check first", no "let me just verify X" — those belong in the fork. Skipping this checkpoint on a Standard+ task is a dispatch-discipline failure and triggers the `Dispatch gate bypass` guard in `reference.md`.

**Anti-pattern (observed in v2.1.5)**:
```
❌ Main session:
   - journalctl ... (gather)
   - curl health ... (gather)
   - ps aux ... (gather)
   - curl direct IP ... (gather)
   - curl FlareSolverr API ... (gather)
   - ... 10+ inline Bash calls, 20K+ tokens burned in main session
   [never dispatches — does RCA inline]
```

**Correct pattern**:
```
✅ Main session:
   - journalctl (one call, extract SYMPTOM)
   - git log (one call, extract RECENT_CHANGES)
   - grep scope from stack trace (extract SCOPE)
   - Inputs filled with [ASSUMED] markers
   - Task(subagent_type="ciel-critic", prompt="MODE=RCA SYMPTOM=... REPRO=... SCOPE=... RECENT_CHANGES=...")
   [dispatch — fork continues gathering + runs the 3-hypothesis RCA]
```

The fork has access to the same tools (via its permitted list) and can deepen the investigation without polluting the main session's context.

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

**Concrete Task tool syntax** — use EXACTLY this shape:

```
Task(
  subagent_type="ciel-critic",   # or ciel-explorer, ciel-researcher, ciel-improver
  description="short 3-5 word task",
  prompt="MODE=RCA
SYMPTOM=<1 sentence>
REPRO=<command or 'flaky — <freq>'>
SCOPE=<file paths or module>
RECENT_CHANGES=<git log summary>

[ASSUMED from git log --since='7d']
- ...

Execute debug-reasoning-rca Phases 1-5. Return RCA VERDICT in the documented format."
)
```

**Per-skill dispatch mapping**:

- `debug-reasoning-rca` → `subagent_type="ciel-critic"` + `MODE=RCA` + INPUTS
- `doc-validator-official` → `subagent_type="ciel-researcher"` + TARGET_STACK + PROPOSED_APIS + PACKAGE_SOURCES
- `modern-patterns-checker` → `subagent_type="ciel-explorer"` + CODE_UNDER_REVIEW + TARGET_STACK
- `ai-failure-modes-detector` → `subagent_type="ciel-explorer"` + CODE_UNDER_REVIEW + AUTHOR
- `self-consistency-verifier` → `subagent_type="ciel-critic"` + PROBLEM + STAKES
- `test-strategy-vitest-playwright` → `subagent_type="ciel-explorer"`
- `playwright-visual-critic` → `subagent_type="ciel-explorer"` (+ Playwright MCP)
- `cicd-security-hardener` → `subagent_type="ciel-explorer"`
- `accessibility-wcag-auditor` → `subagent_type="ciel-explorer"`
- `skills-first-design-auditor` → `subagent_type="ciel-improver"`
- `pattern-fitness-check`, `flux-narrator` → `subagent_type="ciel-explorer"`
- `critiquer-auditor`, `stride-analyzer`, `security-regression-check` → `subagent_type="ciel-critic"`
- `research-web-sources`, `research-github-issues`, `research-forums`, `fact-check-claims`, `validate-source-credibility` → `subagent_type="ciel-researcher"`

**Troubleshoot**: if `Task(subagent_type="ciel-<role>", ...)` errors with "unknown subagent_type", the agent files weren't installed with frontmatter. Run `bash install.sh` to register them (v2.1.6+ installs frontmatter).

### Inline-OK skills (Skill tool direct)

- `ciel` (this orchestrator) — must stay inline; it IS the main session's reasoning trace
- `depth-classifier`, `quoi-framer`, `avec-quoi-versioner` — deterministic, fast, feed the main pipeline
- `faire-gatekeeper`, `evaluer-sizer` — active during main-session implementation
- `relire-critic` (inline fallback for Trivial / Standard <3 files; dispatched via `@ciel-critic` for 3+ files or Critical)
- `meta-critiquer`, `prouver-verifier` — end-of-task orchestration in main session
- `synthesize-findings` — aggregates research outputs back in main session
- `learnings-capture` — writes to `ciel-overlay.md` from main session (writes are ok here)
- **GitHub workflow utility skills** (all inline — deterministic `gh` / `git` commands):
  - `issue-creator` — `gh issue create` with RCA-derived body
  - `branch-setup` — `git checkout -b fix/<N>-<slug>` from fresh origin
  - `commit-writer` — conventional commits + `Refs #<N>` footer
  - `pr-opener` — `gh pr create` with `Closes #<N>`
  - `pr-body-generator` — composes the PR body from commits + evidence
  - `ci-watcher` — `gh run watch` streaming + flaky vs real classification + auto-retry
  - `pr-review-responder` — GraphQL review-thread listing + classify/reply/resolve + re-request review
  - `pr-merger` — `gh pr merge --auto` with branch-protection awareness + draft→ready flip
  - `issue-closer` — `gh issue comment` with production evidence + close
  - `branch-cleaner` — `git branch --merged` delete + `git fetch --prune` + opt-in remote delete
  - `changelog-updater` — appends Keep-a-Changelog entry on version bump
  - `release-publisher` — `git tag -s` + `gh release create --generate-notes` + Sigstore attestations

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
| Post-agent-dispatch + >50% | Proactive | Suggest `/compact` before next task (non-blocking) |
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
