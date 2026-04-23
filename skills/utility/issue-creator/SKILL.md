---
name: issue-creator
description: Creates a GitHub issue from an RCA verdict, bug report, or feature request. Fills structured body (Problem / Root cause / Proposed fix / Acceptance criteria / Linked evidence). Uses `gh issue create`. Returns the issue number so downstream skills (branch-setup, commit-writer, pr-opener) can link to it. Mandatory on Critical tasks for audit trail, default-on for Standard tasks fixing a bug, skippable on Trivial. Inline — deterministic `gh` command.
allowed-tools: Bash, Read
context: inline
---

# issue-creator — Every fix starts with an issue

"Audit trail first" is a 2026 compliance baseline (SOC 2, ISO 27001). Every production-affecting change needs a traceable reason. Ciel enforces this by creating the issue BEFORE opening a branch.

---

## Inputs

```
TITLE: [1-line summary — imperative verb, ≤ 70 chars]
BODY_SOURCE: [rca-verdict | bug-report | feature-request]
RCA_VERDICT: [output from debug-reasoning-rca, if BODY_SOURCE=rca-verdict]
LABELS: [comma-separated, e.g., "bug,production,critical"]
ASSIGNEES: [optional, e.g., "@me"]
```

### Auto-inference sources

- **TITLE** → from RCA VERDICT symptom (1 sentence) or user prompt's core ask
- **LABELS** → infer from Ciel depth: Critical → `bug,critical`, Standard + bug intent → `bug`, feature intent → `enhancement`
- **ASSIGNEES** → `@me` by default (the user running Ciel)

---

## Preflight

```bash
# Verify gh CLI installed + authenticated
command -v gh || { echo "gh CLI not installed — abort"; exit 1; }
gh auth status 2>&1 | grep -q "Logged in" || { echo "gh not authenticated — run: gh auth login"; exit 1; }
```

If preflight fails, BLOCK the skill, instruct the user to install/authenticate.

---

## Process

### 1. Check for duplicates

```bash
# Search open issues with similar title
gh issue list --state=open --search "<title keywords>" --limit 5
```

If a matching open issue exists (≥70% keyword overlap), RETURN that issue number instead of creating a duplicate. Report: `[DUPE] Reusing existing issue #<N>`.

### 2. Build the body

Use this template (adapt per BODY_SOURCE):

**For rca-verdict (bug):**
```markdown
## Problem

<Symptom in 1 sentence>

## Repro

```
<exact command or "flaky — ~1/N runs">
```

## Root cause

<From RCA Phase 4 Semantic diff>

EXPECTED: <...>
ACTUAL:   <...>
GAP:      <...>
ROOT:     <...>

Supported hypothesis: H<n> [FAULT-TYPE]: <cause>

## Proposed fix

- Direct: <from RCA Phase 5 Direct fix>
- Systemic (Critical only): <test/alert/process gap to close>

## Acceptance criteria

- [ ] <testable condition 1>
- [ ] <testable condition 2>
- [ ] Existing tests still pass
- [ ] New regression test added (if systemic fix applies)

## Evidence

- Production logs: <log snippet or path>
- Git blame: <commit that introduced the issue, if identified>
- RCA full output: <paste or link>

🤖 Filed by Ciel (debug-reasoning-rca + issue-creator)
```

**For feature-request:**
```markdown
## Goal

<1-sentence goal>

## Motivation

<Why this is needed now — user story, metric, constraint>

## Proposed approach

<High-level approach from evaluer-sizer if available>

## Acceptance criteria

- [ ] <testable>
- [ ] <testable>
- [ ] Documentation updated
- [ ] Relevant tests added

## Out of scope

- <NOT-X from quoi-framer>

🤖 Filed by Ciel
```

### 3. Create the issue

```bash
gh issue create \
  --title "<title>" \
  --body-file /tmp/ciel-issue-body-$$ \
  --label "<labels>" \
  --assignee "<assignees>"
```

Capture the returned URL, extract the issue number.

### 4. Emit output for downstream skills

```
[ISSUE CREATED]
Number: #<N>
URL: https://github.com/<org>/<repo>/issues/<N>
Title: <title>
Labels: <labels>
```

Pass `#<N>` to `branch-setup` and future `commit-writer` / `pr-opener` calls.

---

## Guardrails

- **Never create without gh auth** — preflight must pass.
- **Respect existing issues** — dupe check is mandatory; don't pollute the tracker.
- **Don't create on forks** — check `gh repo view --json nameWithOwner` matches upstream. Otherwise ask user to confirm.
- **Critical label enforcement** — if Ciel depth is Critical, the issue MUST have the `critical` label (compliance audit).
- **Body under 65 KB** — GitHub's hard limit; truncate + link to gist if RCA evidence exceeds.
- **One issue per root cause** — don't bundle unrelated symptoms. If RCA found 2 distinct root causes, create 2 issues.

---

## When triggered

- After `debug-reasoning-rca` returns a verdict with `confidence: HIGH` or `MEDIUM`
- Start of a FEATURE intent task (non-trivial)
- Explicit user ask: "file an issue for this"
- Before `branch-setup` (issue number is an input)

---

## How to verify

- [ ] `gh auth status` passes?
- [ ] Duplicate check performed? (`gh issue list --search` ran)
- [ ] Issue created on GitHub? (`gh issue view <N>` succeeds)
- [ ] Body has Problem/Root cause/Acceptance criteria sections?
- [ ] Labels applied (type + severity for bugs)?
- [ ] Issue number returned for downstream skills?
- [ ] Critical tasks have `critical` label?

## Anti-pattern

```
❌ RCA completes → jump straight to writing code → commit → PR → no paper trail
✅ RCA completes → issue-creator → branch-setup → work → pr-opener → issue-closer
```

---

## References

- GitHub CLI — cli.github.com/manual/gh_issue_create
- Ciel pipeline: issue-creator → branch-setup → (FAIRE work) → pr-opener → issue-closer
- SOC 2 audit trail requirement for production changes
