---
name: ciel-improve
description: Analyzes recent session transcripts to detect repeated failure modes, user corrections, and skill output truncation, then produces a patch-set proposing specific rewrites for Ciel skills. Never rewrites autonomously — always returns a patch-set for user approval.
allowed-tools: Read, Grep, Glob, Bash
---

# ciel-improve — Meta-skill for self-improvement

## What this covers
This is the heart of Ciel's self-modification subsystem. It reads conversation history, identifies where skills failed to trigger or produced weak output, and proposes concrete rewrites.

## Core principle
**Never rewrite autonomously.** Every change is a proposal. The user approves each patch individually.

## Inputs

- **Session transcripts**: last N session JSONL files (default N=10)
- **Current Ciel version**: `.version` SHA
- **Project learnings**: `.claude/learnings.md` (if exists)
- **Latest eval scores**: `evals/results/*.json` (if exist)

## Process

### 1. Parse transcripts

For each session JSONL, extract:
- User messages (what was asked)
- Tool calls (what was invoked)
- User corrections ("non", "that's wrong", "use X instead")
- Skill triggers (log lines `SkillInvoked: <name>`)

### 2. Identify issues

Classify each turn:
- **UNTRIGGERED**: skill should have fired but didn't
- **MISTRIGGERED**: skill fired when it shouldn't have
- **TRUNCATED**: output < 200 tokens on non-trivial task
- **CORRECTED**: user explicitly corrected behavior
- **REPEATED**: same failure 2+ times across sessions

### 3. Map issues to skills

For each issue, find the responsible skill:
- Description didn't match intent → patch description
- Output truncated → patch output constraints
- Correction repeated → patch to enforce corrected behavior

### 4. Generate candidate rewrites

For each responsible skill, produce 2-3 candidates:
- **A**: baseline (current)
- **B**: tightened gates + more specific description
- **C**: reduced scope + clearer trigger phrasing

### 5. Run `skill-variant-evaluator` on each candidate

Winner = highest aggregate binary score (tiebreak: lowest token usage).

### 6. Produce patch-set

```
## Patch 1 — skills/<category>/<name>/SKILL.md
Issue: <REPEATED: user corrected "use pip not uv" 3 times>
Baseline score: 0.62 | Candidate B score: 0.89 (winner)

--- BEFORE (lines 15-20)
<old block>
--- AFTER
<new block>

Approve? [y/n/edit]
```

## Common patterns

### Good improvement proposal

```
# Ciel improvement proposals — 2026-04-23

Sessions analyzed: 5
Issues detected: 3
Patches proposed: 2

## Patch 1 — skills/utility/commit-writer/SKILL.md
Issue: CORRECTED — user said "add issue reference" 3 times, skill didn't enforce it
Before: "If branch name matches pattern, add Closes #N"
After: "feat/fix commits MUST have Closes #N. If no issue detected, prompt user."

## No-fix issues (user must decide)
- User prefers squash merges but pr-merger defaults to merge commit — preference, not bug
```

### Bad improvement proposal

```
Found some issues. Fixed them.
```

Problems: no patches, no scoring, no user approval, autonomous rewrite.

## Anti-patterns

- **Autonomous rewrite** — NEVER write changes directly. Always propose patches.
- **> 5 patches per run** — too noisy. Pause and ask user.
- **Description rewrite > 200 chars** — prevents wholesale rewrites
- **> 1 new skill per run** — prevents skill explosion
- **Proposing skill deletion** — user decides manually
- **Breaking YAML** — every patch must preserve valid frontmatter

## How to verify

- [ ] Sessions parsed (≥ 1 transcript read)?
- [ ] Issues classified (UNTRIGGERED/MISTRIGGERED/TRUNCATED/CORRECTED/REPEATED)?
- [ ] Each issue mapped to a responsible skill?
- [ ] Candidates generated (2-3 per issue)?
- [ ] Patch-set returned (not applied)?
- [ ] Patch count ≤ 5?
- [ ] YAML frontmatter preserved in all patches?

## When triggered

- User runs `/ciel-improve`
- User asks "can you improve yourself?" or "analyze my recent sessions"
- `improver` agent invokes this skill

Do NOT trigger on every task — this is an infrequent meta operation.
