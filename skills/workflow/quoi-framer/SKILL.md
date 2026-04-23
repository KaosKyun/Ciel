---
name: quoi-framer
description: How to frame a task before starting — forces explicit goal, optimization axis, NOT-X constraint, and measurable definition of done. Prevents scope drift by making the frame explicit before research or coding starts.
---

# Task Framing — Define Before You Start

## What this covers

How to define a task clearly before doing any work. Prevents scope drift, wasted research, and "I thought you meant..." conversations.

## Core principle

**State the goal, the constraint, and the done criteria BEFORE researching or coding.** If you can't state these in 4 lines, you don't understand the task yet.

## The 4 output gates (ALL required)

### 1. Expected result

One sentence. Concrete and testable.

- BAD: "Improve the API"
- GOOD: "GET /api/users returns a paginated list with page+limit query params"

### 2. Optimization axis

Pick ONE primary target:
- `perf` — latency, throughput, resource usage
- `maintainability` — readability, reuse, lowered coupling
- `security` — attack surface reduction, auth hardening
- `simplicity` — fewer parts, less code, less config

Picking 2 usually means picking none. Force a choice.

### 3. NOT-X constraint

At least 1 concrete thing the solution MUST NOT do:
- "NOT-X: no N+1 queries"
- "NOT-X: no new dependencies added"
- "NOT-X: no breaking changes to existing callers"
- "NOT-X: no schema migration"

"no bad code" is not NOT-X. "No global state mutation" is.

### 4. Definition of done

Measurable before research starts:
- "Done when: endpoint returns 200 with `{items, total, page}` shape, test passes on staging, no perf regression vs baseline"

"done when it works" is not acceptable. Specify the observable signal.

## Output format

```
## QUOI

Expected result: <one sentence>
Optimizing for: <perf | maintainability | security | simplicity>
NOT-X: <concrete constraint>
Done when: <measurable criteria>
```

## How to verify

- [ ] QUOI statement: 1 sentence, describes WHAT not HOW?
- [ ] NOT-X constraint: ≥ 1 explicit exclusion?
- [ ] Definition of done: ≥ 1 measurable criterion?
- [ ] Optimization axis: if applicable, stated explicitly?
- [ ] All 4 gates present (Expected result, Optimization, NOT-X, Done)?

## When to re-frame

- Start of any task (before research)
- When scope drift is detected (3+ files touched without re-checking goal)
- When the user changes direction mid-task
