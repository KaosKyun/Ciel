---
name: branch-setup
description: Creates a git branch named with Ciel's convention — `fix/<issue-number>-<slug>` for bug fixes, `feat/<issue-number>-<slug>` for features, `chore/<issue-number>-<slug>` for maintenance. Verifies clean working tree first. Records the branch as the work context so commit-writer adds `Refs #<issue>` footers. Invoked at the start of FAIRE step when a GitHub issue exists (from issue-creator). Inline — fast git commands, no fork needed.
allowed-tools: Bash
context: inline
---

# branch-setup — Branch name as audit trail

Naming the branch after the issue makes traceability automatic — GitHub auto-links, reviewers see the reason, the history tells the story.

---

## Inputs

```
ISSUE_NUMBER: [e.g., "123" — from issue-creator OR explicit user reference]
TITLE_SLUG: [kebab-case short description, ≤ 40 chars]
TYPE: [fix | feat | chore | docs | refactor | test | perf]  # maps to conventional commits
BASE_BRANCH: [usually "main" — override if working off release/*]
```

### Auto-inference sources

- **ISSUE_NUMBER** → from `issue-creator` output, or parse `#N` from user prompt, or from `gh issue view` if user said "working on issue #N"
- **TITLE_SLUG** → from issue title, lowercase, keep first 4-5 meaningful words, kebab-case (e.g., "Library update fails with DB timeout" → `library-update-db-timeout`)
- **TYPE** → infer from issue labels: `bug` → `fix`, `enhancement` → `feat`, else `chore`
- **BASE_BRANCH** → `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'` gives the default branch (`main` or `master`)

---

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

---

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

This enables `commit-writer` to auto-add `Refs #<N>` footers and `pr-opener` to know the issue to link.

### 4. Emit output

```
[BRANCH CREATED]
Name: fix/1042-library-update-db-timeout
From: origin/main (SHA <short>)
Issue: #1042
Work context recorded.
```

---

## Guardrails

- **Always branch from fresh origin/main** — not from local stale main. Prevents "works on my outdated base" bugs.
- **Never force** — if branch exists, ask. Don't silently overwrite.
- **Respect existing stash/WIP** — dirty tree is a blocker, not a warning.
- **Slug length matters** — long branch names get truncated by tools (GitHub, CI). Cap at 40 chars in the slug portion.
- **No backslashes** — Windows checkouts break. Slashes OK for the type prefix.
- **One branch per issue** — even if the fix spans 5 files, keep it one branch. Split only if scope genuinely diverges.

---

## When triggered

- Right after `issue-creator` returns a number
- User says "start working on issue #N" (look up via `gh issue view N`)
- Beginning of FAIRE step when depth is Standard/Critical AND an issue exists

---

## Anti-patterns

- `git checkout -b myfix` → no issue link, no type prefix, untraceable
- Working directly on `main` → violates every workflow — Ciel refuses and forces branching
- `git checkout -b fix/library-timeout` without issue number → enforce the `#N` prefix

---

## References

- Conventional branches — conventional-branch.org
- Conventional commits — conventionalcommits.org (Ciel's `commit-writer` pairs with these)
- Ciel pipeline: issue-creator → branch-setup → FAIRE → commit-writer (adds Refs #N) → pr-opener → issue-closer
