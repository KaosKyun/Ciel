---
name: quoi-framer
description: How to frame a task before starting — forces explicit goal, NOT-X constraint, shared intention, and a measurable definition of done. Use at the start of any non-trivial task to prevent scope drift.
---

# Task Framing — Define Before You Start (Ciel)

## What this covers

How to define a task clearly before doing any work. Prevents scope drift, wasted research, and "I thought you meant..." conversations.

## Core principle

**State the goal, the constraint, the intention, and the done criteria BEFORE researching or coding.** If you can't state these in 5 lines, you don't understand the task yet.

## The 5 output gates (ALL required)

### 1. Expected result

One sentence. Concrete and testable.

- BAD: "Improve the API"
- GOOD: "GET /api/users returns a paginated list with page+limit query params"

### 2. NOT-X constraint

At least 1 concrete thing the solution MUST NOT do:
- "NOT-X: no N+1 queries"
- "NOT-X: no new dependencies added"
- "NOT-X: no breaking changes to existing callers"
- "NOT-X: no schema migration"

"no bad code" is not NOT-X. "No global state mutation" is.

### 3. Intentions partagees (v5)

State what you are looking for, not what you expect to find. This guides exploration without biasing it:
- BAD: "Find where pdfmake is used for PDF export" (cherche une solution specifique)
- GOOD: "Understand how exports are handled in this project" (intention ouverte)

The intention is passed to @ciel-explorer to guide scent-following without creating confirmation bias.

### 4. Definition of done

Measurable before research starts:
- "Done when: endpoint returns 200 with `{items, total, page}` shape, test passes on staging, no perf regression vs baseline"

"done when it works" is not acceptable. Specify the observable signal.

### 5. DOCS gate (v5)

Before framing, verify that documentation has been read:
- README.md (project overview and conventions)
- ADRs if they exist (architecture decisions)
- Tickets/specs (requirements context)
-.ciel/map.json (existing project map)
- ciel-overlay.md (project overlay)

## Output format

```
## QUOI

Expected result: <one sentence>
NOT-X: <concrete constraint>
Intentions: <what I'm looking for (open question)>
Done when: <measurable criteria>
Docs read: <yes — README, ADRs, map, tickets>
```

## Common rationalizations

| Rationalization | Reality |
|---|---|
| "This is simple, I don't need to frame it" | Simple tasks benefit from 2-line frames. The frame costs 10 seconds. Scope drift costs hours. |
| "I already know what to build" | Write it down anyway. Writing forces precision. "I know" is how ambiguity hides. |
| "NOT-X is obvious" | If it's obvious, writing it takes 2 seconds. If you can't write it, it wasn't obvious. |

## How to verify

- [ ] QUOI statement: 1 sentence, describes WHAT not HOW?
- [ ] NOT-X constraint: >= 1 explicit exclusion?
- [ ] Intentions partagees: open question, not solution-biased?
- [ ] Definition of done: >= 1 measurable criterion?
- [ ] DOCS gate: documentation has been read?

## When to re-frame

- Start of any task (before research)
- When scope drift is detected (3+ files touched without re-checking goal)
- When the user changes direction mid-task
