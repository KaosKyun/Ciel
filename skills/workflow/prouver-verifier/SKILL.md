---
name: prouver-verifier
description: Staging verification with AVANT/APRÈS evidence, constraint synthesis, CI gate (gh run list), PR body gate (Closes #XXX, no WIP), issue comment gate (staging PID + evidence), and closure gate. Uses Monitor for streaming logs and Bash run_in_background for one-shot deploys. Invoked as the final step before declaring any task done.
allowed-tools: Bash, WebFetch, Read
---

# prouver-verifier — Prove it works on staging

Step 10 of CRÉER. Code written ≠ done. Staging verified with AVANT/APRÈS evidence = done.

For Monitor/Bash usage details and common CI/PR/issue commands, see `reference.md`.

---

## Trivial — PROUVER allégé

1. Compile OK locally
2. Push to branch
3. Verify no regression (existing tests still green)

No CI gate mandatory, no staging mandatory. Quick smoke check.

---

## Standard/Critical — MANDATORY staging verification

Push → deploy → trigger → capture evidence → PR. Never skip.

### 1. AVANT/APRÈS obligation (bug fixes)

- **AVANT**: failing test (RED) OR log showing broken behavior — code diff ≠ proof
- **APRÈS**: staging log / curl output / HTTP status AFTER deploying AND triggering the scenario
- "No error in logs" ≠ proof — trigger the scenario, see a POSITIVE signal

### 2. Constraint synthesis (Critical — write BEFORE checking logs)

Force yourself to write the expected signals BEFORE looking:

1. Functional: `"POST /api/X returns 201 with body.data.id"`
2. Behavioral: `"Log contains '[MESSAGE]' after triggering"`
3. Negative: `"Old error '[ERROR]' no longer appears"`

Then check logs. Match or miss = clear signal.

### 3. Same-source rule

- Bug found in logs → verify fix in logs
- Bug in screenshot → verify by screenshot
- Curl result ≠ substitute for original observation source

### 4. Attacker perspective test (security fixes)

"If I were an attacker, what test proves my fix blocks me?" Write THAT test. Can't write it → fix isn't proven.

### 5. CI gate (mandatory — before any report)

```bash
gh run list --branch $BRANCH --limit 1
```

Status must be `completed/success` or `in_progress`. If failed:
```bash
gh run view --job=ID
```
Identify root cause. Fix before PR.

"CI is running" ≠ done.

### 6. PR body gate (before `gh pr create`)

- `□` PR body contains `Closes #XXX` for every linked issue?
- `□` PR title has NO WIP marker? (`WIP`, `[WIP]`, `wip`)
- After merge: `gh pr view` → status merged (not open)?

### 7. Issue comment gate (after staging verify, before PR)

Add a comment on EVERY linked issue with:
- Staging PID (process/deploy ID)
- AVANT/APRÈS evidence

Do NOT wait for post-merge. Batch PRs closing multiple issues → each issue gets its own comment.

### 8. Closure gate (before any issue is closed)

```bash
gh issue view <N> --comments
```

Does a comment with staging PID + AVANT/APRÈS exist? No → add NOW before merge (auto-close won't add it). 

Post-merge closure includes:
1. What was fixed (1 line)
2. Concrete observed evidence from staging (logs / curl / DOM — NOT code diffs)
3. PR/SHA reference

Closure without evidence = not closed.

---

## Output format

```
## PROUVER

### AVANT (before fix)
<log excerpt / curl output / screenshot reference>

### APRÈS (after fix, on staging)
<log excerpt / curl output / screenshot reference>

### Constraints (written before check)
1. Functional: <expected signal>
2. Behavioral: <expected signal>
3. Negative: <expected absence>

### CI gate
- Branch: <branch>
- Run: <gh run URL>
- Status: <success | in_progress | failed>

### PR body gate
- [✓/✗] Closes #XXX present
- [✓/✗] No WIP marker
- [✓/✗] Draft vs ready correct

### Issue comments
- #<N>: comment added with PID + AVANT/APRÈS
- ...

### Closure gate
- #<N>: closure comment (fix + evidence + PR ref)
- ...

### VERDICT
<DONE | PENDING: list of remaining items>
```

---

## Guardrails

- **NEVER use `sleep N && tail`** — harness blocks it. Use Monitor for streaming, Bash run_in_background for one-shot waits. See `reference.md` for correct patterns.
- **Evidence must be concrete**: a log line, a curl response, a screenshot path. "Looks good" is not evidence.
- **CI gate pass ≠ done**: green CI + no staging evidence = still not done for Standard/Critical
- **Batch care**: one PR closing 3 issues → 3 individual comments, not one comment claiming it covers all three
- **Close loop**: after PROUVER passes, invoke `meta-critiquer` to reflect and `learnings-capture` to persist any new failure mode observed

---

## When triggered

- After RELIRE passes
- When preparing to open a PR
- Before closing any issue
- When user says "done" or "ready to merge"
