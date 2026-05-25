---
description: ---
agent: ciel-improver
subtask: true
---

> **OpenCode note**: This command requires `claude --print` headless mode for full functionality (binary evals, skill scaffold generation). On OpenCode it runs in degraded mode — the improver agent returns proposals only. For the full harness, use Claude Code.

---
description: Runs the binary eval dataset for a Ciel skill via headless Claude Code, comparing baseline scores and persisting results.
---

# /ciel-eval — Run skill eval harness

Runs the binary eval dataset for a skill via headless Claude Code, persisting scoreboards to `~/.ciel/evals/results/`.

Usage: `/ciel-eval [skill-name]`

- No arg — runs baseline eval for ALL skills that have a dataset
- `skill-name` — runs eval for that skill only

---

## What it does

1. Dispatches `ciel-improver` agent in MODE=EVAL
2. For each target skill:
   - Loads dataset from `evals/datasets/<skill-name>.jsonl`
   - Runs each entry via `claude --print` headless
   - Scores against expected behaviors
3. Persists results to `~/.ciel/evals/results/<skill-name>-<timestamp>.json`
4. Returns a scoreboard

---

## Example output

```
# Eval results — api-design

Dataset: evals/datasets/api-design.jsonl (12 entries)

Score: 0.85 (25/28 criteria passed)
Tokens used: 18.2k
Duration: 15.3s

Result persisted: ~/.ciel/evals/results/api-design-2026-05-23-142345.json
```

---

## Guardrails

- **Max 20 eval entries per dataset** — prevents runaway costs
- **Cost estimation** — displayed before starting; abort if > 500k tokens projected
- **Read-only**: `--disallowed-tools "Write Edit NotebookEdit"` to prevent side effects
- **Graceful fallback**: if `claude --print` unavailable, outputs manual eval prompts

---

## When to run

- Before and after `/ciel-improve` — baseline vs improved
- On VERSION bump — regression sanity check
- When creating a new skill — establish baseline

---

## Eval dataset format

One JSON object per line (JSONL). Required fields:

- `id` — unique in dataset
- `input` — prompt / context passed to skill
- `expected_behavior` — object mapping criterion name to boolean
- `skill` — which skill this tests
