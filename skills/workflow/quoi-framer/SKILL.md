---
name: quoi-framer
description: Forces the author to state the task goal in one sentence plus an explicit NOT-X constraint and a measurable definition of done. Prevents scope drift by making the frame explicit before research or coding starts. Use at the very beginning of every Ciel task, after depth classification.
---

# quoi-framer — Define the task before researching

Step 1 of CRÉER. Four output gates, each one line.

---

## Output gates (ALL required)

1. **Expected result** — in one sentence. Must be concrete and testable.
   - BAD: "Improve the API"
   - GOOD: "GET /api/users returns a paginated list with page+limit query params"

2. **Optimization axis** — pick ONE primary target:
   - `perf` — latency, throughput, resource usage
   - `maintainability` — readability, reuse, lowered coupling
   - `security` — attack surface reduction, auth hardening
   - `simplicity` — fewer parts, less code, less config

3. **NOT-X constraint** — at least 1 concrete thing the solution MUST NOT do:
   - "NOT-X: no N+1 queries"
   - "NOT-X: no new dependencies added"
   - "NOT-X: no breaking changes to existing callers"
   - "NOT-X: no schema migration"

4. **Definition of done** — measurable before research starts:
   - "Done when: endpoint returns 200 with `{items, total, page}` shape, test passes on staging, no perf regression vs baseline"

---

## Output format

```
## QUOI

Expected result: <one sentence>
Optimizing for: <perf | maintainability | security | simplicity>
NOT-X: <concrete constraint>
Done when: <measurable criteria>
```

---

## Guardrails

- **All 4 fields mandatory** — if any field is vague or missing, the skill output is incomplete. Push back, ask for clarification.
- **NOT-X must be concrete** — "no bad code" is not NOT-X. "No global state mutation" is.
- **Done must be observable** — "done when it works" is not acceptable. Specify the observable signal.
- **Single axis** — picking 2 optimization axes usually means picking none. Force a choice.

---

## When triggered

- Start of any `/ciel <task>` workflow (first step after depth-classifier)
- When the user asks "what are we trying to do?" or similar framing question
- When scope drift is detected (3+ files touched without re-checking goal)
