---
name: ci-watcher
description: Streams GitHub Actions via `gh run watch`, classifies failures flaky (≥15% fail rate on main → auto-`gh run rerun --failed`) vs real (hand off to debug-reasoning-rca). Invoke after pr-opener, before pr-merger, or on "CI stuck" / "why is CI red" / "flaky test". Inline.
allowed-tools: Bash, Read
context: inline
---

# ci-watcher — Watch CI, distinguish flaky from broken, retry smart

`prouver-verifier` takes a single-point snapshot of CI state. `ci-watcher` watches over time: streams the run, waits for completion, classifies failures as flaky vs real, retries only what's safe.

---

## Inputs

```
BRANCH: [current branch — from git rev-parse]
PR_NUMBER: [optional — derived if branch has an open PR]
WORKFLOW: [optional — filter to specific workflow name; default all]
MODE: [watch | snapshot — default watch; snapshot = single poll + return]
MAX_RETRIES: [default 1 — for flaky-detected failures only]
FLAKY_THRESHOLD: [default 15 — % fail rate on main that classifies as flaky]
```

### Auto-inference sources

- **BRANCH** → `git rev-parse --abbrev-ref HEAD`
- **PR_NUMBER** → `gh pr view --json number --jq.number 2>/dev/null`
- **WORKFLOW** → all workflows that ran on the branch

---

## Preflight

```bash
gh auth status 2>&1 | grep -q "Logged in" || exit 1
BRANCH=${BRANCH:-$(git rev-parse --abbrev-ref HEAD)}

# Confirm branch has at least one run
LATEST=$(gh run list --branch="$BRANCH" --limit=1 --json databaseId,status,conclusion --jq '.[0] // empty')
[ -z "$LATEST" ] && { echo "No runs found for branch $BRANCH — push first"; exit 1; }
```

---

## Process

### 1. Stream or snapshot

**Watch mode (default)** — stream until completion:

```bash
RUN_ID=$(gh run list --branch="$BRANCH" --limit=1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
RESULT=$?
```

`--exit-status` returns non-zero on run failure. `gh run watch` streams logs as they appear.

**Snapshot mode** — single poll:

```bash
gh run list --branch="$BRANCH" --limit=5 --json databaseId,name,status,conclusion,url
```

### 2. On failure — classify flaky vs real

```bash
# Get failing jobs for this run
FAILED_JOBS=$(gh run view "$RUN_ID" --json jobs --jq '.jobs[] | select(.conclusion == "failure") |.name')

# For each failed job, check history on the base branch
BASE=$(gh pr view "$PR_NUMBER" --json baseRefName --jq.baseRefName 2>/dev/null || echo "main")

for JOB in $FAILED_JOBS; do
  # Last 50 runs on base branch for same workflow
  WORKFLOW=$(gh run view "$RUN_ID" --json workflowName --jq.workflowName)
  FAIL_RATE=$(gh run list \
    --branch="$BASE" \
    --workflow="$WORKFLOW" \
    --limit=50 \
    --json conclusion \
    --jq '[.[] | select(.conclusion == "failure")] | length')

  FAIL_PCT=$((FAIL_RATE * 100 / 50))

  if [ "$FAIL_PCT" -ge "$FLAKY_THRESHOLD" ]; then
    echo "Job '$JOB' fails ${FAIL_PCT}% of the time on $BASE — CLASSIFIED FLAKY"
    FLAKY_JOBS+=("$JOB")
  else
    echo "Job '$JOB' fails ${FAIL_PCT}% of the time on $BASE — CLASSIFIED REAL FAILURE"
    REAL_FAILURES+=("$JOB")
  fi
done
```

**Flaky threshold rationale**: 15% = 7-8 failures in 50 runs. Below that, a single failure is likely the PR's fault. Above, it's environmental/test-harness instability.

### 3. Retry flaky jobs (up to MAX_RETRIES)

```bash
if [ ${#FLAKY_JOBS[@]} -gt 0 ] && [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; then
  echo "Retrying flaky jobs (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
  gh run rerun "$RUN_ID" --failed
  RETRY_COUNT=$((RETRY_COUNT+1))
  # Re-enter step 1 (watch the rerun)
fi
```

`--failed` only reruns failed jobs (saves CI minutes).

### 4. Extract log excerpt for real failures

For handoff to `debug-reasoning-rca`:

```bash
for JOB in $REAL_FAILURES; do
  JOB_ID=$(gh run view "$RUN_ID" --json jobs --jq ".jobs[] | select(.name == \"$JOB\") |.databaseId")

  # Last 50 lines of the failing step
  gh run view --job="$JOB_ID" --log-failed | tail -50
done
```

### 5. Emit output

```
[CI WATCHER]
Run: <URL>
Status: <success | failure | in_progress>
Duration: <Xm Ys>

Jobs:
  [OK]   build
  [OK]   lint
  [WARN] integration-tests — FLAKY (fails 18% on main, retried — now green)
  [FAIL] unit-tests — REAL FAILURE (fails 2% on main — investigate)

Handoff (if real failures):
  - debug-reasoning-rca with SYMPTOM=<failing test name> + LOG excerpt
```

---

## Guardrails

- **MAX_RETRIES=1 by default** — a flaky test that fails twice in a row is likely not flaky. Don't spam retries.
- **Never retry real failures** — the retry mechanism is ONLY for jobs classified flaky. Real failures need a code fix.
- **Never retry pre-merge checks on main** — only PR branches. Retrying on main risks hiding real regressions.
- **Budget-aware**: large rerun loops burn CI minutes. Log estimated minutes cost before retry on repos with tight budgets.
- **Respect timeouts**: `gh run watch` can hang if a job hangs. Wrap in `timeout 1800 gh run watch` for 30-min ceiling.
- **Flaky classification is per-job, not per-run**: if 3 of 5 jobs are flaky but 1 is real, DO NOT retry — fix the real one first.
- **Store flaky detections** — append to `.claude/flaky-tests.log` (optional, per-project) so patterns surface across sessions.

---

## When triggered

- After `pr-opener` in Standard pipeline (step 11 post-insertion)
- Before `pr-merger` as CI-green verification (replaces inline `gh run list` check)
- User says: "watch CI", "is CI green?", "CI is flaky", "rerun failed jobs"
- `prouver-verifier` detects a red CI and needs disambiguation

---

## Anti-pattern

```
❌ Failed → rerun blindly → rerun → rerun → real bug hidden, minutes wasted
✅ Failed → classify (fail % on main) → retry only flaky → real fail → debug-reasoning-rca
```

```
❌ sleep 300 && gh run list # blocked by harness; also cache-cold
✅ gh run watch --exit-status # streams, no sleep
```

---

## Handoff

- **If all green** → `pr-merger` can proceed
- **If real failure** → `debug-reasoning-rca` via `@ciel-critic` with log excerpt as SYMPTOM + failing job as SCOPE
- **If flaky detected + retry succeeded** → proceed to `pr-merger`, log flaky for future `/ciel-improve` signal
- **If flaky + retry failed** → escalate to user (flaky-turned-real or real-misclassified)

---

## References

- `gh run watch` — cli.github.com/manual/gh_run_watch
- `gh run rerun --failed` — cli.github.com/manual/gh_run_rerun
- Flaky test classification — Google's 2020 paper "Taming Google-scale continuous testing" (15% threshold baseline)
- Ciel pipeline: pr-opener → ci-watcher → (flaky? retry : debug-reasoning-rca) → pr-merger
