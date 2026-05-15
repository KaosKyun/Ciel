# prouver-verifier — Reference

## Log observation tools — three modes, use the right one

| Need | Tool | Example |
|------|------|---------|
| Snapshot (last N lines) | `Bash` | `journalctl -u neiyomi-staging -n 50 --no-pager` |
| Stream (watch for events) | `Monitor` | `journalctl -u neiyomi-staging -f \| grep --line-buffered "keyword"` |
| One-shot wait (deploy done?) | `Bash` with `run_in_background: true` | `deploy-staging.sh` |

**NEVER** use `sleep N && tail` or `sleep N && journalctl` — the harness blocks it. Use Monitor for streaming events, Bash `run_in_background` for one-shot waits.

### Monitor example

```
Monitor(
  description: "staging logs after deploy",
  persistent: false,
  timeout_ms: 60000,
  command: "journalctl -u neiyomi-staging -f --since now | grep --line-buffered 'keyword'"
)
```

Always use `grep --line-buffered` in pipes — without it, pipe buffering delays events by minutes.

### Monitor budget

Every Monitor stdout line becomes a conversation message. Always filter. Use `persistent: false` with tight `timeout_ms` for verification (60s typical). Reserve `persistent: true` for session-long watches (debugging live traffic).

### Bash run_in_background

For deploys or long-running one-shot commands:

```
Bash(command="deploy-staging.sh", run_in_background=true)
```

Returns immediately with a PID. Use BashOutput tool later to retrieve output. You'll be notified when the command completes — don't poll.

## CI commands — gh CLI

```bash
# Check CI for current branch
gh run list --branch $(git branch --show-current) --limit 1

# View failing job details
gh run view --job=<ID> --log-failed

# Wait for CI to complete (polling — prefer notification pattern)
gh run watch <run-id>

# List PR status
gh pr list --state open --draft
gh pr view <N>
gh pr ready <N>  # Convert draft to ready

# Issue comments
gh issue view <N> --comments
gh issue comment <N> --body "..."
```

## Staging evidence — what counts

**Good evidence** (trust-worthy):
- Log line with timestamp showing the expected behavior (`2026-04-17T14:23:15 [INFO] User 42 updated profile successfully`)
- Curl output with HTTP status + response body matching constraints
- Screenshot with URL bar showing staging domain + relevant UI state
- DOM snapshot (accessibility tree) showing expected elements

**Weak evidence** (insufficient on its own):
- "No errors in logs"
- "Tests pass"
- "I tested it locally"
- "The CI is green"
- Diff of the code (proves intent, not behavior)

## Constraint synthesis — examples

Good constraints (specific, falsifiable):

```
1. Functional: `POST /api/users/42/profile` with name="Alice" returns HTTP 200 with body `{"id":42,"name":"Alice","updatedAt":<ISO 8601>}`
2. Behavioral: Log contains `[UserService] Profile updated for user 42` within 5s of trigger
3. Negative: Log does NOT contain `[UserService] Validation failed` after trigger
```

Bad constraints (vague):

```
1. Endpoint works
2. User is saved
3. No errors
```

## PR body template

```
## Summary
<1-3 bullets describing what changed and why>

## Test plan
- [ ] Unit tests for <component>
- [ ] Integration test for <boundary>
- [ ] Manual verification on staging: <URL>

## Evidence
- AVANT: <log excerpt or URL>
- APRÈS: <log excerpt or URL>

Closes #<issue>
```

Rules:
- Title ≤ 70 chars, no WIP marker
- `Closes #XXX` required for every linked issue
- Evidence section non-optional for bug fixes

## Issue comment template

```
Deployed to staging.

**PID**: <deploy-id>
**AVANT** (broken):
<log/curl/screenshot>

**APRÈS** (fixed):
<log/curl/screenshot>

Triggered by: <PR #N> / <commit SHA>
```

## Post-merge closure comment

```
Fixed: <1 line description>

**Evidence** (from staging):
<concrete log/curl/DOM — NOT code diffs>

PR: #<N>
Commit: <SHA>
```

## Common failure modes

- Declaring "done" while CI is in_progress → wait for completion
- Declaring "done" with AVANT captured but no APRÈS on staging
- Evidence from same source as bug, but wrong time (read logs from before the deploy)
- PR opened with `[WIP]` title → PR never reviewed, rots as draft
- Batch PR closing 3 issues with one comment copy-pasted → not sufficient, each issue needs its own evidence
- Closure gate skipped because "CI will auto-close via PR merge" → closure via auto-close never adds evidence comment
