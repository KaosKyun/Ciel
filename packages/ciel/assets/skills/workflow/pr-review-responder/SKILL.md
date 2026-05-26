---
name: pr-review-responder
description: Handles PR review comments — lists unresolved threads via GraphQL, classifies accept/reject/clarify, applies fixes, marks resolved, re-requests review. Invoke on CHANGES_REQUESTED, "respond to PR review", "address review feedback". Inline.
allowed-tools: Bash, Read, Edit
context: inline
---

# pr-review-responder — Respond to PR feedback systematically

A PR in CHANGES_REQUESTED state is a dead PR until its comments are addressed. This skill closes the feedback loop: list, classify, respond, mark resolved, re-request.

---

## Inputs

```
PR_NUMBER: [from current branch or explicit]
REVIEWER: [optional — filter by specific reviewer login]
MODE: [interactive | batch — default interactive; in batch, only respond to accept/reject, flag clarify for user]
```

### Auto-inference sources

- **PR_NUMBER** → `gh pr view --json number --jq.number`
- **REVIEWER** → latest reviewer from `gh pr view --json reviews --jq '.reviews[-1].author.login'`

---

## Preflight

```bash
gh auth status 2>&1 | grep -q "Logged in" || exit 1
PR_NUMBER=${PR_NUMBER:-$(gh pr view --json number --jq.number)}
[ -z "$PR_NUMBER" ] && { echo "No PR for current branch"; exit 1; }

# Must be on the PR's head branch to push fixes
HEAD=$(gh pr view "$PR_NUMBER" --json headRefName --jq.headRefName)
CURRENT=$(git rev-parse --abbrev-ref HEAD)
[ "$HEAD" = "$CURRENT" ] || { echo "Checkout the PR branch first: gh pr checkout $PR_NUMBER"; exit 1; }
```

---

## Process

### 1. Fetch unresolved review threads

GitHub's REST API doesn't expose thread-resolution state directly — use GraphQL:

```bash
OWNER=$(gh repo view --json owner --jq.owner.login)
REPO=$(gh repo view --json name --jq.name)

gh api graphql -f query="
  query {
    repository(owner: \"$OWNER\", name: \"$REPO\") {
      pullRequest(number: $PR_NUMBER) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            path
            line
            comments(first: 10) {
              nodes { author { login } body createdAt }
            }
          }
        }
      }
    }
  }
" --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)'
```

Extract: thread ID, file path, line, comment bodies, reviewer login.

### 2. Classify each unresolved thread

For each thread, classify:

- **ACCEPT** — reviewer has a valid point, code change needed. Examples: bug, missed edge case, naming, obvious improvement.
- **REJECT** — reviewer misread / disagreement on non-blocking preference. Document the rebuttal.
- **CLARIFY** — ambiguous; ask reviewer a follow-up question. Examples: "Did you mean X or Y?", "This was intentional because Z — does that address your concern?"

Classification heuristic:
- Comment contains "bug", "broken", "wrong", "missing" → likely ACCEPT
- Comment contains "nit", "preference", "style" → likely REJECT (if inconsistent with codebase convention) or ACCEPT (if aligns)
- Comment is a question (contains "?") → likely CLARIFY

In `MODE=batch`, auto-handle ACCEPT + REJECT; defer CLARIFY to user.

### 3. Apply code changes for ACCEPT threads

For each ACCEPT:

```bash
# Read the file at the reviewer-pointed line
# Apply the suggested change (from comment body, or derived from review context)
# Example: reviewer suggests "use `?.` instead of `&&` chain"
```

Use Edit tool for precise changes. Group changes by file. Commit each logical group separately:

```bash
git add <file>
git commit -m "fix: address review feedback on <file>:<line>

Addresses comment from @<reviewer>:
> <first line of reviewer comment>

Refs #<PR_NUMBER>"
```

### 4. Reply + resolve threads

For each thread (ACCEPT or REJECT):

```bash
# Post reply comment
gh api graphql -f query="
  mutation {
    addPullRequestReviewThreadReply(input: {
      pullRequestReviewThreadId: \"<THREAD_ID>\"
      body: \"<reply>\"
    }) { comment { id } }
  }
"

# Resolve thread
gh api graphql -f query="
  mutation {
    resolveReviewThread(input: { threadId: \"<THREAD_ID>\" }) {
      thread { isResolved }
    }
  }
"
```

Reply templates:
- ACCEPT applied: `"Good catch — fixed in <SHA>. Thanks!"`
- REJECT: `"Intentional — <rebuttal>. Happy to reconsider if you disagree."`
- CLARIFY (user-authored follow-up): `"<user question>"`

### 5. Push + re-request review

```bash
git push origin "$CURRENT"

# Collect reviewer logins (those who left the resolved threads)
REVIEWERS=$(gh pr view "$PR_NUMBER" --json reviews --jq '[.reviews[].author.login] | unique | join(",")')

# Re-request review from original reviewer(s)
for R in $(echo "$REVIEWERS" | tr ',' ' '); do
  gh api \
    --method POST \
    "repos/$OWNER/$REPO/pulls/$PR_NUMBER/requested_reviewers" \
    -f "reviewers[]=$R"
done
```

### 6. Emit output

```
[REVIEW RESPONDED]
PR: #<P>
Unresolved threads: <N>
Accepted: <N> (fixes pushed in <count> commits)
Rejected: <N> (rebuttals posted)
Clarify (deferred to user): <N>
Reviewers re-requested: <@user1, @user2>
```

---

## Guardrails

- **Never force-resolve a thread without replying** — always post a reply before marking resolved; silent resolution is hostile.
- **Never accept a change that breaks tests** — run the test suite locally after each ACCEPT commit. If red, revert and reclassify to CLARIFY.
- **Never reject without rationale** — a REJECT reply must explain *why*, reference codebase convention or past decision.
- **CLARIFY blocks the merge** — a thread in CLARIFY state is NOT resolved. `pr-merger` must see 0 unresolved threads.
- **Batch mode is dangerous for CLARIFY** — in batch, always defer CLARIFY to user rather than auto-replying with a guess.
- **Don't touch unrelated code** — a review comment on `auth.ts:42` only authorizes edits to that file/area. Scope creep invalidates the review.
- **Re-request review only after push succeeds** — don't re-request on a broken push.

---

## When triggered

- `gh pr view` shows `reviewDecision: CHANGES_REQUESTED`
- User says: "respond to PR review", "address comments on PR #N", "handle review feedback"
- After `pr-opener` if reviewers are auto-added and they post comments within the same session

---

## Anti-pattern

```
❌ Reviewer comment → silent push → reviewer confused about what changed
✅ Reviewer comment → reply acknowledging → push → resolve thread → re-request
```

```
❌ Batch-auto-reply "Done" to all threads without applying changes
✅ Apply change, reference SHA in reply, mark resolved
```

---

## References

- GraphQL review threads — docs.github.com/en/graphql/reference/objects#pullrequestreviewthread
- Resolve thread mutation — docs.github.com/en/graphql/reference/mutations#resolvereviewthread
- Request reviewers API — docs.github.com/en/rest/pulls/review-requests
- Ciel pipeline: pr-opener → (reviewer comments) → pr-review-responder → pr-merger
