---
name: critiquer-auditor
description: Full 7-step CRITIQUER audit for reviewing or auditing existing code — APPRENDRE (expected behavior model), COMPRENDRE (why/assumptions), QUESTIONNER (scope), COMPARER (code vs model + STRIDE), COHÉRENCE (patterns + layers), SIGNALER (findings with severity), CAPITALISER (close loop). Invoked by critic agent in MODE=CRITIQUER for PR reviews, diff audits, or retrospective code quality checks.
allowed-tools: Read, Grep, Glob, Bash, WebSearch
context: fork
agent: general-purpose
---

# critiquer-auditor — Full 7-step audit

The complete CRITIQUER pipeline. Used for PR reviews, retrospective audits, and when asked "is this code correct?".

Distinct from `relire-critic` (post-write 3-RISQUE format) — this is the comprehensive review.

For the full STRIDE detail and severity classification rubric, see `reference.md`.

---

## Inputs

```
CHANGED_FILES: [list of modified file paths OR diff summary]
QUOI_GOAL: [original objective — if available]
IMPLEMENTATION: [brief description of what was done — if available]
```

**Entry rule**: read the diff/changed files FIRST. All subsequent steps operate on actual code, never on assumptions.

---

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

### 5. COHÉRENCE — Consistency

- Grep: pattern used consistently elsewhere in the codebase?
- Layer boundaries respected (no business logic in routes, no DB in controllers)?
- Health thresholds from overlay met (complexity, coverage)?

### 6. SIGNALER — Findings with severity

Format: `RISQUE: X parce que Y — IMPACT: Z`

Severity:
- **BLOCKING** — must fix before merge (correctness, security, data loss)
- **IMPORTANT** — should fix (degraded behavior, tech debt with near-term risk)
- **MINOR** — nice to fix (style, naming, low-risk improvement)
- **VALIDATED** — explicitly checked and confirmed correct; document what was verified

Every finding: RISQUE format. Every BLOCKING: specific FIX suggestion. Include NOT-X (what the solution must NOT do).

### 7. CAPITALISER — Close the loop

- New anti-pattern found? → add to Guards or project overlay
- New failure mode? → add Guard immediately
- Invoke `learnings-capture` to persist

---

## Output format

```
## CRITIQUER AUDIT

### APPRENDRE
Expected behavior: <1-2 sentences>
Bypass signals to check: <min 3 items>

### COMPRENDRE
Assumptions:
1. <assumption> — verified: <yes/no, evidence>
2. ...
3. ...

### QUESTIONNER
- Nothing-counterfactual: <consequence if no change>
- Scope proportional: <yes/no, reason>

### COMPARER
- Code vs model: <matches | deviates at file:line>
- Bypass signals checked: <N/3 flagged>
- STRIDE:
  - S: <N/A because X | RISQUE: ...>
  - T: ...
  - R: ...
  - I: ...
  - D: ...
  - E: ...
- OPS: <any finding?>

### COHÉRENCE
- Pattern consistency: <grep evidence>
- Layer boundaries: <clean | violation at file:line>
- Thresholds: <met | violation: ...>

### SIGNALER
BLOCKING:
- RISQUE: <X> parce que <Y> — IMPACT: <Z> → FIX: <exact correction>

IMPORTANT:
- RISQUE: <...> → <FIX/ACCEPT>

MINOR:
- <note>

VALIDATED:
- <what was verified correct>

### CAPITALISER
- New Guard to add: <yes/no — description>
- Overlay update: <yes/no — what>
- learnings-capture invocation: <triggered>
```

---

## Guardrails

- **Read the diff FIRST**: never operate from PR description alone. Description lies; code doesn't.
- **STRIDE is non-negotiable**: all 6 categories explicit. N/A is fine; silence is not.
- **RISQUE format strict**: parce que + IMPACT required. Generic "this might break" rejected.
- **BLOCKING has FIX**: if you can't name the fix, the finding isn't actionable enough for BLOCKING.
- **Include VALIDATED section**: reviews that only report problems miss what the code got right — dropping useful signal.

---

## When triggered

- `critic` agent in MODE=CRITIQUER
- PR audit: user says "review PR #X" or provides a diff
- Retrospective: "why did this ship with bug Y?" → audit the PR that shipped
- Before major release: audit recent PRs that touched critical paths
