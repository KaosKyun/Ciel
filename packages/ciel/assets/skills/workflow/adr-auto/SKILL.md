---
name: adr-auto
description: How to capture a significant architectural decision as an ADR (Architecture Decision Record) in docs/adrs/ while it's fresh. Use right after making a non-trivial design choice, so the rationale isn't lost.
---

# Automatic ADR — Document Decisions in Real Time (Ciel)

## What this covers

How to document architectural decisions while they're fresh. When a task involves a significant architectural decision, write an ADR to docs/adrs/ — capturing the rationale now, not months later.

## Core principle

**If the decision was non-trivial, document WHY.** Code shows WHAT. ADRs show WHY. Without ADRs, future developers (or future you) will wonder why the code is the way it is.

## When to write an ADR

Write an ADR when the task involves:
- Adding a new dependency/library
- Choosing between two technologies
- Changing a database schema
- Adopting a design pattern
- Making a performance trade-off
- Changing the build/deploy pipeline
- Any decision with long-term consequences

Do NOT write an ADR for:
- Bug fixes (tests document the fix)
- Refactoring without semantic change
- Renames/reorganizations
- Dependency upgrades (changelog suffices)

## ADR format (based on Michael Nygard's template)

```
# ADR-<NNN>: <Title>

## Status

<proposed | accepted | deprecated | superseded by ADR-NNN>

## Context

<What is the issue that we're seeing that is motivating this decision or change? 2-3 sentences.>

## Decision

<What is the change that we're proposing and/or doing? 1-2 sentences.>

## Consequences

<What becomes easier or harder to do because of this change? 2-3 items.>

## References

<Link to relevant docs, tickets, or PRs>
```

## File naming

`docs/adrs/<NNN>-<kebab-case-title>.md`

Start at 001 and increment.

## How to trigger (Ciel)

When writing the ADR:
1. Check if the task involved a significant decision (see list above)
2. If yes -> write `docs/adrs/<NNN>-<title>.md`
3. Update `.ciel/map.json` to reference the new ADR
4. Reference the ADR in the RELIRE submission so the critic can check it

## Common rationalizations

| Rationalization | Reality |
|---|---|
| "The code is self-documenting" | Code shows WHAT. ADRs show WHY. Six months from now, "why did we choose this" is not visible in the code. |
| "I'll add it later" | Later is when the decision is forgotten and the context is lost. Write it now or it never gets written. |
| "This decision is too small for an ADR" | If you had to think about it for more than 30 seconds, it's big enough for an ADR. |
| "Nobody reads ADRs anyway" | Nobody reads them until they need to undo a decision and can't figure out why it was made. Then they're invaluable. |

## How to verify

- [ ] ADR written for every significant decision?
- [ ] No ADR written for trivial changes?
- [ ] ADR includes context, decision, consequences?
- [ ] Map updated with ADR reference?
- [ ] ADR committed with the code?
