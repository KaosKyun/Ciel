---
name: learnings-capture
description: Mines the recent conversation for user corrections and failure modes, extracts MISTAKE→RULE pairs, and appends them to .claude/learnings.md or ciel-overlay.md. Invoked automatically at session boundaries. Deduplicates against existing entries.
allowed-tools: Read, Bash
---

# learnings-capture — Auto-capture session learnings

## What this covers
Closes the feedback loop: every user correction or failure mode observed in a session becomes a persistent rule that Ciel applies in future sessions.

## Core principle
**Every correction is a learning opportunity.** If the user said "no, use X" — that becomes a rule. If a test failed because of Y — that becomes a rule. Capture it before the session ends.

## Inputs

- **conversation-scope**: last N turns to analyze (default 20)
- **target-file**: `local` → `.claude/learnings.md` | `project` → `ciel-overlay.md` | `auto` (default)

## Process

### 1. Scan recent turns

Read the last 20 turns. Skip if < 5 turns.

### 2. Extract signals

- **User corrections**: "no, use X", "stop doing Y", "always X", "never Y"
- **Failure modes**: test failures, CI red, "the fix broke X"
- **Positive patterns**: "that worked", "keep doing X"

### 3. Formulate MISTAKE → RULE pairs

```
[<date>] MISTAKE: <what happened> → RULE: <how to avoid it>
```

Example:
```
[2026-04-23] MISTAKE: used `npm install` despite project using Bun → RULE: check for bun.lockb before picking package manager
```

### 4. Classify scope

- **local** — project-agnostic → `.claude/learnings.md`
- **project** — tied to this project's stack → `ciel-overlay.md`

### 5. Deduplicate

Check if RULE portion (normalized) already exists. Skip if duplicate.

### 6. Append

Append new pairs at bottom of target file under `## Leçons projet` or `## Learnings`.

## Common patterns

### Good learning capture

```
# Session learnings captured

Turns analyzed: 15
Signals detected: 3
New pairs: 2
Duplicates skipped: 1

## Appended to ciel-overlay.md
- [2026-04-23] MISTAKE: used vi.mock() for internal service → RULE: use vi.spyOn() for internal logic, vi.mock() only for external I/O
- [2026-04-23] MISTAKE: committed .env file → RULE: check git diff --cached for .env before commit
```

### Bad learning capture

```
Captured some learnings.
```

Problems: no pairs, no dedup, no classification.

## Anti-patterns

- **Overwriting** — always append, never overwrite
- **Deleting** — even "wrong" learnings stay
- **Dedup threshold too low** — 80% lexical similarity = duplicate
- **> 10 pairs per session** — pick top 10, skip rest
- **PII captured** — filter passwords, tokens, emails before writing
- **No timestamp** — use `[YYYY-MM-DD]` format

## How to verify

- [ ] ≥ 1 turn analyzed?
- [ ] Signals detected and classified?
- [ ] MISTAKE → RULE pairs formatted correctly?
- [ ] Scope classified (local/project)?
- [ ] Deduplication performed?
- [ ] PII filtered out?
- [ ] Pairs appended (not overwritten)?

## When triggered

- `Stop` hook fires at session end
- `PreCompact` hook fires before context compaction
- User says "capture what we just learned"
- `meta-critiquer` invokes at step 3 (user correction detected)
