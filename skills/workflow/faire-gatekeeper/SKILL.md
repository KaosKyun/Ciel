---
name: faire-gatekeeper
description: How to implement code safely — 9 quality gates covering alternatives, idiomatic patterns, code quality, removal safety, test-first discipline, before-state capture, alignment, volume, and chunked validation. A checklist for implementation discipline.
allowed-tools: Read, Grep, Bash
---

# Implementation Safety — 9 Quality Gates

## What this covers

How to implement code with discipline. These gates run during coding, not before — they catch problems as they happen.

## Core principle

**Check gates per-file, not per-task.** Each write/edit gets its own gate check.

## The 9 gates

### 1. Alternatives gate

"I chose X over Y because [reason]." No Y named → research alternatives first.

### 2. Idiomatic gate — justify any framework bypass

Common bypass signals that need justification:
- `window.*` / `document.*` in React → why not hook/ref/router?
- `for` + raw SQL → why not batch/ORM?
- `catch(e) { return null }` → why not Result/sealed class?
- `as X` without type guard → why not `is X`?
- Copying a block for the 3rd+ time → why not extract a helper?

Each bypass signal detected → justification required.

### 3. Quality gates

- Cyclomatic complexity < 15 per function
- Nesting depth < 4
- Function length < 50 lines

If any gate fails → refactor before committing.

### 4. Removal gate (before removing cache, feature, config, or dependency)

1. **Who uses it?** — grep all consumers
2. **What replaces it?** — identify the alternative
3. **What degrades?** — trace the impact path

"I don't know" → investigate before acting.

### 5. Test gate (before implementation code)

- Test written BEFORE implementation? (RED first)
- Test verifies observable behavior, not just code execution?
- Failure path tested at same priority as happy path?

### 6. Before-state capture (bug fix only)

Capture broken behavior IMMEDIATELY, before writing any code:
- Log excerpt showing the error
- Curl output showing wrong response
- Screenshot showing wrong UI

### 7. Alignment checkpoint (3+ files)

When 3+ files have been touched: re-read the task goal. Did scope grow? Is the approach still best?

### 8. Volume gate

Creating 3+ PRs in the same session → PAUSE. Verify labels + staging evidence on each PR before opening the next.

### 9. Chunked validation

After each file: compile? types OK? 2 consecutive fails → STOP. Don't keep coding through compilation errors.

## Output format

```
## GATES

- [✓/⚠/✗] Alternatives: <chose X over Y | missing>
- [✓/⚠/✗] Idiomatic: <bypass signal? justification?>
- [✓/⚠/✗] Quality: <complexity/nesting/length ok?>
- [✓/⚠/✗] Removal: <who/what/degrades clear?>
- [✓/⚠/✗] Test-first: <RED first?>
- [✓/⚠/✗] Before-state: <captured?>
- [✓/⚠/✗] Alignment: <scope matches goal?>
- [✓/⚠/✗] Volume: <PR count?>
- [✓/⚠/✗] Chunked: <compile ok?>

⚠ = review before continuing
✗ = blocking — address or accept risk
```

## How to verify

- [ ] All 9 gates checked (alternatives, idiomatic, quality, removal, test, before-state, alignment, volume, chunked)?
- [ ] Failed gates logged with ✓/⚠/✗ status?
- [ ] Gates are non-blocking (context injection, not write prevention)?
- [ ] Per-file basis applied (each write/edit gets its own check)?

## Key rules

- **Never block writes**: gates inject context, they don't prevent writes. Failed gates are warnings.
- **Per-file basis**: each write/edit gets its own check.
- **Quality thresholds**: match project linter config if stricter.
