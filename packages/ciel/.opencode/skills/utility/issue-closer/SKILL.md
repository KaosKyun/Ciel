---
name: issue-closer
description: Closes GitHub issues with a structured evidence comment — what was fixed, concrete observed staging evidence (logs/curl/DOM — NOT code diffs), and PR/SHA reference. Enforces closure gate from prouver-verifier. Never closes without evidence.
allowed-tools: Bash
---

# issue-closer — Structured issue closure

## What this covers
Implements the PROUVER closure gate: before any issue is marked closed, an evidence comment must be posted. Closing without evidence is lying to future-you.

## Core principle
**No evidence, no closure.** A code diff proves you wrote code. Staging evidence proves it works. Only the latter closes an issue.

## Inputs

- Issue number(s)
- Fix description (1 line)
- Concrete evidence: staging log excerpt, curl output, DOM snapshot, or screenshot — NOT code diff
- PR number or commit SHA that contains the fix

## Process

### 1. Check current state

```bash
gh issue view <N> --json state,comments
```

If already closed AND evidence comment exists → no action needed.
If already closed AND no evidence comment → post evidence comment (closure without evidence = not closed).
If open → post evidence comment + close.

### 2. Post evidence comment

```markdown
Fixed: <1-line description>

**Evidence** (from staging):
<concrete log excerpt / curl output / DOM snapshot / screenshot>

PR: #<N>
Commit: <SHA>
```

Use `gh issue comment <N> --body "$(cat <<'EOF' ... EOF)"` for formatting.

### 3. Close if still open

```bash
gh issue close <N> --reason completed
```

### 4. Confirm

```bash
gh issue view <N> --json state,comments
```

State: `closed`. Last comment: evidence format. → DONE.

## Common patterns

### Good closure comment

```markdown
Fixed: prevent N+1 query in user dashboard endpoint

**Evidence** (from staging):
$ curl -s https://staging.example.com/api/dashboard | jq '.query_count'
12
(was 103 before fix — confirmed via pg_stat_statements)

PR: #568
Commit: a1b2c3d
```

### Bad closure comment

```markdown
Fixed in PR #568.
```

Problems: no evidence, no staging verification, just a code reference.

## Anti-patterns

- **Closing with code diff as evidence** — code diff proves you wrote code, not that it works
- **Closing without staging evidence** — always verify on staging first
- **Copy-paste evidence across issues** — if one PR closes 3 issues, each gets specific evidence
- **Auto-close via merge commit** — the auto-close doesn't add evidence. Close explicitly via this skill.
- **"It should work now"** — this is hope, not evidence

## How to verify

- [ ] Evidence comment posted before closure?
- [ ] Evidence is from staging (not local)?
- [ ] Evidence is concrete (log/curl/DOM, not "fixed in PR")?
- [ ] Issue state is `closed` with reason `completed`?
- [ ] Last comment matches evidence format (Fixed + Evidence + PR + Commit)?

## When triggered

- After `prouver-verifier` PROUVER step completes
- After PR merge when auto-close didn't add evidence
- User request: "close issue #N"
