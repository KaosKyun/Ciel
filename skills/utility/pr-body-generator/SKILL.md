---
name: pr-body-generator
description: Generates pull request bodies with Summary + Test plan + Closes #XXX sections. Enforces PR body gate — no WIP marker in title, Closes reference required for linked issues, test plan as bulleted checklist. Invoked before gh pr create.
allowed-tools: Bash, Read
---

# pr-body-generator — Structured PR bodies

## What this covers
The PR body is the reviewer's entry point. A good body answers: what changed, how to test it, and what issue it fixes. All in 30 seconds of reading.

## Core principle
**PR body is for the reviewer, not the author.** The author knows the context. The reviewer needs: what, why, how to verify, and what to watch for.

## Inputs

- Branch name
- Commit list (`git log base..HEAD --oneline`)
- Diff summary (`git diff base..HEAD --stat`)
- Linked issue numbers (from branch name, or explicit input)

## Process

### 1. Detect base branch

Default: `main` or `master`. Respect project convention.

### 2. Extract linked issues

- Branch pattern: `<type>/<N>-...` → issue #N
- Commit body: any `#<N>` or `closes #<N>`
- Explicit input from user

### 3. Summarize changes

From commits + diff stat:
- Top 3 changes by impact (by lines changed or by commit subject classification)
- Avoid exhaustive file list — summarize

### 4. Generate body

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

## Common patterns

### Good PR body

```markdown
## Summary
- Refactor auth middleware to use dependency injection (was hardcoded)
- Add rate limiting to /login endpoint (10 req/min per IP)
- Update session expiry from 24h to 1h per security audit

## Test plan
- [x] Unit tests for rate limiter (vitest)
- [x] Integration test for session expiry (vitest + msw)
- [ ] Manual: verify login still works on staging
- [ ] Manual: verify rate limit triggers after 10 rapid requests

## Evidence
- AVANT: `curl -s staging/api/login -X POST` → 200 (no rate limit)
- APRÈS: `curl -s staging/api/login -X POST` → 200 first 10, then 429

Closes #342
```

### Bad PR body

```markdown
Updated auth stuff.
```

Problems: no summary, no test plan, no issue reference, no evidence.

## Anti-patterns

- **WIP in title** — if it's not done, don't open the PR. Draft PRs exist for this.
- **No `Closes #N`** — PR without issue reference is untraceable
- **Empty test plan** — at least 1 item, even if "manual verification only"
- **Invented test plan** — if no tests planned, be honest. Don't list tests that don't exist.
- **Missing evidence for bug fixes** — detect `fix` commits → require AVANT/APRÈS
- **Exhaustive file list** — summarize by impact, don't list every file

## How to verify

- [ ] Summary has 1-3 bullet points?
- [ ] Test plan has at least 1 item?
- [ ] `Closes #N` present (if linked issue exists)?
- [ ] Bug fix PRs have AVANT/APRÈS evidence section?
- [ ] No WIP/draft markers in title?
- [ ] Body is readable in 30 seconds?

## When triggered

- Before `gh pr create`
- User says "write a PR body" / "PR description"
- `prouver-verifier` skill step 6 (PR body gate)
