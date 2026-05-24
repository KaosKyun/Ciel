---
name: skill-variant-evaluator
description: AutoResearch eval runner that generates 2-3 variants of a skill, executes them headlessly against binary eval datasets, compares aggregate scores, and proposes the winner with tiebreak on token usage. Use when /ciel-eval is invoked or when ciel-improve needs to pick between candidate rewrites.
allowed-tools: Read, Bash, Glob
---

# skill-variant-evaluator — AutoResearch eval harness

## What this covers
Implements Karpathy-style AutoResearch for Ciel skills: define binary evals, run variants, compare scores, keep the winner.

## Core principle
**Binary evals, not vibes.** Every skill improvement is measured against concrete pass/fail criteria. The variant with the highest score wins.

## Inputs

- **skill-path**: path to `SKILL.md`
- **variants** (optional): 2-3 candidate SKILL.md contents
- **dataset**: eval dataset in `evals/datasets/<name>.jsonl`
- **baseline-only**: boolean — only score current skill, no variants

## Process

### 1. Locate eval dataset

Look for `evals/datasets/<skill-name>.jsonl`. If missing, warn and exit.

### 2. Load variants

- Variant A: current SKILL.md (baseline)
- Variants B, C: alternatives provided or from `variants/`

### 3. Execute each variant headlessly

For each variant:
1. Write to `SKILL.md.eval.<letter>`
2. For each eval entry, run `claude --print` with the eval prompt
3. Capture output + token usage + duration
4. Score against `expected_behavior` criteria (binary per criterion)

### 4. Aggregate scores

`aggregate = sum(criteria_passed) / total_criteria`

Winner = highest aggregate. Tiebreak: lowest total token usage.

### 5. Persist results

Write to `evals/results/<skill-name>-<timestamp>.json`.

## Common patterns

### Good eval result

```
# Skill variant evaluation — flux-narrator

Dataset: evals/datasets/flux-narration.jsonl (8 entries)

| Variant | Score | Tokens | Duration |
|---------|-------|--------|----------|
| A (baseline) | 0.72 | 14.5k | 12.5s |
| B (tightened) | 0.89 | 15.1k | 13.2s ← WINNER |
| C (reduced) | 0.81 | 12.8k | 11.7s |

Winner: **Variant B** (+0.17 over baseline)
Recommendation: adopt Variant B.
```

### Bad eval result

```
Variant B seems better. Use it.
```

Problems: no scores, no comparison table, no dataset reference.

## Anti-patterns

- **Dataset > 20 entries** — cap to prevent runaway costs
- **> 3 variants** — no clear winner possible
- **Token cost > 500k without confirmation** — estimate first
- **Overwriting SKILL.md** — variants go to `.eval.<letter>` files
- **Not cleaning up** — delete `.eval.<letter>` temp files after results persisted

## How to verify

- [ ] Dataset exists and loaded?
- [ ] All variants executed?
- [ ] Scores aggregated correctly?
- [ ] Winner identified with tiebreak if needed?
- [ ] Results persisted to `evals/results/`?
- [ ] Temp files cleaned up?
- [ ] Token cost within budget?

## When triggered

- User runs `/ciel-eval [skill-name]`
- `ciel-improve` calls this for each proposed patch
- `improver` agent invokes this as part of its loop
