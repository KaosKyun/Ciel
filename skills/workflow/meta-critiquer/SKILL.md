---
name: meta-critiquer
description: 30-second post-task reflection checking 8 items — depth match, new failure mode, user correction, stale branches, uncovered issues, context health, session progress file, dead code sweep. Invoked by the Stop hook at end of every task (non-negotiable, even for Trivial). Closes the feedback loop between task execution and Ciel self-improvement.
allowed-tools: Bash, Read, Grep
---

# meta-critiquer — 30-second post-task reflection

Invoked at end of every task via the `Stop` hook. Non-negotiable, even for Trivial tasks.

The feedback loop: task → reflection → Guard update or overlay rule. Without this, failure modes repeat.

---

## 8 checks

### 1. Depth match?
- Was the task processed at the right depth?
- Over-processed trivial = waste
- Under-processed critical = risk
- If wrong depth detected → flag to `learnings-capture` for future `depth-classifier` refinement

### 2. New failure mode?
- Did something go wrong that the current Guards didn't catch?
- If yes → add a new Guard NOW to `skills/ciel/reference.md` Guards table
- Invoke `learnings-capture` to persist

### 3. User correction?
- Did the user correct me during the task?
- If yes → update overlay or learnings.md
- Invoke `learnings-capture`

### 4. Stale branches?
```bash
git branch -r | wc -l
```
Excessive remote branches (> 30) → consider cleanup of merged branches. Command varies per project — check overlay.

### 5. Uncovered issues?
```bash
gh issue list --state closed --limit 10 --json number,comments
```
Any issue closed with 0 comments? → missing evidence comment → add it NOW before next task. Invoke `issue-closer` skill to add structured closure comment.

### 6. Context health?
- Context >50% after any agent dispatch round → recommend `/compact` to user (parenthetical, non-blocking)
- Context >70% → recommend new session
- Two Critical tasks in same context → mandatory new session recommendation
- Stacking Critical tasks in one context window degrades output quality

### 7. Session progress file
At each session boundary (task done, context > 70%, or before `/compact`): write `.claude/session-progress.md` with:
- Current status
- Completed tasks
- **Failed approaches + why they failed** (critical — prevents dead-end loops)
- Known limitations
- Next steps

Next session reads this instead of replaying history.

### 8. Dead code sweep
Run language-specific linter:
- **Python**: `ruff check --select F401,F811,F841 . && vulture . --min-confidence 80`
- **TypeScript**: `npx knip` or manual grep for unused exports
- **Kotlin**: Detekt `UnusedPrivateMember` + `UnusedImport` rules
- **Go**: `go vet ./...`
- **Rust**: `cargo clippy -- -W unused`

Fix findings before session end.

---

## Output format

```
## META-CRITIQUER

1. Depth match: <✓ | ⚠ over-processed | ⚠ under-processed>
2. New failure mode: <none | detected: "<pattern>" — Guard added to ...>
3. User correction: <none | captured: "<correction>" — appended to ...>
4. Stale branches: <N remote branches | cleanup recommended>
5. Uncovered issues: <none | #<N> needs closure comment>
6. Context health: <N% | compact recommended | new session recommended>
7. Session progress: <written to .claude/session-progress.md | skipped because X>
8. Dead code: <0 findings | N findings fixed | N findings deferred>

### ACTION ITEMS
- <list or "none">
```

---

## Guardrails

- **Always runs**: even after Trivial tasks (30s is cheap; missed reflections compound)
- **Always non-blocking**: this is a post-task reflection, never blocks the commit/push
- **Items 2 + 3 trigger `learnings-capture`**: don't just report, persist
- **Item 7 writes the session-progress file**: failed approaches field is the critical one — preserves what NOT to try again
- **Anti-entropy rule**: every new Guard added here must either simplify OR catch a real failure. Don't add theoretical Guards.

---

## When triggered

- `Stop` hook at end of every task (automatic)
- Before a `/compact` or session end
- User says "let's wrap up" or "what did we miss?"
- After a significant failure or user correction
