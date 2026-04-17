---
name: relire-critic
description: Generates exactly 3 hostile critiques (RISQUE format) of changed files — at least 1 functional risk (user-facing), 1 import/API surface check, 1 data assumption check — then resolves each with FIX/ACCEPT/DEFER. Runs the standard 8-item RELIRE checklist. Invoked by the PostToolUse hook on Write/Edit; dispatched as critic agent in fork context for Standard/Critical tasks with 3+ files.
allowed-tools: Read, Grep, Glob, Bash
---

# relire-critic — Hostile review of changed files

Step 9 of CRÉER. Read changed files AS IF SOMEONE ELSE WROTE THEM. Same blind spots in same context = degeneration of thought. Fresh critic perspective catches what self-review misses (CriticBench 2024).

---

## Inputs

```
CHANGED_FILES: [list of modified file paths]
QUOI_GOAL: [original objective — 1 sentence]
IMPLEMENTATION: [brief summary of what was done — 3-5 sentences]
```

---

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

---

## RELIRE-B — Resolve each RISQUE

For each critique, choose ONE:

- **FIX**: exact correction needed — name the code change
- **ACCEPT**: why the risk is acceptable (TTL? cosmetic? window < 1s?)
- **DEFER**: issue reference + why out of scope (`#123 — blocked by X upstream`)

If 0 fixes needed → suspicious. Re-examine critiques for specificity (they might be too abstract).

---

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

---

## Output format

```
## RELIRE VERDICT

### RISQUES
1. RISQUE: <X> parce que <Y> — IMPACT: <Z>
   → FIX: <exact correction> / ACCEPT: <reason> / DEFER: <#issue + reason>

2. RISQUE: <X> parce que <Y> — IMPACT: <Z>
   → <resolution>

3. RISQUE: <X> parce que <Y> — IMPACT: <Z>
   → <resolution>

### CHECKLIST
- [✓/✗/N/A] Quality gates respected — <evidence>
- [✓/✗/N/A] All imports exist at stated paths — <evidence>
- [✓/✗/N/A] DB columns verified in real schema — <evidence>
- [✓/✗/N/A] Test mocks aligned with actual call sites — <evidence>
- [✓/✗/N/A] Tests independent of implementation — <evidence>
- [✓/✗/N/A] No unextracted duplication — <evidence>
- [✓/✗/N/A] Linter clean (0 new violations) — <evidence>
- [✓/✗/N/A] Staff engineer would approve — <rationale>

### VERDICT
BLOCKING: <list or "none">
IMPORTANT: <list or "none">
MINOR: <list or "none">
```

---

## Guardrails

- **Exactly 3 RISQUES**, not 2, not 5. 3 forces focus. If you find 5, pick the top 3 by severity.
- **No generic critiques**: "might not scale" → unspecific, rejected. "Loads all users into memory at line 47, O(n) with no pagination — breaks at 100k users" → specific, accepted.
- **Distribution rule strict**: skipping the import check or the data check is a common error path. All 3 types required.
- **Trivial inline mode**: when invoked directly (not via critic agent), runs inline in the current context. Still produces same format.
- **Standard/Critical via critic agent**: when dispatched via critic agent, runs in fork context for fresh perspective. Agent loads this skill as its task.

---

## When triggered

- `PostToolUse` hook on Write/Edit (automatic) — inline format
- `critic` agent in MODE=RELIRE, Standard tasks with 3+ files changed
- `critic` agent in MODE=RELIRE, ALL Critical tasks (mandatory, no inline alternative)
- User request: "review what I just wrote"
