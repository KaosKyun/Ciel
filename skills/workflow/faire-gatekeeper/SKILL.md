---
name: faire-gatekeeper
description: How to implement code safely — 6 quality gates for Ciel v5 (test-first, alternatives, idiomatic, quality, removal, boy-scout). SPIKE mode relaxes gates. A checklist for implementation discipline during FAIRE (etape 11).
---

# Implementation Safety — 6 Quality Gates (Ciel v5)

## What this covers

How to implement code with discipline during Ciel v5 FAIRE phase (etape 11). These gates run during coding and are enforced by the plugin or hooks. SPIKE mode relaxes some gates.

## Core principle

**Check gates per-file, not per-task.** Each write/edit gets its own gate check. In SPIKE mode, gates 1 and 6 are optional but the code must be marked FIXME/TODO.

## The 6 gates (v5)

### Gate 1: Test-first (RED)

Do not write source code before the test exists. If no `*.test.*` file exists:
- OpenCode: plugin blocks via tool.execute.before
- Claude Code: hook blocks via exit 2

**SPIKE mode**: relaxed. Exploration code may be written without tests, but must be marked FIXME/TODO.

### Gate 2: Alternatives

"I chose X over Y because [reason]." No Y named -> research alternatives first.

### Gate 3: Idiomatic

Common bypass signals that need justification:
- `window.*` / `document.*` in React -> why not hook/ref/router?
- `for` + raw SQL -> why not batch/ORM?
- `catch(e) { return null }` -> why not Result/sealed class?
- `as X` without type guard -> why not `is X`?
- Copying a block for the 3rd+ time -> why not extract a helper?

### Gate 4: Quality

- Complexity: < 15 (cyclomatic)
- Nesting: < 4 levels
- Function length: < 50 lines
- File length: < 400 lines

**SPIKE mode**: relaxed. Exploration code may be longer or complex, but must be marked FIXME/TODO.

### Gate 5: Removal safety

If you are DELETING code:
- Who uses it? (grep for imports/references)
- What replaces it?
- What degrades if not replaced?
- Is there a migration path?

### Gate 6: Boy-scout (v5)

After the change: is the code better than before?
- Minor improvements count: better naming, removed dead code, added missing test
- If the file was already touched, leaving it better is cheap
- If nothing to improve, note "status quo" explicitly

## Output format

```
## FAIRE gates

Gate 1 (test-first): <PASS | BLOCKED | SPIKE>
Gate 2 (alternatives): <X > Y because ...>
Gate 3 (idiomatic): <PASS | bypass justified: ...>
Gate 4 (quality): <complexity N, nesting N, length N | PASS>
Gate 5 (removal): <no removal | safe: ...>
Gate 6 (boy-scout): <improved: ... | status quo>
```

## How to verify

- [ ] Test exists (or spike mode active)?
- [ ] Alternative considered and documented?
- [ ] No unjustified framework bypass?
- [ ] Complexity < 15, nesting < 4, function < 50 lines?
- [ ] Removals checked for dependents?
- [ ] Code better than before?

## SPIKE mode behavior

When `.ciel/exploration.active` exists:
- Gate 1 (test-first): relaxed
- Gate 4 (quality): relaxed
- Gates 2, 3, 5: always active
- Gate 6 (boy-scout): recommended but not blocking
- Exploration code MUST be marked FIXME or TODO

## Key rules

- **Gates are non-negotiable in Standard/Critical mode**: plugin/hooks enforce them
- **SPIKE mode is for exploration only**: gates are relaxed, but code must be refactored properly after
- **Gate 5 matters most**: deleting code without checking dependents is the fastest way to break production
- **Boy-scout is the cheapest improvement**: if you already read the file, clean it up
