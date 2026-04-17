---
name: api-architecture
description: Expert patterns for API design across REST, GraphQL, gRPC, WebSocket — versioning, pagination, idempotency, error shapes, rate limiting, transport auth parity, schema evolution. Invoked in parallel with researcher when API design work is detected. Auto-activates on routes/, controllers/, and *.proto files.
allowed-tools: Read, Grep
context: fork
agent: Explore
paths: "**/routes/**,**/controllers/**,**/*.proto,**/*.graphql,**/api/**"
---

# api-architecture — API design patterns

Applied in parallel with `researcher` when API surface is being designed or changed.

---

## Inputs

```
TASK: [1-sentence description]
STYLE: [REST | GraphQL | gRPC | WebSocket | mixed]
```

---

## Key patterns

### REST
- Resource-oriented URLs (nouns, not verbs): `/users/42` not `/getUser?id=42`
- HTTP methods carry semantics: GET idempotent, POST non-idempotent, PUT idempotent (replace), PATCH partial
- Status codes: 200/201/204 success, 4xx client error, 5xx server error — don't return 200 with error body
- Versioning: URL path (`/v1/users`) OR header (`Accept: application/vnd.myapi.v1+json`)
- Pagination: cursor > offset for deep pages; `Link: <...>; rel="next"` header OR response field
- Idempotency: POST endpoints that must be safe to retry → `Idempotency-Key` header

### GraphQL
- Schema-first: design schema before implementation
- N+1 via DataLoader (batch + cache within request)
- Query depth + complexity limits (prevent DoS)
- Persisted queries for public APIs
- Don't expose mutations for trivial ops (prefer REST for simple CRUD)

### gRPC
- Proto versioning: never remove fields, only deprecate
- Bi-directional streaming for real-time
- Deadlines on every RPC (don't let clients hang)
- Error model: `google.rpc.Status` with `code` + `details`

### WebSocket / SSE
- **Auth parity** with REST (same token, same checks)
- Heartbeat / ping to detect dead connections
- Per-connection rate limits
- Message size bounds
- Graceful reconnection client-side

---

## Error shape consistency

All endpoints return errors in the same shape:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Field 'email' is invalid",
    "details": [{"field": "email", "reason": "format"}],
    "request_id": "req_abc123"
  }
}
```

Never: error as 200 with `{"success": false}`. HTTP status + structured error body.

---

## Output format

```
## API ARCHITECTURE INSIGHTS — <style>

### Design checks
- Versioning strategy: <URL | header | none | MIXED ⚠️>
- Pagination: <cursor | offset | none>
- Idempotency: <header present on non-idempotent methods? | N/A>
- Error shape: <uniform | inconsistent ⚠️>

### Transport auth parity (if mixed)
- REST: <authed>
- WebSocket: <same auth? MISMATCH ⚠️>
- SSE: <same auth? MISMATCH ⚠️>

### Schema evolution
- Breaking changes detected: <none | list>
- Backward compat path: <...>

### Rate limits
- Configured: <per-IP / per-user / per-endpoint | none>

### CROSS-REFERENCES
- Conflicts with researcher findings: <none | list>
```

---

## Guardrails

- **Transport auth parity non-negotiable** — same resource via REST and WS must use same auth
- **Versioning on day 1** — retrofitting is painful
- **Pagination shape consistent** across all list endpoints
- **Never use mutation verbs in REST URLs** — `GET /api/deleteUser` is a sign of broken design

---

## When triggered

- API design/change tasks
- New endpoint creation
- Task mentions versioning, pagination, WebSocket, GraphQL, gRPC
- `paths` glob on routes/, controllers/, proto files
