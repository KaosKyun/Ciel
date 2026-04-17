---
name: skill-variant-evaluator
description: AutoResearch eval runner that generates 2-3 variants of a skill, executes them headlessly against binary eval datasets, compares aggregate scores, and proposes the winner with tiebreak on token usage. Use when /ciel-eval is invoked, when ciel-improve needs to pick between candidate rewrites, or when a new skill needs baseline benchmarking. Invokes `claude --print` headless mode for each variant.
allowed-tools: Read, Bash, Glob
---

# skill-variant-evaluator — AutoResearch eval harness

Implements Karpathy-style AutoResearch for Ciel skills: define binary evals, run variants, compare scores, keep the winner.

For eval dataset format and runner details, see `reference.md`.

---

## Inputs

- **skill-path**: path to a `SKILL.md` file (e.g. `skills/workflow/flux-narrator/SKILL.md`)
- **variants** (optional): list of 2-3 candidate SKILL.md contents to evaluate. If not provided, reads from `skills/<category>/<name>/variants/*.md`
- **dataset**: path to eval dataset in `evals/datasets/<name>.jsonl` (matched by skill name if omitted)
- **baseline-only**: boolean — if true, only score the current skill, no variants

---

## Process

### 1. Locate eval dataset

If dataset path provided, use it directly. Otherwise look for `evals/datasets/<skill-name>.jsonl`. If no dataset exists, emit a warning and exit: user must first create a dataset via `/ciel-create-eval` or manually.

### 2. Load variants

- Variant A: current SKILL.md (baseline)
- Variants B, C: alternative versions provided as input or found in `skills/<category>/<name>/variants/`

### 3. Execute each variant headlessly

For each variant:

1. Write variant content to `skills/<category>/<name>/SKILL.md.eval.<letter>`
2. For each eval entry in the dataset, run `claude --print` with the eval prompt:

```bash
claude --print \
  --plugin-dir /home/user/Ciel \
  --allowed-tools "Read Grep Glob WebSearch WebFetch Bash" \
  --model claude-opus-4-7 \
  "<eval prompt from dataset>"
```

3. Capture the output + token usage + duration
4. Score against the eval's `expected_behavior` criteria (binary per criterion)

### 4. Aggregate scores

For each variant: `aggregate = sum(criteria_passed) / total_criteria`

Winner = highest aggregate. Tiebreak: lowest total token usage.

### 5. Persist results

Write to `evals/results/<skill-name>-<timestamp>.json`:

```json
{
  "skill": "flux-narrator",
  "timestamp": "2026-04-16T10:23:45Z",
  "ciel_version": "<sha>",
  "dataset": "evals/datasets/flux-narration.jsonl",
  "variants": [
    {"letter": "A", "source": "baseline", "score": 0.72, "tokens": 14500, "duration_ms": 12500},
    {"letter": "B", "source": "candidate-tightened", "score": 0.89, "tokens": 15100, "duration_ms": 13200},
    {"letter": "C", "source": "candidate-reduced", "score": 0.81, "tokens": 12800, "duration_ms": 11700}
  ],
  "winner": "B"
}
```

---

## Output format

```
# Skill variant evaluation — <skill-name>

Dataset: <path> (<N> entries)
Baseline score: <A_score>

| Variant | Score | Tokens | Duration |
|---------|-------|--------|----------|
| A (baseline) | 0.72 | 14.5k | 12.5s |
| B (tightened) | 0.89 | 15.1k | 13.2s ← WINNER |
| C (reduced) | 0.81 | 12.8k | 11.7s |

Winner: **Variant B** (+0.17 over baseline)

Recommendation: adopt Variant B.

Next step: approve via `/ciel-improve` → apply Patch

Result logged: evals/results/<skill-name>-<timestamp>.json
```

---

## Guardrails

- **Dataset size cap**: max 20 eval entries per run (prevents runaway costs). Warn if dataset > 20 entries.
- **Variant count cap**: max 3 variants per run (A + B + C). More variants = no clear winner.
- **Token cost warning**: estimate cost (variants × entries × ~15k tokens) before starting. If > 500k tokens, require user confirmation.
- **Headless mode availability**: if `claude --print` is not available in environment, fall back to user-run manual evals (document the exact prompts and collect scores manually).
- **Never overwrite**: existing SKILL.md files stay untouched. Variants are written to `.eval.<letter>` suffixed files.
- **Cleanup**: delete `.eval.<letter>` temp files after results are persisted.

---

## When triggered

- User runs `/ciel-eval [skill-name]` — evaluates baseline only if no variants provided
- User runs `/ciel-improve` — ciel-improve skill calls this for each proposed patch
- `improver` agent invokes this as part of its loop
