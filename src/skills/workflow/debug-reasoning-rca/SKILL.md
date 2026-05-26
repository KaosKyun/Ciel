---
name: debug-reasoning-rca
description: How to debug systematically — hypothesis-driven root cause analysis methodology. 3 parallel hypotheses, fault-type taxonomy (model/context/orchestration/environment), semantic diff between expected and actual behavior. For bugs, incidents, flaky tests, regressions, production failures.
allowed-tools: Read, Grep, Glob, Bash
---

# Systematic Debugging — Root Cause Analysis Methodology

## What this covers

How to find the real cause of a bug, not just patch the symptom. Default LLM failure: jump to the first plausible fix. Proper debugging is hypothesis-driven (Hunt & Thomas) and catches 75% more recurrences (STRATUS 2025).

## Core principle

**Never propose a fix before a hypothesis is SUPPORTED by evidence.** "It might be this, let me fix it" is forbidden.

## Step 1: Gather context

Before hypothesizing, understand the failure:

- **Read the error literally** — stack trace, log line, exit code. What does the system actually say?
- **Read the failing code** at the exact `file:line` from the trace
- **Check recent changes** — `git log -p --since="7 days ago" -- <scope>`. A recent bug usually has a recent cause.
- **Run the repro** once and capture full output

Skip this step = hypotheses based on vibes.

## Step 2: Generate 3 hypotheses

Generate EXACTLY 3 **causally distinct** hypotheses. Not 3 variants of the same theory.

Format:
```
H<n>: <cause> → <mechanism> → <observable effect>
  Evidence for: <what would be true if correct>
  Evidence against: <what would be true if wrong>
  Fault-type: [MODEL | CONTEXT | ORCHESTRATION | ENVIRONMENT]
```

### Fault-type taxonomy

| Type | What it means | Example |
|------|--------------|---------|
| **MODEL** | Code logic wrong | Off-by-one, wrong algorithm, wrong assumption |
| **CONTEXT** | Missing/stale input | Wrong config, race window, state leak |
| **ORCHESTRATION** | Infrastructure misconfigured | Retry/timeout wrong, queue backlog |
| **ENVIRONMENT** | External change | Dependency drift, OS change, infra outage |

**Distribution rule**: hypotheses must span AT LEAST 2 fault-types. Three MODEL hypotheses = tunnel vision.

## Step 3: Validate (targeted checks)

For each hypothesis, run ONE targeted check (not fix):

- MODEL → add a log line or unit test asserting the expected invariant
- CONTEXT → dump actual input/config at failure point; diff vs expected
- ORCHESTRATION → check retry count, timeout, queue depth at failure time
- ENVIRONMENT → `<pkg-mgr> list | grep <dep>` vs lockfile; `uname -a`

Record: evidence collected, hypothesis supported/refuted/inconclusive.

## Step 4: Semantic diff

Once supported, write the diff between expected and actual:

```
EXPECTED: <behavior that should happen>
ACTUAL: <behavior that happens>
GAP: <precise mechanism>
ROOT: <why the gap exists — not "because of the bug", the underlying why>
```

If ROOT reads like "because the code is buggy" — you've only found the symptom. Ask "why" again.

## Step 5: Fix (two layers)

- **Direct fix** — address the supported hypothesis (the bug itself)
- **Systemic fix** — address why the bug was possible (missing test, missing alert, missing type)

Systemic fix is the 75% MTTR-reduction lever. Don't skip it on Critical bugs.

## Output format

```
## RCA VERDICT

### Symptom
<1 sentence>

### Repro
<exact command or "flaky — triggers ~1/N runs">

### Hypotheses explored
H1 [MODEL]: <cause> — <supported|refuted|inconclusive> — <evidence>
H2 [CONTEXT]: <cause> — <supported|refuted|inconclusive> — <evidence>
H3 [ORCHESTRATION]: <cause> — <supported|refuted|inconclusive> — <evidence>

### Root cause
<hypothesis number>: <cause>

### Semantic diff
EXPECTED/ACTUAL/GAP/ROOT

### Fix
- Direct: <exact code change>
- Systemic: <test/alert/process to add>

### Confidence
HIGH | MEDIUM | LOW — <why>
```

## Auto-inference (before asking the user)

Exhaust these sources before flagging input as unknown:

- **SYMPTOM** → grep last error in user's prompt; tail service logs; check recent PR descriptions
- **REPRO** → read `package.json` scripts, `Makefile`, `README.md`, test files, CI workflow
- **SCOPE** → `git diff HEAD~10 --stat` then rank by overlap with symptom keywords
- **RECENT_CHANGES** → `git log --since="7 days ago" --oneline -- <scope>`

State inferred values as `[ASSUMED from <source>]`. Only flag as `[UNKNOWN]` if truly blocking.

## How to verify

- [ ] ≥ 3 hypotheses generated (not just 1)?
- [ ] Each hypothesis has a fault type from the taxonomy?
- [ ] Semantic diff completed (EXPECTED vs ACTUAL vs GAP)?
- [ ] Root cause identified with evidence (file:line)?
- [ ] Fix addresses root cause, not symptom?
- [ ] Confidence level stated (HIGH/MEDIUM/LOW)?

## Anti-patterns

- **Patch-the-symptom**: add try/catch without understanding WHY it failed
- **Fix-the-test**: modify assertion to match wrong behavior instead of fixing code
- **Guess-and-check**: 5 commits titled "try fix" — no hypothesis discipline
- **First-hypothesis-wins**: commit first theory without validating alternatives
- **No repro, no RCA**: chasing intermittent bugs without deterministic repro burns hours

## Structured RCA methods (complementary)

The 3-hypothesis method above is the default — fast, hypothesis-driven, good for most bugs. For complex, recurrent, or systemic problems, these structured RCA methods add depth.

### Decision guide

| Problem type | Method | Why |
|-------------|--------|-----|
| Linear, single-symptom | **3 hypotheses** (default) | Fastest — parallel hypotheses, minimal overhead |
| Recurrent incident, process failure | **5 Whys** | Iterative questioning reaches systemic root cause |
| Multi-factor, need exhaustive exploration | **Ishikawa (Fishbone)** | 6M families (Method/Machine/Manpower/Material/Milieu/Measurement) guide complete coverage |
| Multi-layer, complex system | **Drill Down / Tree Diagram** | Decompose recursively (build → deploy → runtime → data) into atomic sub-causes; visualize as tree |
| Interacting causes, feedback loops | **Relations Diagram** | Map causal links, count outbound/inbound arrows to find drivers vs effects |

**When to use the full sequence**: if the problem involves ≥ 3 interacting factors across distinct system layers, use the full chain: Ishikawa (explore) → Relations Diagram (map interactions) → 5 Whys on each promising node → Tree Diagram (document). For simpler problems, pick one method from the guide.

### 5 Whys

Ask "why?" iteratively (5× typical) on the symptom. Each answer becomes the next question. Stop when the cause is systemic/process-level, not technical. **Anti-pattern**: stopping at "error 500" — the real cause may be "no integration test catches this path."

### Ishikawa (Fishbone)

Draw a horizontal spine ending at the problem (fish head). Add diagonal bones for 6 families: Method, Machine, Manpower, Material, Milieu, Measurement (adapt to software: Technology, Data/API). Branch sub-causes off each family. **Anti-pattern**: filling every family superficially — depth > breadth.

### Drill Down / Tree Diagram

Decompose the problem into 2-4 MECE sub-causes at each level, recursing until atomic (directly fixable). Visualize the result as a hierarchical tree with AND/OR logic per branch. These are the same analytical process — decomposition (Drill Down) and visualization (Tree Diagram). **Anti-pattern**: stopping at shallow levels — "module X crashes" isn't actionable, "method Y throws Z when condition W" is.

### Relations Diagram

List all discovered factors. For each pair, ask if causation exists and in which direction. Draw arrows. Count outbound (drivers) vs inbound (effects). Nodes with the most outbound arrows are root cause candidates. **Anti-pattern**: connecting everything — if most factors connect to most others, the diagram is not discriminating; focus on clear causal links only.

## Key insight

The hardest part of debugging is not finding the fix — it's resisting the urge to fix before understanding. The 3-hypothesis discipline forces you to consider alternatives before committing to one.
