---
description: "Run binary evals for Ciel skills (degraded on OpenCode — uses improver agent proposals only)"
agent: ciel-improver
subtask: true
---

> **OpenCode note**: This command uses the improver agent. For full `claude --print` headless evals, use Claude Code.

# /ciel-eval — Run eval harness

Usage: `/ciel-eval [skill-name]`

## What it does

1. Dispatches the `ciel-improver` agent in MODE=EVAL
2. For each target skill, loads dataset from `evals/datasets/<skill-name>.jsonl`
3. If variants exist, evaluates each
4. Returns a scoreboard

## Example output

```
# Eval results — flux-narrator

Dataset: evals/datasets/flux-narration.jsonl (8 entries)
Variants evaluated: 3

| Variant | Score | Tokens | Duration |
|---------|-------|--------|----------|
| A (baseline) | 0.72 | 14.5k | 12.5s |
| B (tightened) | 0.89 | 15.1k | 13.2s ← WINNER |

Winner: **Variant B** (+0.17 over baseline)
```

## Guardrails

- Max 20 eval entries per dataset
- Max 3 variants per skill
- Cost estimation displayed before starting
- Graceful fallback if headless mode unavailable
