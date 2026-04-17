---
name: issue-closer
description: Closes GitHub issues with a structured evidence comment — what was fixed, concrete observed staging evidence (logs/curl/DOM — NOT code diffs), and PR/SHA reference. Enforces closure gate from prouver-verifier. Never closes an issue without an evidence comment present.
allowed-tools: Bash
---

# issue-closer — Structured issue closure

Small utility that implements the PROUVER closure gate: before any issue is marked closed, an evidence comment must be posted.

---

## Inputs

- Issue number(s)
- Fix description (1 line)
- Concrete evidence: staging log excerpt, curl output, DOM snapshot, or screenshot — NOT code diff
- PR number or commit SHA that contains the fix

---

## Process

### 1. Check current state

```bash
gh issue view <N> --json state,comments
```

If already closed AND evidence comment exists → no action needed.
If already closed AND no evidence comment → post evidence comment (still, closure without evidence = not closed).
If open → post evidence comment + close.

### 2. Post evidence comment

Template:

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

---

## Output format

```
## Issue closure — #<N>

- Previous state: <open | closed>
- Evidence comment: <posted | already present>
- Final state: <closed>
- Evidence excerpt: <first 3 lines>
```

---

## Guardrails

- **Evidence is mandatory**: refuse to close without evidence (not code diff, not "it should work now", not "fixed in PR")
- **Evidence must be from STAGING** (post-deploy), not local
- **Batch PRs**: if one PR closes 3 issues, invoke this skill 3 times — each issue gets its own specific evidence comment, not a copy-paste
- **Don't auto-close via merge commit**: the auto-close doesn't add evidence comment. Close explicitly via this skill.
- **Reason: completed** (not "not planned") for fix-closures

---

## When triggered

- After `prouver-verifier` PROUVER step completes
- After PR merge when auto-close didn't add evidence
- User request: "close issue #N"
