---
name: diverge
description: How to explore 2-3 radically different approaches before choosing one (Ciel v5 etape 5). Used after AVEC QUOI, before RECHERCHE. Prevents single-approach bias and premature convergence. Use when the task is non-trivial and there are multiple valid approaches.
---

# Divergent Exploration — 2-3 Approaches Before Choosing (Ciel v5)

## What this covers

How to explore multiple approaches before committing to one. In Ciel v5, this is etape 5 (DIVERGE). The goal is to avoid premature convergence on the first viable approach that comes to mind.

## Core principle

**Generate 2-3 approaches before evaluating any of them.** The first approach that works is rarely the best. In v5, DIVERGE happens after AVEC QUOI (versions checked) and before RECHERCHE (external research).

## When to use

- Non-trivial tasks with multiple valid solutions
- Architectural decisions
- Library/framework choices
- Design patterns
- Database schema design
- API design

**When NOT to use**: 1-line fix, rename, trivial config change, obvious solution.

## The process

### Step 1: Generate at least 2 approaches

For each approach, describe:
- What it does (1-2 sentences)
- Key trade-offs (not "it's better" -- specific pros/cons)
- Implementation effort (rough estimate)
- Risk level (low/medium/high)

Approaches should be GENUINELY different. Not "use React vs use React with hooks" -- same approach. Bad:
- "Use PostgreSQL vs MySQL" (trivial database choice)
- "Use REST vs GraphQL" (genuinely different)

### Step 2: Let them compete (not you decide)

Generate approaches WITHOUT evaluating them. Evaluation happens in EVALUER (etape 9), after RECHERCHE has gathered external data about each approach.

Common trap: generating 2 approaches but immediately choosing the first one without research.

### Step 3: Document for EVALUER

Pass both approaches (with their trade-offs, effort, risk) to the EVALUER phase. The researcher should check documentation for BOTH approaches.

## Output format

```
## DIVERGE

### Approach A: <name>
What: <1-2 sentences>
Trade-offs:
  + <pro>
  - <con>
Effort: <XS/S/M/L/XL>
Risk: <low/medium/high>

### Approach B: <name>
What: <1-2 sentences>
Trade-offs:
  + <pro>
  - <con>
Effort: <XS/S/M/L/XL>
Risk: <low/medium/high>

### (Optional) Approach C: <name>
...
```

## Common rationalizations

| Rationalization | Reality |
|---|---|
| "I already know the best approach" | You know the first approach that came to mind. That's not the same as the best approach. Generate 2-3 then compare. |
| "Diverging takes too long" | It takes 5 minutes. Committing to the wrong approach costs days. The math is clear. |
| "There's only one valid way to do this" | There are almost always 2+ valid approaches. If you can't think of alternatives, you don't understand the problem well enough. |

## How to verify

- [ ] >= 2 genuinely different approaches generated?
- [ ] Approaches are different in kind, not degree?
- [ ] Trade-offs documented for each?
- [ ] Effort estimated?
- [ ] Risk assessed?
- [ ] Evaluation deferred to next phase (EVALUER)?
