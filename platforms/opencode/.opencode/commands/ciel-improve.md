---
description: ---
agent: ciel-improver
subtask: true
---

> **OpenCode note**: This command requires `claude --print` headless mode for full functionality (binary evals, skill scaffold generation). On OpenCode it runs in degraded mode — the improver agent returns proposals only. For the full harness, use Claude Code.

---
description: Runs the Ciel improver agent on recent session transcripts to detect failure modes and produce a patch-set of skill rewrites for user approval.
---

# /ciel-improve — Self-improvement pass

*Analyzes recent session transcripts, detects repeated failure modes and user corrections, and proposes concrete skill improvements as a patch-set for user approval.*

Usage: `/ciel-improve [scope]`

- `scope` defaults to `last-10-sessions`
- Other scopes: `last-N-sessions`, `since-date=YYYY-MM-DD`, `skill=<name>`, `project-only`

---

## What it does

1. Dispatches the `improver` agent in MODE=IMPROVE
2. The agent invokes `ciel-improve` skill → `skill-variant-evaluator` for each candidate patch
3. Returns a structured patch-set: for each skill to improve, shows BEFORE / AFTER blocks with eval scores
4. Waits for user approval on each patch (y/n/edit)
5. Applies approved patches + auto-generates commit messages

---

## Example output

```
# Ciel improvement proposals — 2026-04-17T14:23

Sessions analyzed: 10
Issues detected: 4
Patches proposed: 3

## Patch 1 — skills/workflow/flux-narrator/SKILL.md
Issue: REPEATED — user corrected "missing test-specific items" 3 times across sessions
Sessions affected: 3
Baseline score: 0.71 | Candidate B score: 0.88 (winner)

--- BEFORE (lines 34-38)
- Test level: unit / integration / E2E
--- AFTER
- Test level: unit (isolated logic) / integration (layer boundary) / E2E (user flow)
- Mandatory when writing tests: URL routing, mock lifecycle, timing — see reference.md

Approve? [y/n/edit]
```

---

## Guardrails

- **Max 5 patches per run** — prevents noise
- **Always patch-set, never autonomous rewrite** — you approve each change
- **Preserves YAML validity** — every proposed patch validates against the skill schema
- **Logs rejected patches** — `evals/results/rejected-patches.jsonl` for future proposal improvements

---

## When to run

- Monthly routine — catch process drift early
- After a significant failure — post-incident analysis
- Before a major version bump — ensure baseline quality
- When you've corrected Claude on the same thing 3+ times — time to make it a rule

---

## Cost

Typical run consumes 1-2M tokens across sub-skill evaluations. Projected cost is displayed before the run — you can abort.
