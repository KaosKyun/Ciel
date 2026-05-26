---
name: spike-mode
description: How to use SPIKE mode in Ciel — prototype/exploration mode with assoupli gates. Create.ciel/exploration.active to enter spike mode. Quality gates relaxed, code marked FIXME/TODO. Used for POC, draft, experimental, throwaway code. Must be refactored properly after.
---

# SPIKE Mode — Explore Without Commitment (Ciel)

## What this covers

How to use SPIKE mode in Ciel for prototyping and exploration. When you need to test an idea quickly without going through the full quality pipeline. The mode is triggered by creating a `.ciel/exploration.active` file in the project root.

## Core principle

**Speed over quality during exploration. Quality over speed for production.** SPIKE mode exists because sometimes you need to write throwaway code to validate an approach. But throwaway code that stays is technical debt.

## When to use SPIKE mode

- Prototyping a new feature
- Testing a library integration
- Exploring a complex refactoring
- Validating an architecture approach
- POC / proof of concept
- "I don't know if this will work, let me try"

Do NOT use SPIKE mode for:
- Production code
- Code you plan to keep
- Critical/security code
- Code you already know how to implement

## How to enter SPIKE mode

```bash
touch.ciel/exploration.active
```

The plugin detects this file and:
- Assouplit gates 1 (test-first) and 4 (quality)
- Injects SPIKE mode indicator in system prompt
- Marks all code as experimental

## How to exit SPIKE mode

```bash
rm.ciel/exploration.active
```

Or when the exploration is done,
- Refactor the experimental code properly
- Add tests
- Follow the full pipeline

## What changes in SPIKE mode

| Gate | Standard mode | SPIKE mode |
|------|---------------|------------|
| Test-first (RED) | Bloquant | Assoupli |
| Alternatives | Requis | Recommande |
| Idiomatic | Requis | Recommande |
| Quality (complexity, nesting) | Enforce | Assoupli |
| Removal safety | Requis | Requis |
| Boy-scout | Recommande | Recommande |
| FIXME/TODO markers | Optionnel | OBLIGATOIRE |

## Output format

When in SPIKE mode, add this to the plan:

```
## SPIKE MODE

Goal: <what are we trying to learn/prove?>
Exit criteria: <when is this exploration done?>
Markers: <files marked FIXME/TODO>
Follow-up task: <describe the proper implementation>
```

## Common rationalizations

| Rationalization | Reality |
|---|---|
| "I'll clean up the spike code later" | You won't. If you don't schedule the cleanup immediately, spike code becomes permanent debt. |
| "The gates are annoying, I'll use spike mode" | SPIKE mode is for when you DON'T KNOW the solution, not for when you don't WANT to write tests. |
| "This is just a quick prototype, no need for FIXME" | Unmarked prototype code looks like production code. Without FIXME, nobody knows it needs refactoring. Future you included. |
| "SPIKE mode means no rules" | SPIKE assouplit les gates mais ne les supprime pas. Security et removal restent actifs. |

## Rules

- **Code written in SPIKE mode MUST be marked FIXME or TODO**
- **SPIKE code MUST be refactored or removed after exploration**
- **SPIKE mode does not bypass security gates** (removal safety still applies)
- **Do not commit SPIKE code without refactoring**
- **SPIKE mode is for individual exploration sessions, not for PRs**

## How to verify

- [ ].ciel/exploration.active exists?
- [ ] All exploratory code has FIXME/TODO markers?
- [ ] Exit criteria defined?
- [ ] Follow-up task created for proper implementation?
- [ ] No SPIKE code committed without refactoring?
