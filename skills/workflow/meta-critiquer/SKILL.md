---
name: meta-critiquer
description: How to reflect on completed work — 8-item post-task reflection checklist covering depth match, failure mode detection, user corrections, stale branches, uncovered issues, context health, session progress, and dead code. Closes the feedback loop between execution and improvement.
allowed-tools: Bash, Read, Grep
---

# Post-Task Reflection — 8-Item Checklist

## What this covers

How to reflect on completed work and capture learnings. The feedback loop: task → reflection → improvement. Without this, failure modes repeat.

## Core principle

**Always reflect, even after trivial tasks.** 30 seconds is cheap; missed reflections compound.

## The 8 checks

### 1. Depth match?

Was the task processed at the right depth?
- Over-processed trivial = waste
- Under-processed critical = risk
- Wrong depth → flag for future classifier refinement

### 2. New failure mode?

Did something go wrong that current Guards didn't catch?
- Yes → add a new Guard immediately
- Capture the pattern for future reference

### 3. User correction?

Did the user correct you during the task?
- Yes → update overlay or learnings
- Don't just note it — persist it so it doesn't happen again

### 4. Stale branches?

```bash
git branch -r | wc -l
```
Excessive remote branches (> 30) → consider cleanup of merged branches.

### 5. Uncovered issues?

Any recently closed issues with 0 comments? → missing evidence comment → add it now.

### 6. Context health?

After Critical task or 3+ agent dispatches: consider context compression or new session. Stacking Critical tasks in one context window degrades output quality.

### 7. Session progress

At session boundary, write progress file with:
- Current status
- Completed tasks
- **Failed approaches + why they failed** (critical — prevents dead-end loops)
- Known limitations
- Next steps

### 8. Dead code sweep

Run language-specific linter:
- **Python**: `ruff check --select F401,F811,F841 . && vulture . --min-confidence 80`
- **TypeScript**: `npx knip` or manual grep for unused exports
- **Kotlin**: Detekt `UnusedPrivateMember` + `UnusedImport`
- **Go**: `go vet ./...`
- **Rust**: `cargo clippy -- -W unused`

## Output format

```
## REFLECTION

1. Depth match: <✓ | ⚠ over/under-processed>
2. New failure mode: <none | detected — Guard added>
3. User correction: <none | captured — persisted>
4. Stale branches: <N branches | cleanup recommended>
5. Uncovered issues: <none | #N needs closure>
6. Context health: <N% | compact recommended>
7. Session progress: <written | skipped>
8. Dead code: <0 findings | N fixed>

### ACTION ITEMS
- <list or "none">
```

## How to verify

- [ ] All 8 checks completed (depth, failure mode, correction, branches, issues, context, progress, dead code)?
- [ ] ≥ 1 action item generated?
- [ ] User corrections captured (if any)?
- [ ] Stale branches flagged (if any)?
- [ ] Learnings captured for corrections?

## Key rules

- **Always non-blocking**: reflection never blocks the commit/push
- **Persist, don't just report**: items 2 and 3 must trigger learnings capture
- **Failed approaches matter most**: the session progress file's failed-approaches field prevents dead-end loops in future sessions
- **Anti-entropy**: every new Guard must either simplify OR catch a real failure. No theoretical Guards.
