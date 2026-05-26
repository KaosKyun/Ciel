---
name: meta-critiquer
description: How to reflect on completed work — 10-item post-task reflection checklist for Ciel. Covers depth match, failure mode detection, user corrections, stale branches, uncovered issues, context health, dead code, map update, parking lot, and boy-scout rule. Closes the feedback loop between execution and improvement.
---

# Post-Task Reflection — 10-Item Checklist (Ciel)

## What this covers

How to reflect on completed work and capture learnings. In Ciel, this is the last pipeline step (etape 16: META). Always run after every task, even trivial ones.

## Core principle

**Always reflect, even after trivial tasks.** 30 seconds is cheap; missed reflections compound. In v5, the reflection covers not just the code but the project map, parking lot, and boy-scout rule.

## The 10 checks (v5)

### 1. Depth match?

Was the task processed at the right depth?
- Over-processed trivial = waste
- Under-processed critical = risk
- Wrong depth -> flag for future classifier refinement

### 2. New failure mode?

Did something go wrong that current gates didn't catch?
- Yes -> add a new gate immediately
- Capture the pattern for future reference (in .ciel/learnings.md)

### 3. User correction?

Did the user correct you during the task?
- Yes -> persist to .ciel/learnings.md
- Don't just note it -- save it so it doesn't happen again

### 4. Stale branches?

```bash
git branch -r | wc -l
```
Excessive remote branches (> 30) -> consider cleanup of merged branches.

### 5. Uncovered issues?

Any recently closed issues with 0 comments? -> missing evidence comment -> add it now.

### 6. Context health?

After Critical task or 3+ agent dispatches: consider context compression or new session. Stacking Critical tasks in one context window degrades output quality.

### 7. Dead code sweep

Run language-specific linter:
- **Python**: `ruff check --select F401,F811,F841 . && vulture . --min-confidence 80`
- **TypeScript**: `npx knip` or manual grep for unused exports
- **Kotlin**: Detekt `UnusedPrivateMember` + `UnusedImport`
- **Go**: `go vet ./...`
- **Rust**: `cargo clippy -- -W unused`

### 8. Map update (v5)

Has the project map (.ciel/map.json) been updated with new modules, key files, or patterns discovered during this task?
- If exploration happened -> update map
- If new ADR was written -> reference it in map

### 9. Parking lot (v5)

Were any tangential discoveries made during the task?
- Yes -> note in .ciel/parking.md
- Don't act on them now -- just note them

### 10. Boy-scout rule (v5)

Did you leave the code better than you found it?
- Minor improvements count: better naming, removed dead code, added missing test, improved error message
- If you only modified what was required and nothing else -> acceptable but note it

## Output format

```
## REFLECTION

1. Depth match: <match | over/under-processed>
2. New failure mode: <none | detected>
3. User correction: <none | captured in .ciel/learnings.md>
4. Stale branches: <N branches | cleanup recommended>
5. Uncovered issues: <none | #N needs closure>
6. Context health: <N% | compact recommended>
7. Dead code: <0 findings | N fixed>
8. Map update: <up-to-date | needs update>
9. Parking: <none | N notes added>
10. Boy-scout: <improved | status quo>

### ACTION ITEMS
- <list or "none">
```

## How to verify

- [ ] All 10 checks completed?
- [ ] >= 1 action item generated?
- [ ] User corrections captured (if any)?
- [ ] Stale branches flagged (if any)?
- [ ] Map checked for updates?
- [ ] Parking lot entries noted?

## Key rules

- **Always non-blocking**: reflection never blocks the commit/push
- **Persist, don't just report**: items 2 and 3 must trigger learnings capture
- **Map update (item 8) is mandatory after exploration**: without it, the next session starts with a stale map
