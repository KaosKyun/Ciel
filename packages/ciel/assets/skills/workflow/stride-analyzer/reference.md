# stride-analyzer — Reference

## STRIDE — detailed category probes

### S — Spoofing (identity)

Can I impersonate another user/service/system?

Probes:
- Grep for `userId` / `user_id` coming from request params vs resolved server-side (JWT, session)
- Grep for identity claims trusted without verification (e.g. `X-User-Id` header accepted as-is)
- Check auth middleware ordering: is authentication before authorization?
- WebSocket/SSE: is the same auth applied? (common gap: REST auth is bulletproof, WS accepts any token)

Evidence format:
```
- Spoofing: userId extracted from JWT claim at JwtMiddleware.kt:45 — not client-supplied ✓
```

### T — Tampering (data integrity)

Can input be modified in transit or at rest without detection?

Probes:
- HTTPS everywhere? Grep for `http://` (non-localhost)
- CSRF tokens on state-changing endpoints?
- Signed cookies / signed JWTs? What algorithm? (HS256 vs RS256 considerations)
- Database writes: is the audit trail immutable? (INSERT-only tables for events)

### R — Repudiation (non-denial)

Can a user deny having performed an action?

Probes:
- Audit log coverage: what events are logged? With what identity?
- Log tampering resistance: append-only? Logged externally?
- Timestamp source: server-controlled? Synced?

### I — Information Disclosure

What information leaks to unauthorized parties?

Probes:
- Error messages: do they include stack traces / SQL / paths / credentials?
- Logs: do they contain PII, secrets, tokens?
- API responses: over-fetching? `SELECT *` instead of projected columns?
- 404 vs 403 distinction: timing attack on existence probe?
- Autocomplete endpoints: leak usernames / emails?

### D — Denial of Service

Can this be flooded or exhausted?

Probes:
- Rate limiting: per-IP? per-user? per-endpoint?
- Resource bounds: max payload size? max query depth (GraphQL)? max file upload?
- Algorithmic complexity: O(n²) loops on user-controlled n?
- Connection pooling: max connections? timeout?
- Regex catastrophic backtracking on user input?

### E — Elevation of Privilege

Can I access what I shouldn't?

Probes:
- RBAC/ABAC correctness: does the permission check run before the action?
- Horizontal privilege escalation: can user A read user B's data with API manipulation?
- Vertical privilege escalation: can user become admin via some path?
- Mass assignment: can user set `isAdmin` via PATCH body?

## OPS lens (overlayed on STRIDE)

- **Unclosed connections**: grep for `conn.close()` / `client.close()` / `try-with-resources` / `use {}` — every open should have a close
- **Memory leaks**: long-lived caches without eviction? Unbounded collections? Listeners not removed?
- **Locks**: deadlock-prone order? Held across I/O?
- **100x volume**: if traffic grew 100x tomorrow, what breaks first?

## Killer checklist — detail

### Same field = same validation everywhere

If `email` is validated one way in `RegisterRoute.kt` and another way in `ProfileUpdateRoute.kt`, an attacker uses the weaker one. Validation must be centralized.

```bash
# Find all places email is validated
grep -rn "email" --include='*.kt' src/ | grep -iE 'valid|sanitize|check'
```

Evidence: all call sites converge on a single validator.

### Same domain = same auth on ALL transports

REST endpoint has auth; WebSocket channel for the same resource doesn't (or uses different auth). Attacker bypasses via WebSocket.

```bash
grep -rn "authenticate" src/ --include='*.kt'
grep -rn "socket\|websocket\|sse\|webFluxClient" src/
```

### Identity resolved server-side

```bash
# Any userId coming from request body/path?
grep -rn 'call.parameters\["userId"\]' src/
grep -rn 'request.body.userId' src/
# Should all be via JWT/session claim
```

### SQL parameterized

```bash
# Find string interpolation in SQL
grep -rn "\\\$" src/ --include='*.kt' | grep -iE 'sql|query'
grep -rn "\"SELECT.*\"\ +\ " src/
```

### PII anonymization

```bash
# Find logging of user fields
grep -rn "logger.info.*user" src/
grep -rn "println.*email\|println.*phone" src/
```

## Multi-PR delegation

When the same reviewer has done 2+ STRIDE passes on related PRs in one session, blind spots compound. Delegate the 2nd pass to a subagent:

```
Task(subagent_type="Explore", prompt="""
Run STRIDE PASSE 2 on this diff. Fresh eyes, no session history.
CHANGED_FILES: [...]
FOCUS: category you feel is weakest
""")
```

## Stale item rotation

Tracked via `learnings-capture`: if a killer checklist item passes (✓) in 10+ audits without catching anything, flag for review. Either:

- The codebase is genuinely clean on that dimension → consider removing item
- The item is too vague to fail → tighten the check

Replace with a newer, more specific check.
