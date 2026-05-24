---
name: branch-setup
description: Creates a git branch named with Ciel's convention — `fix/<issue-number>-<slug>` for bug fixes, `feat/<issue-number>-<slug>` for features. Verifies clean working tree first. Records branch as work context so commit-writer adds `Refs #<issue>` footers. Inline — fast git commands, no fork needed.
allowed-tools: Bash
context: inline
---

# branch-setup — Branch name as audit trail

## What this covers
Naming the branch after the issue makes traceability automatic — GitHub auto-links, reviewers see the reason, the history tells the story.

## Core principle
**Every branch traces to an issue. No orphan branches.** The branch name IS the audit trail.

## Inputs

```
ISSUE_NUMBER: [e.g., "123" — from issue-creator OR explicit user reference]
TITLE_SLUG: [kebab-case short description, ≤ 40 chars]
TYPE: [fix | feat | chore | docs | refactor | test | perf]
BASE_BRANCH: [usually "main" — override if working off release/*]
```

### Auto-inference sources

- **ISSUE_NUMBER** → from `issue-creator` output, or parse `#N` from user prompt, or from `gh issue view`
- **TITLE_SLUG** → from issue title, lowercase, keep first 4-5 meaningful words, kebab-case
- **TYPE** → infer from issue labels: `bug` → `fix`, `enhancement` → `feat`, else `chore`
- **BASE_BRANCH** → `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'`

## Preflight

```bash
# 1. Working tree is clean
git status --porcelain | grep -q . && { echo "Working tree dirty — stash or commit first"; exit 1; }

# 2. We're in a git repo
git rev-parse --git-dir > /dev/null 2>&1 || { echo "Not a git repo"; exit 1; }

# 3. Base branch is reachable
git rev-parse --verify "origin/$BASE_BRANCH" > /dev/null 2>&1 || { echo "Base branch $BASE_BRANCH not found on origin"; exit 1; }
```

If dirty, offer 3 options:
1. Stash (`git stash push -m "ciel pre-branch stash"`)
2. Commit to current branch first (user's call)
3. Abort

## Process

### 1. Compute branch name

```bash
BRANCH_NAME="${TYPE}/${ISSUE_NUMBER}-${TITLE_SLUG}"
# Example: fix/1042-library-update-db-timeout
```

Validate:
- ≤ 80 chars total (many git hosts truncate)
- Only `[a-z0-9/-]` (no uppercase, no underscore, no special)
- Not already exists locally OR remotely

```bash
git rev-parse --verify "$BRANCH_NAME" 2>/dev/null && { echo "Branch exists locally — checkout instead?"; exit 1; }
git ls-remote --exit-code origin "$BRANCH_NAME" && { echo "Branch exists on origin — checkout instead?"; exit 1; }
```

### 2. Create + checkout from fresh base

```bash
git fetch origin "$BASE_BRANCH" --quiet
git checkout -b "$BRANCH_NAME" "origin/$BASE_BRANCH"
```

### 3. Record the work context

Write to `.git/ciel-work-context` (local, not committed):

```
ISSUE: #<N>
BRANCH: <branch>
TYPE: <type>
STARTED: <ISO timestamp>
BASE: <base branch>
```

### 4. Emit output

```
[BRANCH CREATED]
Name: fix/1042-library-update-db-timeout
From: origin/main (SHA <short>)
Issue: #1042
Work context recorded.
```

## Common patterns

### Good branch names

```
fix/342-null-pointer-auth-login
feat/567-user-avatar-upload
chore/890-update-ci-node-version
refactor/123-extract-payment-service
```

### Bad branch names

```
myfix                          # no type, no issue
fix/library-timeout            # no issue number
feature/add-the-thing-with-all-the-details  # way too long
FIX/123-UPPERCASE              # uppercase breaks some tools
```

## Anti-patterns

- `git checkout -b myfix` → no issue link, no type prefix, untraceable
- Working directly on `main` → violates every workflow — Ciel refuses and forces branching
- `git checkout -b fix/library-timeout` without issue number → enforce the `#N` prefix
- Branching from stale local `main` → always fetch + branch from `origin/main`
- Branch names > 80 chars → GitHub truncates, CI tools break

## How to verify

- [ ] Branch name matches `<type>/<N>-<slug>` pattern? (`git branch --show-current | grep -E '^[a-z]+/[0-9]+-'`)
- [ ] ≤ 80 chars total? (`git branch --show-current | wc -c` ≤ 81)
- [ ] Working tree clean before branch? (preflight passed)
- [ ] Branched from `origin/<base>`, not stale local? (`git log --oneline -1 origin/main` matches recent)
- [ ] `.git/ciel-work-context` written with ISSUE + BRANCH + TYPE?

## When triggered

- Right after `issue-creator` returns a number
- User says "start working on issue #N"
- Beginning of FAIRE step when depth is Standard/Critical AND an issue exists

## References

- Conventional branches — conventional-branch.org
- Conventional commits — conventionalcommits.org
- Ciel pipeline: issue-creator → branch-setup → FAIRE → commit-writer → pr-opener → issue-closer
