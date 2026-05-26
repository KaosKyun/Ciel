---
name: relire-critic
description: How to self-review code effectively — hostile critique methodology, risk taxonomy, and quality checklist. Generates exactly 3 targeted critiques (functional, import/API, data assumption) then resolves each. Applicable after any code change.
allowed-tools: Read, Grep, Glob, Bash
---

# Code Self-Review — Hostile Critique Methodology

## What this covers

How to review your own code as if someone else wrote it. Self-review fails because the author reinforces their own blind spots (degeneration of thought, CriticBench 2024). This methodology forces adversarial thinking.

## Core principle

Read changed files **as if someone else wrote them**. Your job is to find what could fail, not to confirm what works.

## Methodology: 3 RISQUES

Generate EXACTLY 3 specific critiques of the changed code. Not 2, not 5 — 3 forces focus.

### Mandatory distribution

Each set of 3 RISQUES must include:

1. **Functional risk** — what breaks for users? "This fails when..."
2. **Import/API surface check** — does this import path actually exist? Is the API contract correct?
3. **Data assumption check** — does this DB column / response shape / format actually match reality?

### Specificity rules

- Concrete, not abstract: "might have bugs" is invalid
- Reference specific `file:line` where the risk lives
- Can't generate 3 specific critiques → you don't understand the code → read more

### Format

```
RISQUE: [what could fail] parce que [root cause] — IMPACT: [consequence]
```

## Resolution

For each RISQUE, choose ONE:

- **FIX**: exact correction needed — name the code change
- **ACCEPT**: why the risk is acceptable (TTL? cosmetic? window < 1s?)
- **DEFER**: issue reference + why out of scope

If 0 fixes needed → suspicious. Re-examine for specificity.

## Quality checklist (8 items)

Apply after resolving RISQUES:

1. Quality gates respected? (complexity < 15, nesting < 4, functions < 50 lines)
2. All new imports exist in actual files at stated paths?
3. All DB columns referenced exist in real schema?
4. Test mocks on same host:port as actual requests?
5. Tests could fail independently of implementation?
6. Duplicated logic with existing code?
7. Linter clean? (0 new violations vs base branch)
8. Would a staff engineer approve this without changes?

Each item: evidence (`file:line` or command output) or explicit "N/A because X".

## Output format

```
## RISQUES
1. RISQUE: <X> parce que <Y> — IMPACT: <Z>
   → FIX/ACCEPT/DEFER: <resolution>
2....
3....

## CHECKLIST
- [✓/✗/N/A] <item> — <evidence>
...

## VERDICT
BLOCKING: <list or "none">
IMPORTANT: <list or "none">
MINOR: <list or "none">
```

## How to verify

- [ ] Exactly 3 RISQUES (no more, no less)?
- [ ] Distribution: 1 functional + 1 import + 1 data-assumption?
- [ ] Each RISQUE has file:line evidence?
- [ ] Each RISQUE has resolution (FIX/ACCEPT/DEFER)?
- [ ] Quality checklist (8 items) completed?
- [ ] VERDICT issued (BLOCKING/IMPORTANT/MINOR)?

## Common mistakes

- **Generic critiques**: "might not scale" → too vague. "Loads all users into memory at line 47, O(n)" → specific.
- **Skipping distribution**: all 3 are functional risks, no import or data check → incomplete.
- **Too many RISQUES**: 5 critiques dilute focus. Pick top 3 by severity.
- **Not reading code**: reviewing the description instead of the actual file → always read code first.
