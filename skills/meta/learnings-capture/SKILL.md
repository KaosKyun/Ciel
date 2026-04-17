---
name: learnings-capture
description: Mines the recent conversation for user corrections and failure modes, extracts MISTAKE→RULE pairs, and appends them to .claude/learnings.md (local) or ciel-overlay.md (project-specific). Invoked automatically by Stop and PreCompact hooks at session boundaries. Deduplicates against existing entries. Never overwrites — always appends with timestamp.
allowed-tools: Read, Bash
---

# learnings-capture — Auto-capture session learnings

Closes the feedback loop: every user correction or failure mode observed in a session becomes a persistent rule that Ciel applies in future sessions.

For capture heuristics and dedup logic, see `reference.md` (not created — this skill is intentionally small).

---

## Inputs

- **conversation-scope**: last N turns to analyze (default 20)
- **target-file**: `local` → `.claude/learnings.md` | `project` → `ciel-overlay.md` | `auto` → determined by content (default `auto`)

---

## Process

### 1. Scan recent turns

Read the last 20 turns (or configured N). Skip if session has fewer turns.

### 2. Extract signals

For each turn, identify:

- **User corrections**: phrases like "no, use X", "stop doing Y", "always X", "never Y", "that's wrong because Z", "actually X"
- **Failure modes**: test failures after code written, CI red after push, user said "the fix broke X"
- **Positive patterns**: user said "that worked", "good, keep doing X" — rarely captured but noted

### 3. Formulate MISTAKE → RULE pairs

Each signal becomes a pair:

```
[<date>] MISTAKE: <what happened (1 line)> → RULE: <how to avoid it (1 line)>
```

Example:

```
[2026-04-16] MISTAKE: used `npm install` despite project using Bun lockfile → RULE: check for bun.lockb before picking package manager
```

### 4. Classify scope

For each pair, classify as:

- **local** — one-off, project-agnostic learning (goes to `.claude/learnings.md`)
- **project** — tied to this specific project's stack or conventions (goes to `ciel-overlay.md` under `## Leçons projet`)

Heuristics for project-scope:
- Mentions specific tool versions, framework names, or internal paths
- Refers to overlay rules
- Contradicts or extends an existing overlay rule

Else → local.

### 5. Deduplicate

Before appending:

- Read existing file
- For each new pair, check if the RULE portion (normalized: lowercase, stemmed) already exists
- Skip if duplicate (log: "skipped duplicate: <rule>")

### 6. Append

Append new pairs at the bottom of the target file under `## Leçons projet` (for overlay) or `## Learnings` (for `.claude/learnings.md`). Create the section if missing.

---

## Output format

```
# Session learnings captured

Turns analyzed: <N>
Signals detected: <M>
New pairs: <P>
Duplicates skipped: <D>

## Appended to .claude/learnings.md
- [2026-04-16] MISTAKE: ... → RULE: ...

## Appended to ciel-overlay.md
- [2026-04-16] MISTAKE: ... → RULE: ...

## Skipped (duplicates)
- <rule text>
```

If nothing to append, output: `No new learnings in this session.`

---

## Guardrails

- **Never overwrite**: always append. Existing content stays as-is.
- **Never delete**: even "wrong" learnings stay. User cleans up manually.
- **Dedup threshold**: 80% lexical similarity on RULE text → treat as duplicate
- **Max pairs per session**: 10 (if more, pick top 10 by frequency/clarity and skip the rest — avoids flooding)
- **Timestamp format**: `[YYYY-MM-DD]` ISO 8601 date (no time, keeps entries readable)
- **No PII**: never capture passwords, tokens, API keys, email addresses, or usernames — filter before writing

---

## When triggered

- `Stop` hook fires at session end
- `PreCompact` hook fires before context compaction
- User says "capture what we just learned" or "add this to learnings"
- `meta-critiquer` skill invokes this at step 3 (user correction detected)
