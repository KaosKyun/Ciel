---
name: prouver-verifier
description: How to verify implementation with evidence — AVANT/APRÈS methodology, constraint synthesis, CI gate, PR body gate, issue comment gate, and closure gate. Proves code works with concrete evidence, not assumptions.
allowed-tools: Bash, WebFetch, Read
---

# Implementation Verification — Evidence-Based Proof

## What this covers

How to prove that code works with concrete evidence. Code written ≠ done. Verified with AVANT/APRÈS evidence = done.

## Core principle

**"No error in logs" ≠ proof.** Trigger the scenario, see a POSITIVE signal.

## AVANT/APRÈS methodology (bug fixes)

- **AVANT**: failing test (RED) OR log showing broken behavior — code diff ≠ proof
- **APRÈS**: staging log / curl output / HTTP status AFTER deploying AND triggering the scenario

### Same-source rule

- Bug found in logs → verify fix in logs
- Bug in screenshot → verify by screenshot
- Curl result ≠ substitute for original observation source

### Constraint synthesis (write BEFORE checking logs)

Force yourself to write expected signals BEFORE looking:

1. Functional: `"POST /api/X returns 201 with body.data.id"`
2. Behavioral: `"Log contains '[MESSAGE]' after triggering"`
3. Negative: `"Old error '[ERROR]' no longer appears"`

Then check logs. Match or miss = clear signal.

### Attacker perspective (security fixes)

"If I were an attacker, what test proves my fix blocks me?" Write THAT test. Can't write it → fix isn't proven.

## Verification gates

### CI gate

```bash
gh run list --branch $BRANCH --limit 1
```

Status must be `completed/success`. If failed → identify root cause, fix before PR.

"CI is running" ≠ done.

### PR body gate

- `Closes #XXX` present for every linked issue?
- No WIP marker? (`WIP`, `[WIP]`, `wip`)
- Draft vs ready correct?

### Issue comment gate

Add a comment on EVERY linked issue with:
- Staging PID (process/deploy ID)
- AVANT/APRÈS evidence

Do NOT wait for post-merge. Batch PRs → each issue gets its own comment.

### Closure gate

```bash
gh issue view <N> --comments
```

Does a comment with staging PID + AVANT/APRÈS exist? No → add NOW before merge.

Post-merge closure includes:
1. What was fixed (1 line)
2. Concrete observed evidence (logs / curl / DOM — NOT code diffs)
3. PR/SHA reference

Closure without evidence = not closed.

## Quick verification (trivial tasks)

1. Compile OK locally
2. Push to branch
3. Verify no regression (existing tests still green)

No CI gate mandatory, no staging mandatory.

## Output format

```
## VERIFICATION

### AVANT (before fix)
<log excerpt / curl output / screenshot>

### APRÈS (after fix, on staging)
<log excerpt / curl output / screenshot>

### Constraints (written before check)
1. Functional: <expected signal>
2. Behavioral: <expected signal>
3. Negative: <expected absence>

### CI gate
- Run: <URL>
- Status: <success | in_progress | failed>

### PR body gate
- [✓/✗] Closes #XXX present
- [✓/✗] No WIP marker

### Issue comments
- #<N>: comment added with PID + AVANT/APRÈS

### VERDICT
<DONE | PENDING: remaining items>
```

## How to verify

- [ ] AVANT state captured (before fix)?
- [ ] APRÈS state captured (after fix, on staging)?
- [ ] Constraints written BEFORE checking logs?
- [ ] CI gate passed?
- [ ] PR body gate passed (AVANT/APRÈS evidence)?
- [ ] Issue comment gate passed (evidence posted)?
- [ ] VERDICT issued (DONE / NOT-YET)?

## Common mistakes

- **"No error in logs"**: not proof — trigger the scenario and look for positive signal
- **Code diff as proof**: showing what changed ≠ showing it works
- **Missing AVANT**: without before-state, can't prove improvement
- **Skipping issue comments**: auto-close won't add evidence — do it manually
