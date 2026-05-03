---
command: ciel-eval
description: Run binary eval harness for Ciel skills
agent: ciel-improver
subtask: true
---

# /ciel-eval — Run eval harness

Runs the binary eval dataset for one skill (or all skills), comparing variants and persisting scoreboards.

Usage: `/ciel-eval [skill-name]`

- No arg → runs baseline eval for ALL skills that have a dataset
- `skill-name` → runs eval for that skill only (baseline + any variants in `variants/`)

## Process

1. Dispatches the `improver` agent in MODE=EVAL
2. The agent invokes `skill-variant-evaluator` skill
3. For each target skill:
   - Loads dataset from `evals/datasets/<skill>.jsonl`
   - Generates 2-3 variants of the skill
   - Executes all variants headlessly against the dataset
   - Compares aggregate scores
   - Proposes winner with tiebreak on token usage
4. Results appended to `evals/results/<skill>-scoreboard.md`
