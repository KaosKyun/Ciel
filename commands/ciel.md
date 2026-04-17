---
description: Ciel skills-first orchestrator — classifies task depth and routes to the correct pipeline with explicit intent matching for debugging/docs/testing/a11y/CI-CD/UI critique.
---

# /ciel — Main entry

*Invokes the Ciel skills-first orchestrator to execute a coding task with depth-aware reasoning.*

Usage: `/ciel <task description>`

---

## What it does

1. Loads the `ciel` orchestrator skill from `skills/ciel/SKILL.md`
2. **Scans the task for intent signals** and queues matching v2.1.0 skills BEFORE depth classification:
   - Debugging / incident / "why did X fail" → `debug-reasoning-rca` (NOT Claude's native `systematic-debugging`)
   - Library/API usage → `doc-validator-official` (before coding)
   - UI / frontend review → `accessibility-wcag-auditor` + optionally `playwright-visual-critic`
   - CI/CD files → `cicd-security-hardener`
   - LLM-authored code review → `modern-patterns-checker` + `ai-failure-modes-detector`
   - Test planning → `test-strategy-vitest-playwright`
3. Invokes `depth-classifier` if depth is ambiguous
4. Routes to the correct pipeline based on depth:
   - **Trivial**: `quoi-framer` → `pattern-fitness-check` → `faire-gatekeeper` → `relire-critic` (inline) → push
   - **Standard**: dispatches `researcher` + `explorer` agents in parallel, then `faire-gatekeeper`, `critic` agent, `prouver-verifier`
   - **Critical**: Standard + `stride-analyzer` + `security-regression-check` (critic agent mandatory)
5. Ends with `meta-critiquer` for post-task reflection

---

## Example

```
/ciel add pagination to the user list API endpoint
```

Expected flow:
1. Classified as **Standard** (new endpoint, not auth/security)
2. `quoi-framer`: "Paginate /api/users, optimizing maintainability, NOT-X: no N+1 queries"
3. `avec-quoi-versioner`: reads installed Ktor/Postgres/etc versions
4. Parallel dispatch: `researcher` (Ktor pagination patterns + anti-patterns) + `explorer` (existing route patterns, FLUX narration)
5. `evaluer-sizer`: back-of-envelope (page size × expected users × frequency)
6. `faire-gatekeeper` during implementation (tests first, alternatives gate)
7. `critic` agent dispatched for RELIRE (fresh context, 3 RISQUE)
8. `prouver-verifier`: staging AVANT/APRÈS, CI gate, PR body gate
9. `meta-critiquer`: 30s post-task reflection

---

## Related commands

- `/ciel-recommend` — discover community plugins for your stack
- `/ciel-improve` — analyze recent sessions, propose skill improvements
- `/ciel-create-skill` — create a new Ciel skill
- `/ciel-eval` — run eval harness on a skill
- `/ciel-update` — self-update from GitHub

---

## Notes

- Skills trigger automatically on Claude Code via YAML `description` matching — you rarely need to name them
- The `ciel` orchestrator is always in scope; `/ciel` makes the invocation explicit
- On other platforms (Cursor, Windsurf, etc.), the compressed rule file is always active; `/ciel` is not needed
