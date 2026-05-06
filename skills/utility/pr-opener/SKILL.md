---
name: pr-opener
description: Opens a GitHub pull request for the current branch using `gh pr create`. Composes the body with Summary + Test plan + Closes #N, auto-links the tracked issue (Closes #N), attaches Ciel verification evidence (tests passing, CI green, RELIRE verdict). Runs after FAIRE completion, before the user asks. The final step of the automated workflow before issue-closer. Inline — deterministic `gh` command.
allowed-tools: Bash, Read
context: inline
---

# pr-opener — Close the loop, link the issue

A PR without an issue link is a commit without a reason. Ciel's `pr-opener` guarantees every PR auto-closes its source issue on merge.

---

## Inputs

```
ISSUE_NUMBER: [from .git/ciel-work-context written by branch-setup]
BRANCH: [current branch — from git rev-parse]
TITLE: [1-line summary — imperative, ≤ 70 chars]
BASE_BRANCH: [main usually, from .git/ciel-work-context]
DRAFT: [true|false — default false, true if CI not yet green]
```

### Auto-inference sources

- **ISSUE_NUMBER, BRANCH, BASE_BRANCH** → read `.git/ciel-work-context`
- **TITLE** → derive from the latest commit message on the branch (`git log -1 --format=%s`), strip conventional-commit prefix if present
- **DRAFT** → true if `gh run list --branch=$BRANCH --limit=1 --json status --jq '.[0].status'` returns in_progress OR any test is failing

---

## Preflight

```bash
# 1. gh auth
gh auth status 2>&1 | grep -q "Logged in" || { echo "gh not authenticated"; exit 1; }

# 2. Branch pushed to origin
CURRENT=$(git rev-parse --abbrev-ref HEAD)
git ls-remote --exit-code origin "$CURRENT" > /dev/null 2>&1 || {
  echo "Branch not pushed — pushing now"
  git push -u origin "$CURRENT"
}

# 3. Work context exists
[ -f .git/ciel-work-context ] || { echo "No .git/ciel-work-context — did branch-setup run?"; exit 1; }

# 4. Not already a PR open for this branch
gh pr list --head "$CURRENT" --state=open --json number --jq '.[0].number' | grep -q . && {
  PR_NUM=$(gh pr list --head "$CURRENT" --state=open --json number --jq '.[0].number')
  echo "PR already exists: #$PR_NUM — updating body instead"
  UPDATE_MODE=true
}
```

---

## Process

### 1. Compose the PR body

Extract linked issue from branch name (`<type>/<N>-...` → issue #N) or `.git/ciel-work-context`.

Summarize changes from commits + diff stat: top 3 changes by impact (by lines changed or commit subject classification). Avoid exhaustive file list.

Assemble with:

```
ISSUE_NUMBER: <N>
BRANCH: <branch>
COMMITS: git log origin/$BASE_BRANCH..HEAD --oneline
CHANGED_FILES: git diff --stat origin/$BASE_BRANCH...HEAD
RELIRE_VERDICT: [from critic agent if invoked]
CI_STATUS: gh run list --branch=<branch> --limit=1 --json conclusion
EVIDENCE: [prouver-verifier output if applicable]
```

Expected body structure (generated):

```markdown
## Summary

<1-3 bullets — what changed and why>

## Closes

Closes #<N>

## Changes

<git diff --stat output>

## Test plan

- [x] Unit tests pass (<N> added/modified)
- [x] Integration tests pass
- [x] Manual verification: <staging evidence from prouver-verifier>
- [x] No regression on existing suites

## Evidence

- Staging logs: <snippet>
- CI run: <URL to gh run>
- RELIRE verdict: <BLOCKING: none | IMPORTANT: N | MINOR: N>

🤖 Opened by Ciel (pr-opener)
```

### 2. Create or update the PR

```bash
if [ -z "$UPDATE_MODE" ]; then
  gh pr create \
    --base "$BASE_BRANCH" \
    --head "$CURRENT" \
    --title "<title>" \
    --body-file /tmp/ciel-pr-body-$$ \
    $([ "$DRAFT" = "true" ] && echo "--draft")
else
  gh pr edit "$PR_NUM" --body-file /tmp/ciel-pr-body-$$
fi
```

### 3. Emit output

```
[PR OPENED]
Number: #<P>
URL: https://github.com/<org>/<repo>/pull/<P>
Closes: #<N>
Draft: <true|false>
CI: <pending|running|passed|failed>
```

---

## Guardrails

- **Closes #N is mandatory** — if the work came from an issue, the PR MUST close it on merge. This is what makes the workflow a closed loop.
- **Draft if CI red** — don't request review on a broken PR. Flip to ready only after CI green.
- **Body ≤ 65 KB** — GitHub limit; truncate evidence + link to gist if needed.
- **Push before PR** — branch must be on origin. Auto-push if not.
- **Respect existing PR** — if one is already open for this branch, UPDATE it, don't create a duplicate.
- **Never auto-merge** — opening the PR is the end of Ciel's automated work. Merge decision is the user's.
- **`prouver-verifier` MUST have run green before the merge command** (mirror of `skills/ciel/SKILL.md`) — applies to every merge path: `gh pr merge [--auto|--squash|--merge|--rebase]`, `git push` direct-to-default, GitHub UI "Merge" button. If pr-opener is asked to auto-merge (e.g., user passes a `--merge-when-green` intent), refuse unless `.git/ciel-prouver-verdict` exists with `verdict=PASS`.
- **Never `--no-verify`** — pre-push hooks run; if they fail, investigate, don't skip.

---

## When triggered

- End of FAIRE step when a branch was created by `branch-setup`
- `prouver-verifier` PROUVER step completes successfully
- User says "open a PR" after finishing work
- Skip if Trivial task (direct push to main was the intent)

---

## How to verify

- [ ] `gh auth status` passes?
- [ ] Branch pushed to origin?
- [ ] `.git/ciel-work-context` exists?
- [ ] PR created/updated on GitHub? (`gh pr view` succeeds)
- [ ] `Closes #N` present in body?
- [ ] Body has Summary + Test plan + Evidence sections?
- [ ] Draft status correct? (draft if CI red, ready if green)
- [ ] No duplicate PR? (checked for existing open PR first)

## Handoff to issue-closer

`pr-opener` DOES NOT close the issue — `issue-closer` does that POST-merge with evidence. The PR body's `Closes #N` is a GitHub-level auto-close hook; `issue-closer` adds the structured comment with production evidence after merge lands.

---

## References

- GitHub CLI — cli.github.com/manual/gh_pr_create
- GitHub auto-close keywords — docs.github.com/en/issues/tracking-your-work-with-issues/closing-an-issue-automatically
- Ciel pipeline: issue-creator → branch-setup → FAIRE → pr-opener → issue-closer (post-merge)
