---
name: ciel
description: Deep-reasoning workflow for coding tasks. Forces understanding before generating and verification before claiming done. Invoked automatically on any code modification task.
---

# Ciel — Deep-Reasoning Skill

Principle: **"Understand before generating. Verify before claiming done."**

## When to use

Cascade should invoke this skill for ANY code modification task — new features, bug fixes, refactors, component creation, route changes, service modifications.

## Depth Gauge — Classify FIRST

| Level | Signals | Steps |
|-------|---------|-------|
| **Trivial** | rename, typo, 1-line | QUOI -> CODEBASE -> FAIRE -> PROUVER |
| **Standard** | hook, route, component, service | Full CREER (skip SECURITE) |
| **Critical** | auth, DB schema, security, payment | Full CREER + SECURITE |

Unsure -> Standard. Touches auth/users/tokens -> Critical.

## CREER Pipeline

### 1. QUOI
- Expected result in 1 sentence
- NOT-X: 1 constraint the solution must NOT do
- What counts as "done"?

### 2. AVEC QUOI
- Read actual installed versions from package.json/build files (never memory)
- Load `ciel-overlay.md` if present

### 3. RECHERCHE (Standard/Critical)
- WebSearch: official docs + anti-patterns + framework philosophy
- Minimum: 1 search result + 1 documented finding + 1 anti-pattern
- "I already know this" = red flag you MUST research

### 4. SECURITE (Critical only)
- STRIDE all 6: Spoofing, Tampering, Repudiation, Info Disclosure, DoS, Elevation
- Killer checklist: same validation everywhere? SQL parameterized? Identity server-side?
- Show grep evidence for each item

### 5. CODEBASE (Standard/Critical)
- Grep existing patterns, check fitness: same problem? same constraints?
- Signatures before full files: `grep -n "^fun \|^class " <file>`
- Duplication check: 2+ copies -> extract helper first

### 6. EVALUER (Standard/Critical)
- Back-of-envelope sizing
- Pre-mortem: 2 ways this fails in production
- "I chose X over Y because [reason]." No Y = think harder
- "What if we do NOTHING?"

### 7. FLUX (Standard/Critical)
- Narrate: "When user does X -> Y fires -> Z handles -> state changes -> output"
- Mark BOUNDARIES + ASSUMPTIONS + BREAK POINTS
- Can't narrate = read more code first

### 8. FAIRE
- RED test FIRST, always
- Idiomatic gate: justify any framework bypass
- Quality gates: complexity < 15, nesting < 4, function < 50 lines
- Alignment checkpoint at 3+ files: re-read QUOI

### 9. RELIRE
- 3 critiques minimum: `RISQUE: [what] parce que [why] -- IMPACT: [consequence]`
- At least 1 functional risk (user-facing)
- Resolve each: FIX / ACCEPT / DEFER
- "Would a staff engineer approve this?"

### 10. PROUVER
- AVANT: evidence of broken behavior (log, curl, screenshot)
- APRES: staging trigger + positive evidence after fix
- CI gate: must be green before presenting results

## Guards

| Signal | Guard |
|--------|-------|
| "I already know this" | = red flag, MUST research |
| Writing code before test | Write RED test first |
| Self-critique finds 0 issues | Re-examine with fresh eyes |
| Same approach failed 2x | STOP. List 3 different approaches |
| File read 3+ times | Note pointer, evict content |

## Context Budget
- `<50%` normal depth
- `50-70%` prefer grep/signatures over full reads
- `>70%` no new research, finish current step
- `>85%` finish, commit, start new session
