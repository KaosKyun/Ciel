---
name: ciel-improve
description: Analyzes recent session transcripts to detect repeated failure modes, user corrections, and skill output truncation, then produces a patch-set proposing specific rewrites for Ciel skills. Use when the user invokes /ciel-improve or asks Ciel to self-improve. Never rewrites skills autonomously — always returns a patch-set for user approval.
allowed-tools: Read, Grep, Glob, Bash
---

# ciel-improve — Meta-skill for self-improvement

This is the heart of Ciel's self-modification subsystem. It reads conversation history, identifies where skills failed to trigger or produced weak output, and proposes concrete rewrites.

**Critical rule**: this skill NEVER writes changes to other skills directly. It ALWAYS produces a patch-set (before/after diffs) and lets the user approve each patch individually.

For patch format details and scoring rubric, see `reference.md`.

---

## Inputs

- **Session transcripts**: last N Claude Code session JSONL files from `~/.claude/projects/<project-slug>/*.jsonl` (default N=10)
- **Current Ciel version**: `.version` SHA
- **Project learnings**: `.claude/learnings.md` (if exists)
- **Project overlay**: `ciel-overlay.md` (if exists)
- **Latest eval scores**: `evals/results/*.json` (if exist)

---

## Analysis process

### 1. Parse transcripts

For each session JSONL, extract:
- User messages (what was asked)
- Tool calls (what Claude invoked)
- Tool results (success / failure / truncation)
- User corrections (phrases like "non", "that's wrong", "use X instead of Y", "stop doing Y")
- Skill triggers (log lines `SkillInvoked: <name>`)

### 2. Identify issues

For each turn, classify into one of:

- **UNTRIGGERED**: a skill should have fired based on the prompt but didn't (e.g. user asked about React patterns, `frontend-mastery` didn't trigger)
- **MISTRIGGERED**: a skill fired when it shouldn't have (context waste)
- **TRUNCATED**: skill/agent output < 200 tokens on non-trivial task
- **CORRECTED**: user explicitly corrected Claude's behavior
- **REPEATED**: same failure pattern observed 2+ times across sessions

### 3. Map issues to skills

For each issue, find the responsible skill (if any):
- If `description` didn't match user intent → patch the description
- If output was truncated → patch output constraints (token budget, fallback scope)
- If a correction happened repeatedly → patch the skill to enforce the corrected behavior

### 4. Generate candidate rewrites

For each responsible skill, produce 2-3 candidate rewrites of the relevant block:
- **A**: baseline (current content)
- **B**: tightened gates + more specific description keywords
- **C**: reduced scope + clearer trigger phrasing

### 5. Run `skill-variant-evaluator` on each candidate

Invoke `skill-variant-evaluator` with the skill + the candidates + any matching dataset from `evals/datasets/`. Winner = highest aggregate binary score (tiebreak: lowest token usage).

### 6. Produce patch-set

Output a structured patch-set for user approval:

```
## Patch 1 — skills/<category>/<name>/SKILL.md
Issue: <REPEATED: user corrected "use pip not uv" 3 times across sessions>
Baseline score: 0.62 | Candidate B score: 0.89 (winner)

--- BEFORE (lines 15-20)
<old block>
--- AFTER
<new block>

Approve? [y/n/edit]
```

---

## Output format

```
# Ciel improvement proposals — <timestamp>

Sessions analyzed: N
Issues detected: M
Patches proposed: P

## Patch 1 — <skill-path>
Issue: <type + summary>
Before: <block>
After: <block>
Eval delta: <baseline> → <winner>

## Patch 2 — <skill-path>
...

## New skills proposed (if any)
- <name>: <purpose> — detected pattern: <summary>

## No-fix issues (user must decide)
- <issue that requires human judgment>
```

---

## Guardrails

- **Patch count cap**: max 5 patches per run. More = likely too noisy. Pause and ask user.
- **Description diff size cap**: description field rewrite ≤ 200 chars changed per patch (prevents wholesale rewrites).
- **New skill cap**: max 1 new skill proposed per run (prevents skill explosion).
- **Skill deletion**: NEVER propose deleting a skill in an automated pass. User decides manually.
- **YAML validation**: every proposed patch must preserve valid YAML frontmatter (name ≤ 64 chars kebab-case, description ≤ 1024 chars).

---

## When triggered

- User runs `/ciel-improve`
- User asks "can you improve yourself?" or "analyze my recent sessions"
- `improver` agent invokes this skill

Do NOT trigger on every task — this is an infrequent meta operation.
