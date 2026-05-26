---
name: critiquer-auditor
description: How to audit code comprehensively — 7-dimension review methodology covering expected behavior, assumptions, scope, code-vs-model comparison, STRIDE security, pattern consistency, and findings with severity. For PR reviews, retrospective audits, and "is this code correct?" questions.
allowed-tools: Read, Grep, Glob, Bash, WebSearch
---

# Code Audit — 7-Dimension Review Methodology

## What this covers

How to do a thorough code audit. Distinct from quick self-review (relire-critic) — this is the comprehensive methodology for PR reviews, retrospective audits, and quality checks.

## Core principle

**Read the diff/changed files FIRST.** All dimensions operate on actual code, never on assumptions. Description lies; code doesn't.

## Dimension 1: Expected behavior model

From issue/spec/PR description: "what was this SUPPOSED to do?"

- Build a bypass signal checklist for this change type BEFORE scanning code
- If external lib involved: search `[lib] [version] anti-patterns common mistakes`

Output: 1-2 sentence behavior model + min 3 bypass signals to look for.

## Dimension 2: Assumptions

- Git blame: why was the original code written this way?
- Surface 3 assumptions, verify each (grep / blame / read)

Output: 3 assumptions + verification status each.

## Dimension 3: Scope

- "What if we do nothing?" considered?
- Scope of change proportional to the problem?

Output: counterfactual + proportionality judgment.

## Dimension 4: Code vs model + STRIDE + OPS

- Code matches expected behavior model? (grep-backed)
- All bypass signals checked from dimension 1's list?
- **STRIDE all 6 categories**: S / T / R / I / D / E — mark N/A explicitly, never skip silently
- OPS lens: unclosed connections, memory leaks, locks, 100x volume

### STRIDE reference

| Category | What to check |
|----------|--------------|
| **S**poofing | Authentication bypass, identity assumption |
| **T**ampering | Data integrity, unauthorized modification |
| **R**epudiation | Audit trail, logging completeness |
| **I**nformation disclosure | Data exposure, error messages, logs |
| **D**enial of service | Resource exhaustion, infinite loops, missing limits |
| **E**levation of privilege | Authorization bypass, role escalation |

## Dimension 5: Consistency

- Grep: pattern used consistently elsewhere in the codebase?
- Layer boundaries respected (no business logic in routes, no DB in controllers)?
- Health thresholds from overlay met (complexity, coverage)?

## Dimension 6: Findings with severity

Format: `RISQUE: X parce que Y — IMPACT: Z`

Severity levels:
- **BLOCKING** — must fix before merge (correctness, security, data loss). Requires specific FIX.
- **IMPORTANT** — should fix (degraded behavior, tech debt with near-term risk)
- **MINOR** — nice to fix (style, naming, low-risk improvement)
- **VALIDATED** — explicitly checked and confirmed correct

Every finding: RISQUE format. Every BLOCKING: specific FIX + NOT-X (what solution must NOT do).

## Dimension 7: Close the loop

- New anti-pattern found? → add to Guards or project overlay
- New failure mode? → add Guard immediately
- Capture learnings for future reference

## Output format

```
## AUDIT

### Expected behavior
<1-2 sentences + bypass signals>

### Assumptions
1. <assumption> — verified: <yes/no, evidence>
2....
3....

### Scope
- Nothing-counterfactual: <consequence if no change>
- Scope proportional: <yes/no, reason>

### Code vs model + STRIDE
- Code vs model: <matches | deviates at file:line>
- Bypass signals: <N/3 flagged>
- STRIDE:
  - S: <N/A because X | RISQUE:...>
  - T/R/I/D/E:...

### Consistency
- Pattern: <grep evidence>
- Layers: <clean | violation at file:line>
- Thresholds: <met | violation>

### Findings
BLOCKING: <RISQUE + FIX>
IMPORTANT: <RISQUE + FIX/ACCEPT>
MINOR: <note>
VALIDATED: <what was verified>

### Learnings
- New Guard: <yes/no>
- Overlay update: <yes/no>
```

## How to verify

- [ ] All 7 dimensions completed (Expected behavior, Assumptions, Scope, Code vs model + STRIDE, Consistency, Findings, Learnings)?
- [ ] All 6 STRIDE categories present (even if N/A)?
- [ ] Findings have severity (BLOCKING/IMPORTANT/MINOR)?
- [ ] VALIDATED section identifies what code got right?
- [ ] Learnings captured?

## Common mistakes

- **Operating from PR description alone**: always read the actual code
- **Skipping STRIDE categories**: all 6 must be explicit, even if N/A
- **BLOCKING without FIX**: if you can't name the fix, it's not actionable enough for BLOCKING
- **No VALIDATED section**: reviews that only report problems miss what the code got right
