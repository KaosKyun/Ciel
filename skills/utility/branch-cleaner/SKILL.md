---
name: branch-cleaner
description: Deletes merged branches safely — `git branch --merged` for locals, `git fetch --prune` for stale tracking refs, opt-in `git push origin --delete` per-branch confirm. Excludes main/master/develop + current. Invoke post-merge, on "clean up branches", or when >20 stale branches. Inline.
allowed-tools: Bash
context: inline
---

# branch-cleaner — Delete merged, keep history tidy

Local + remote branches accumulate silently. After 3 months, `git branch` shows 40+ old branches, most of them merged. This skill deletes safely.

---

## Inputs

```
BASE_BRANCH: [default: origin's default branch — main/master]
REMOTE_CLEANUP: [true | false — default false; requires explicit confirmation for remote deletes]
PROTECTED: [comma-separated list — default: main,master,develop,release/*]
DRY_RUN: [true | false — default true on first invocation; shows what would be deleted]
```

### Auto-inference sources

- **BASE_BRANCH** → `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'`
- **Current branch** → always protected (cannot delete the branch you're on)

---

## Preflight

```bash
git rev-parse --git-dir > /dev/null 2>&1 || { echo "Not a git repo"; exit 1; }

# Don't run with dirty tree — in case user is in the middle of something
git status --porcelain | grep -q . && { echo "Working tree dirty — commit or stash first"; exit 1; }

# Fetch to get fresh remote state
git fetch --all --prune --quiet
```

`--prune` already removes stale remote-tracking refs (remotes of branches deleted on origin).

---

## Process

### 1. Identify merged local branches

```bash
BASE=${BASE_BRANCH:-$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')}
CURRENT=$(git rev-parse --abbrev-ref HEAD)

# Branches merged into BASE, excluding protected
MERGED=$(git branch --merged "origin/$BASE" --format='%(refname:short)' \
  | grep -vE "^(main|master|develop|${CURRENT}|release/.*)$" \
  | grep -v "^\*")
```

`git branch --merged` is safer than `--no-merged`: only shows branches whose tip commit is reachable from BASE.

**Caveat**: squash-merged PRs are NOT detected by `--merged` (the commit SHA is different). For these, use the PR-title heuristic:

```bash
# Branches that match a closed-merged PR title
CLOSED_PRS=$(gh pr list --state=closed --search "is:merged" --limit=100 --json headRefName --jq '.[].headRefName')
for BRANCH in $(git branch --format='%(refname:short)' | grep -v "^\*"); do
  echo "$CLOSED_PRS" | grep -qx "$BRANCH" && SQUASH_MERGED+=("$BRANCH")
done
```

### 2. Show what would be deleted (DRY_RUN)

```
[BRANCH CLEANER — DRY RUN]

Local branches merged into origin/$BASE:
  - fix/1042-library-update     (last commit: 2026-03-15, 4 weeks ago)
  - feat/1055-new-endpoint      (last commit: 2026-04-02, 2 weeks ago)

Squash-merged (by PR title match):
  - fix/1048-typo               (PR #1048 closed 2026-04-10)

Protected (not deleted):
  - main, master, develop, release/2026-q2
  - <current: your current branch>

Remote branches fully merged (would delete with REMOTE_CLEANUP=true):
  - origin/fix/1042-library-update
  - origin/fix/1048-typo

To proceed: re-run with DRY_RUN=false
```

### 3. Delete local branches (on user confirmation)

```bash
for B in $MERGED $SQUASH_MERGED; do
  git branch -d "$B" 2>&1 || {
    # -d refuses if upstream diverged; confirm before -D
    if [ -n "$ASSUME_YES" ]; then
      if [ "$ASSUME_YES" = "force" ]; then
        git branch -D "$B"
      else
        echo "Branch '$B' not fully merged; skipping (set ASSUME_YES=force to force-delete)"
      fi
    else
      echo "Branch '$B' not fully merged per -d — use -D? [y/N]"
      read CONFIRM
      [ "$CONFIRM" = "y" ] && git branch -D "$B"
    fi
  }
done
```

`-d` is the safe delete (requires merged). `-D` force-deletes — only use after explicit confirmation.

### 4. Delete remote branches (only if REMOTE_CLEANUP=true)

```bash
if [ "$REMOTE_CLEANUP" = "true" ]; then
  for B in $MERGED $SQUASH_MERGED; do
    # Only if remote branch still exists
    git ls-remote --exit-code origin "$B" > /dev/null 2>&1 || continue

    echo "Delete origin/$B? [y/N]"
    read CONFIRM
    [ "$CONFIRM" = "y" ] && git push origin --delete "$B"
  done
fi
```

### 5. Prune remote-tracking refs (already done in preflight, re-run for safety)

```bash
git remote prune origin
```

### 6. Emit summary

```
[BRANCH CLEANED]
Local deleted: <N> branches
Remote deleted: <N> branches (skipped if REMOTE_CLEANUP=false)
Remote-tracking pruned: <N> refs
Branches remaining: <N> local / <N> remote

Protected (untouched): main, master, develop, <current>, release/*
```

---

## Guardrails

- **DRY_RUN by default on first call** — show before delete. Second call with DRY_RUN=false actually deletes.
- **Never delete the current branch** — `git branch -d` would fail anyway; bail early.
- **Never delete protected branches** — hard-coded: main, master, develop, release/*. Add repo-specific via `.ciel-protected-branches` (one branch per line).
- **Squash-merge detection is heuristic** — a branch name matching a closed-merged PR isn't proof of merge (someone could have renamed + re-used). Confirm per branch in non-dry mode.
- **Remote deletes require REMOTE_CLEANUP=true** — two opt-ins (flag + per-branch confirm) before touching origin.
- **Force-delete `-D` requires per-branch confirm** — don't silently `-D`. Diverged branches might hold unpushed work.
- **Backup via `git reflog`** — informative only; `git reflog` keeps deleted commits for 90 days. Mention this before force-delete so user knows recovery exists.
- **Never `git push --force` in this skill** — deletion is `--delete`, not force.
- **Respect in-progress work** — preflight dirty-tree check prevents deleting branches while user is switching contexts.

---

## When triggered

- Post-merge handoff from `pr-merger` (after `issue-closer`)
- `meta-critiquer` item 4 "Stale branches?" when count > 20
- User says: "clean up branches", "delete merged", "prune stale"
- Session end when `git branch | wc -l` is high and user confirms cleanup

---

## Anti-pattern

```
❌ git branch -D $(git branch | grep -v main)     # nukes everything including unmerged work
✅ git branch -d <merged-only>                    # safe, refuses diverged
```

```
❌ git push origin --delete $(git branch -r)      # deletes remote branches blind
✅ Per-branch confirm with REMOTE_CLEANUP flag
```

---

## References

- `git branch --merged` — git-scm.com/docs/git-branch
- `git fetch --prune` — git-scm.com/docs/git-fetch
- `git reflog` (recovery) — git-scm.com/docs/git-reflog
- Ciel pipeline: pr-merger → issue-closer → branch-cleaner → (changelog-updater | release-publisher)
