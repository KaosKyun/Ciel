---
description: Runs the binary eval dataset for one or all Ciel skills via claude --print headless, comparing variants.
---

# /ciel-eval — Run eval harness

*Runs the binary eval dataset for one skill (or all skills) via `claude --print` headless mode, comparing variants and persisting scoreboards.*

Usage: `/ciel-eval [skill-name]`

- No arg → runs baseline eval for ALL skills that have a dataset
- `skill-name` → runs eval for that skill only (baseline + any variants in `variants/`)

---

## What it does

1. Dispatches the `improver` agent in MODE=EVAL
2. The agent invokes `skill-variant-evaluator` skill
3. For each target skill:
   - Loads dataset from `evals/datasets/<skill-name>.jsonl`
   - If variants exist (`skills/<category>/<name>/variants/*.md`), evaluates each
   - Otherwise, baseline-only scoring
4. Persists results to `evals/results/<skill-name>-<timestamp>.json`
5. Returns a scoreboard

---

## Example output

```
# Eval results — flux-narrator

Dataset: evals/datasets/flux-narration.jsonl (8 entries)
Variants evaluated: 3

| Variant | Score | Tokens | Duration |
|---------|-------|--------|----------|
| A (baseline) | 0.72 | 14.5k | 12.5s |
| B (tightened) | 0.89 | 15.1k | 13.2s ← WINNER |
| C (reduced) | 0.81 | 12.8k | 11.7s |

Winner: **Variant B** (+0.17 over baseline)

Recommendation: adopt Variant B via `/ciel-improve`

Result persisted: evals/results/flux-narrator-2026-04-17-142345.json
```

---

## Guardrails

- **Max 20 eval entries per dataset** — prevents runaway costs
- **Max 3 variants per skill** — A/B/C, more is noise
- **Cost estimation** — displayed before starting; user can abort if > 500k tokens projected
- **Read-only evals** — `--disallowed-tools "Write Edit NotebookEdit"` to prevent side effects
- **Graceful fallback** — if `claude --print` is unavailable, outputs manual eval prompts and waits for user input

---

## When to run

- Before and after every `/ciel-improve` pass (baseline vs improved)
- On every CHANGELOG version bump — regression sanity check
- When creating a new skill — establish baseline score
- When adding new eval criteria — re-score existing skills

---

## Eval dataset format

One JSON object per line (JSONL). See `evals/datasets/depth-classification.jsonl` for examples. Required fields:

- `id` — unique in dataset
- `input` — prompt / context passed to skill
- `expected_behavior` — object mapping criterion name → boolean
- `skill` — which skill this tests

See `skills/meta/skill-variant-evaluator/reference.md` for the full schema and supported criterion evaluators.
