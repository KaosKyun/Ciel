---
name: pr-body-generator
description: Generates pull request bodies with Summary + Test plan + Closes #XXX sections. Enforces PR body gate — no WIP marker in title, Closes reference required for linked issues, test plan as bulleted checklist. Invoked before gh pr create.
allowed-tools: Bash, Read
---

# pr-body-generator — Structured PR bodies

Small utility to ensure PR bodies follow a consistent, review-friendly format.

---

## Inputs

- Branch name
- Commit list (`git log base..HEAD --oneline`)
- Diff summary (`git diff base..HEAD --stat`)
- Linked issue numbers (from branch name, or explicit input)

---

## Process

### 1. Detect base branch

Default: `main` or `master`. Respect project convention.

### 2. Extract linked issues

- Branch pattern: `<user>/issue-<N>-...` → issue #N
- Commit body: any `#<N>` or `closes #<N>`
- Explicit input from user

### 3. Summarize changes

From commits + diff stat:
- Top 3 changes by impact (by lines changed or by commit subject classification)
- Avoid exhaustive file list — summarize

### 4. Generate body

Template:
```markdown
## Summary
- <bullet: what changed>
- <bullet: what changed>
- <bullet: what changed>

## Test plan
- [ ] Unit tests for <component>
- [ ] Integration test for <boundary>
- [ ] Manual verification on staging: <URL>

## Evidence (if bug fix)
- AVANT: <log excerpt or URL>
- APRÈS: <log excerpt or URL>

Closes #<N>
```

---

## Output format

The full PR body text, ready for `gh pr create --body "..."` or heredoc.

---

## Guardrails

- **PR title check**: if title contains `WIP`, `[WIP]`, `wip`, `draft` → warn (don't open draft PRs named WIP; either not done = don't open, or done = remove marker)
- **Closes #XXX required**: if no linked issue detected, prompt user to add one or confirm no issue exists
- **Test plan non-empty**: at least 1 test plan item, even if "manual verification only"
- **Evidence section for bug fixes**: detect fix-like commits → require AVANT/APRÈS
- **Don't invent test plan**: if tests exist, reference them; if no tests planned, be honest

---

## When triggered

- Before `gh pr create`
- User says "write a PR body" / "PR description"
- `prouver-verifier` skill step 6 (PR body gate)
