---
name: pr-merger
description: Merges a GitHub PR safely — reads branch protection (reviews, checks, CODEOWNERS), flips draft→ready on green CI, picks squash/rebase/merge from repo config, uses `--auto`. Gated by prouver-verifier VERDICT=DONE. Hands off to issue-closer + branch-cleaner. Invoke on "merge PR" / "auto-merge" / "land this PR". Inline.
allowed-tools: Bash, Read
context: inline
---

# pr-merger — Close the loop with branch-protection awareness

Opening a PR is only half the workflow. `pr-merger` owns the other half: flip draft → ready, wait for green CI + approvals, respect branch protection, pick the right merge strategy, then hand off to post-merge cleanup.

---

## Inputs

```
PR_NUMBER: [from current branch via `gh pr view --json number` or explicit]
MERGE_STRATEGY: [squash | rebase | merge — default: read from repo settings]
AUTO: [true | false — default true; uses --auto to queue behind protection gates]
DELETE_BRANCH: [true | false — default true; deletes source branch after merge]
PROUVER_VERDICT: [DONE | PENDING — must be DONE to proceed]
```

### Auto-inference sources

- **PR_NUMBER** → `gh pr view --json number --jq .number` from current branch
- **MERGE_STRATEGY** → `gh api repos/{owner}/{repo} --jq '.allow_squash_merge, .allow_rebase_merge, .allow_merge_commit'` — prefer squash > rebase > merge if multiple allowed. Match repo convention from last 10 merged PRs.
- **PROUVER_VERDICT** → output of `prouver-verifier` in same session

---

## Preflight

```bash
gh auth status 2>&1 | grep -q "Logged in" || { echo "gh not authenticated"; exit 1; }

# PR must exist and be open
PR_NUMBER=${PR_NUMBER:-$(gh pr view --json number --jq .number 2>/dev/null)}
[ -z "$PR_NUMBER" ] && { echo "No PR found for current branch"; exit 1; }

STATE=$(gh pr view "$PR_NUMBER" --json state --jq .state)
[ "$STATE" = "OPEN" ] || { echo "PR #$PR_NUMBER is $STATE — cannot merge"; exit 1; }

# prouver-verifier gate
[ "$PROUVER_VERDICT" = "DONE" ] || { echo "prouver-verifier verdict is $PROUVER_VERDICT — run it first"; exit 1; }
```

---

## Process

### 1. Read branch protection rules

```bash
OWNER_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
BASE=$(gh pr view "$PR_NUMBER" --json baseRefName --jq .baseRefName)

# Protection settings (may return 404 if unprotected — treat as unprotected)
PROTECTION=$(gh api "repos/$OWNER_REPO/branches/$BASE/protection" 2>/dev/null || echo "{}")

REQUIRED_REVIEWS=$(echo "$PROTECTION" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')
REQUIRED_CHECKS=$(echo "$PROTECTION" | jq -r '.required_status_checks.contexts // [] | join(",")')
REQUIRES_CODEOWNERS=$(echo "$PROTECTION" | jq -r '.required_pull_request_reviews.require_code_owner_reviews // false')
```

### 2. Verify approvals + checks

```bash
# Approvals
APPROVED=$(gh pr view "$PR_NUMBER" --json reviewDecision --jq .reviewDecision)
if [ "$REQUIRED_REVIEWS" -gt 0 ] && [ "$APPROVED" != "APPROVED" ]; then
  echo "PR needs approval (reviewDecision=$APPROVED, required=$REQUIRED_REVIEWS)"
  echo "Action: request review via gh pr edit --add-reviewer @user OR wait"
  exit 1
fi

# Required status checks
CHECKS=$(gh pr view "$PR_NUMBER" --json statusCheckRollup --jq '.statusCheckRollup[] | select(.conclusion != "SUCCESS" and .conclusion != "NEUTRAL" and .conclusion != "SKIPPED") | .name')
if [ -n "$CHECKS" ]; then
  echo "Failing/pending checks:"
  echo "$CHECKS"
  echo "Hand off to ci-watcher for retry/flaky detection"
  exit 1
fi
```

### 3. Flip draft → ready (if still draft + CI green)

```bash
IS_DRAFT=$(gh pr view "$PR_NUMBER" --json isDraft --jq .isDraft)
if [ "$IS_DRAFT" = "true" ]; then
  echo "Flipping draft → ready (CI is green)"
  gh pr ready "$PR_NUMBER"
fi
```

### 4. Pick merge strategy

```bash
case "$MERGE_STRATEGY" in
  squash)  FLAG="--squash" ;;
  rebase)  FLAG="--rebase" ;;
  merge)   FLAG="--merge" ;;
  *)       echo "Unknown strategy: $MERGE_STRATEGY"; exit 1 ;;
esac

# delete-branch flag
DELETE_FLAG=""
[ "$DELETE_BRANCH" = "true" ] && DELETE_FLAG="--delete-branch"

# auto flag
AUTO_FLAG=""
[ "$AUTO" = "true" ] && AUTO_FLAG="--auto"
```

### 5. Merge

```bash
gh pr merge "$PR_NUMBER" $FLAG $AUTO_FLAG $DELETE_FLAG
MERGE_STATUS=$?
```

If `--auto` is set, GitHub queues the merge. If not, the merge completes synchronously.

### 6. Emit output + hand off

```
[PR MERGED] (or [PR QUEUED] if --auto pending on checks)
Number: #<P>
Strategy: <squash|rebase|merge>
Branch deleted: <yes|no>

Handoff:
- issue-closer (if PR closes an issue — from `Closes #N` in body)
- branch-cleaner (local cleanup of merged branch)
```

Post-merge, the caller should invoke `issue-closer` and `branch-cleaner` in sequence.

---

## Guardrails

- **prouver-verifier gate is non-negotiable** — never merge without DONE verdict. Skipping skips evidence capture.
- **Never merge a draft** — flip to ready first, explicitly.
- **Never bypass branch protection** — if protection fails, surface the reason and stop. Don't suggest disabling protection.
- **Match repo strategy** — a repo that only allows squash should never receive `--merge`. Read settings, don't assume.
- **Never `--admin`** — admin merge bypasses protection. Refuse unless user explicitly requests AND explains why.
- **Auto-merge requires protection** — `--auto` only works if branch protection is configured. Fall back to synchronous merge if not.
- **Respect `[WIP]` / `[DO NOT MERGE]` in title** — block merge, surface the marker.

---

## When triggered

- End of Standard pipeline after `pr-opener` + `prouver-verifier` + `ci-watcher` all return green
- User says: "merge this PR", "enable auto-merge", "land this"
- Skipped on Trivial tasks (direct push to main)

---

## Anti-pattern

```
❌ gh pr merge 42 --admin --merge    # bypasses protection AND wrong strategy
✅ pr-merger reads protection, picks squash (repo convention), --auto queues behind CI
```

```
❌ Merge PR while draft                 # reviewers haven't been asked yet
✅ gh pr ready first, then gh pr merge
```

---

## Handoff to downstream skills

- `issue-closer` — reads `Closes #N` from PR body, posts evidence comment, closes issue
- `branch-cleaner` — deletes merged branch locally + prunes remote refs
- `changelog-updater` — if PR has `release-note` label or is on a version-bump branch

---

## References

- GitHub CLI — cli.github.com/manual/gh_pr_merge
- Branch protection API — docs.github.com/en/rest/branches/branch-protection
- Merge queue — docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue
- Ciel pipeline: pr-opener → ci-watcher → pr-merger → issue-closer → branch-cleaner
