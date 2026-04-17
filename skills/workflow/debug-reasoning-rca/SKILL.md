---
name: debug-reasoning-rca
description: Ciel's systematic debugging and root-cause analysis skill — THE skill to invoke for ANY bug, incident, flaky test, regression, production failure, "why did X not work", or "investigate this error". Generates 3 parallel hypotheses, classifies fault type (model vs context vs orchestration vs environment), performs semantic diff between expected and actual behavior, then proposes a corrective suggestion that addresses the root — not the symptom. 75% MTTR reduction vs ad-hoc debugging (STRATUS paper). Always prefer this over generic debugging approaches. Dispatched via @ciel-critic.
allowed-tools: Read, Grep, Glob, Bash
context: fork
agent: critic
---

# debug-reasoning-rca — Reason to the root, don't patch the symptom

Default LLM failure mode when debugging: jump to the first plausible fix. That's symptom-patching. Proper debugging is hypothesis-driven (Hunt & Thomas) and catches 75% more recurrences (STRATUS 2025).

---

## Inputs (infer before asking — see orchestrator's Autonomy protocol)

```
SYMPTOM: [user-visible or log-visible failure — 1 sentence]
REPRO: [minimal reproduction steps OR "not reproducible yet"]
SCOPE: [file paths / module / service suspected — or "unknown"]
RECENT_CHANGES: [commits / PRs landed in the last 7 days for the scope]
```

### Auto-inference sources (exhaust BEFORE asking the user)

- **SYMPTOM** → grep last error in user's prompt; tail `/var/log/<service>`; check `journalctl -u <service> -n 100` if systemd; read recent PR descriptions
- **REPRO** → read `package.json` scripts, `Makefile`, `README.md#usage`, test files, CI workflow for the command that failed; re-run the user's stated action via Bash if safe; use Playwright MCP to replay UI if configured
- **SCOPE** → `git diff HEAD~10 --stat` then rank by overlap with SYMPTOM keywords; `git blame` the top lines from the error trace
- **RECENT_CHANGES** → `git log --since="7 days ago" --oneline -- <scope>`; `gh pr list --state=merged --limit 10` if `gh` available

State the inferred values under `[ASSUMED from <source>]` at the top of the RCA. Only flag as `[UNKNOWN]` and pause if a critical input cannot be gathered after exhausting sources.

### Repro-first rule (autonomous variant)

If you cannot establish a deterministic repro after auto-inference:
1. Document the non-determinism (e.g., "triggers ~1/N runs based on logs showing 3/1000 occurrences")
2. Proceed with RCA on the most-likely hypothesis weighted by evidence frequency
3. Mark VERDICT with `confidence: LOW` and suggest adding telemetry before final fix

Do NOT bail out demanding a repro. Partial information + explicit uncertainty > zero progress.

---

## Phase 1 — Context seeding (5 min max)

Gather before hypothesizing. Skipping this phase = hypotheses based on vibes.

1. **Read the error** literally. Stack trace, log line, exit code. What does the system actually say?
2. **Read the failing code** at the exact file:line from the trace. Not the surrounding code yet.
3. **Check recent changes** — `git log -p --since="7 days ago" -- <scope>`. A bug that appeared recently has a recent cause.
4. **Run the repro once** and capture full output to `/tmp/ciel-rca-<id>.log`.

---

## Phase 2 — 3 parallel hypotheses

Generate EXACTLY 3 causally distinct hypotheses. Not 3 variants of the same theory.

Format each:
```
H<n>: <cause> → <mechanism> → <observable effect>
  Evidence for: <what would be true if H<n> is correct>
  Evidence against: <what would be true if H<n> is wrong>
  Fault-type: [MODEL | CONTEXT | ORCHESTRATION | ENVIRONMENT]
```

### Fault-type taxonomy (Anthropic 2604.08906)

- **MODEL** — code logic wrong, off-by-one, wrong algorithm, wrong assumption about data
- **CONTEXT** — missing/stale input, wrong config, race window, concurrency, state leak
- **ORCHESTRATION** — retry/timeout/circuit-breaker misconfigured, wrong service routing, queue backlog
- **ENVIRONMENT** — dependency version drift, OS/runtime change, infra outage, secret rotation

### Distribution rule

The 3 hypotheses must span AT LEAST 2 fault-types. Three MODEL hypotheses = tunnel vision, rejected.

---

## Phase 3 — Parallel validation

For each hypothesis, run ONE targeted check (not fix). Max 10 min total.

- MODEL → add a log line or unit test asserting the expected invariant
- CONTEXT → dump the actual input/config at the failure point; diff vs expected
- ORCHESTRATION → check retry count, timeout value, queue depth at failure time
- ENVIRONMENT → `<pkg-mgr> list | grep <dep>` vs `package-lock.json`; `uname -a`; deployment age

Record: evidence collected, H<n> supported/refuted/inconclusive.

---

## Phase 4 — Semantic diff

Once a hypothesis is supported, write the diff BETWEEN EXPECTED AND ACTUAL:

```
EXPECTED: <behavior that should happen>
ACTUAL:   <behavior that happens>
GAP:      <precise mechanism>
ROOT:     <why the gap exists — not "because of the bug", the underlying why>
```

Example (good):
```
EXPECTED: retry up to 3x with 100ms backoff
ACTUAL:   retry 1x then throws
GAP:      circuit breaker opens on first 5xx because threshold is 1
ROOT:     threshold was set to 1 in 2024-03 during an incident and never reverted
```

If ROOT reads like "because the code is buggy" — you've only found the symptom. Ask "why" again.

---

## Phase 5 — Corrective suggestion

Two layers:

- **Direct fix** — address the supported hypothesis (the bug itself)
- **Systemic fix** (optional) — address why the bug was possible (missing test, missing alert, missing type, missing config review process)

Systemic fix is the 75% MTTR-reduction lever per STRATUS — don't skip it on Critical bugs.

---

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

### Root cause (supported hypothesis)
<hypothesis number>: <cause>

### Semantic diff
EXPECTED: <...>
ACTUAL:   <...>
GAP:      <...>
ROOT:     <...>

### Fix
- Direct: <exact code change OR config flip OR rollback SHA>
- Systemic (Critical only): <test to add / alert to add / review process>

### Confidence
HIGH | MEDIUM | LOW — <why>

### If LOW confidence
<what additional signal would raise it — an extra log, a repro in staging, etc.>
```

---

## Guardrails

- **Repro-first rule**: no repro → no RCA. Chasing intermittent bugs without deterministic repro burns hours. Fix the repro gap first.
- **3 hypotheses, distinct fault-types**: prevents the "one-track mind" that LLMs default to.
- **No jump-to-fix**: do not propose a fix before a hypothesis is SUPPORTED by evidence. "It might be this, let me fix it" is forbidden.
- **Timebox**: Phase 1-3 = 30 min hard cap. If RCA inconclusive after 30 min → escalate to human (add mitigation, ship partial fix with ISSUE tracker link, don't guess).
- **Recent-change bias**: if a change landed in the last 24h and the bug started then, H1 should be "that change" — but still validate, don't assume.
- **Systemic fix optional on Standard, mandatory on Critical**: Critical bugs (auth, payments, data loss) must fix both the bug and the process gap.

---

## When triggered

- User reports a bug / test fails in CI / production incident alert
- `critic` agent dispatched with MODE=RCA
- Post-mortem for Critical incident
- Before patching a flaky test (to decide fix vs quarantine vs delete)

---

## Anti-patterns caught

- Patch-the-symptom: "add try/catch around the failing line" without understanding WHY it failed
- Fix-the-test: modify the assertion to match wrong behavior instead of fixing the code
- Guess-and-check: 5 commits each titled "try fix" — indicates no hypothesis discipline
- First-hypothesis-wins: commit the first theory without validating alternatives

---

## References

- AgentFixer (arxiv 2603.29848) — failure detection + fix recommendation pipeline
- STRATUS — multi-agent autonomous RCA, 75% MTTR reduction
- Hunt & Thomas, *The Pragmatic Programmer*, ch. "Debugging" — hypothesis-driven method
