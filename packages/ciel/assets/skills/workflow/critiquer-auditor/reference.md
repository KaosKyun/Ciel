# critiquer-auditor — Reference

## STRIDE — audit probes (7-step audit context)

Use these probes when running COMPARER on each STRIDE category. Mark N/A explicitly; never skip.

### S — Spoofing
- Can I impersonate another user/service in this code path?
- Identity: client-supplied or server-resolved?
- WebSocket / SSE / GraphQL subscription: same auth as REST?

### T — Tampering
- Input modified in transit? HTTPS? Signatures?
- Idempotency keys present?
- CSRF protection on state-changing endpoints?

### R — Repudiation
- Audit log coverage: who, what, when recorded?
- Log integrity: append-only? remote-shipped?

### I — Information Disclosure
- Error messages: stack traces? SQL? paths?
- Logs: PII? secrets?
- Response bodies: over-fetching? unprojected columns?
- Timing attacks: 404 vs 403 distinction?

### D — Denial of Service
- Rate limiting per IP/user/endpoint?
- Resource bounds: payload size, query depth, file upload?
- Algorithmic complexity on user-controlled input?
- Regex catastrophic backtracking?

### E — Elevation of Privilege
- Permission check BEFORE action?
- Horizontal escalation: user A read user B's data?
- Vertical escalation: mass assignment setting `isAdmin`?

## Severity rubric

### BLOCKING
- Correctness bug: code produces wrong result for some input
- Security: any STRIDE finding that an attacker can exploit
- Data loss: delete/overwrite without backup/confirm
- Production crash: uncaught exception on common path

### IMPORTANT
- Degraded behavior: works but slow / intermittent
- Tech debt with near-term risk: pattern that will break at 2x current load
- Accessibility violation: keyboard/screen reader broken
- Test debt: feature ships without meaningful test

### MINOR
- Naming / style inconsistency
- Unused import
- Todo comment for future work
- Minor DRY violation (< 3 copies)

### VALIDATED
- Explicit callout of what was checked and confirmed correct
- Useful because it shows the reviewer's mental map
- Helps author understand what was covered vs skipped

## Counterfactual analysis

Questions to answer in QUESTIONNER step:

- What if we merged without this change? What breaks?
- Is there a 10% of this change that would solve 90% of the problem?
- Is this fixing a symptom or a cause? If symptom: where's the cause?
- Is this change reversible? If yes, risk is lower.

## Bypass signal checklist (build in APPRENDRE)

Common bypass signals to look for per framework:

### React / frontend
- `window.*` or `document.*` inside components
- `useEffect` with no dependency array
- Direct DOM manipulation via `refs.current`
- `dangerouslySetInnerHTML` with non-sanitized input

### Backend / JVM
- Raw SQL string concatenation
- `catch(Exception e) { }` or `catch → null`
- `as` cast without type guard (Kotlin) or unchecked cast (Java)
- Thread creation without pool

### Async / concurrent
- `async` function called without `await`
- Promise created but not awaited
- Race conditions on shared state
- Timeout of 0 or infinite

## Layer boundary violations

- Business logic in routes / controllers → should be in services
- DB calls in controllers → should be behind repository
- UI logic in models → should be in view layer
- Tests reaching across layers without mocks

## Overlay thresholds

If `ciel-overlay.md` exists under `## Santé du code`, check its thresholds:

```
### Santé du code
- Complexité cyclomatique: < 15 par fonction
- Profondeur d'imbrication: < 4
- Taille de fonction: < 50 lignes
- Couverture test: > 80% lignes modifiées
```

If any violation: IMPORTANT finding (can be demoted to MINOR if tiny exceedance).

## Capitalization format

When `learnings-capture` is invoked from CAPITALISER:

```
[YYYY-MM-DD] MISTAKE: <what happened, 1 line>
  → RULE: <how to avoid in future, 1 line>
  → Invoke: <which skill/guard catches this>
  → Evidence: <file:line where it was found>
```

This format feeds into `ciel-overlay.md` under `## Leçons projet` (project-specific) or `.claude/learnings.md` (general).

## Anti-patterns in audits

- Reviewing without reading the diff first → operate on assumptions
- STRIDE performed but all 6 "N/A" → didn't actually probe each category
- Only finding problems (no VALIDATED) → unclear what was checked
- BLOCKING without FIX → not actionable, author can't resolve
- Copying PR description into audit → pure theater, no independent thought
