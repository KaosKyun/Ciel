---
name: observability
description: Expert patterns for logs (structured + correlation IDs), metrics (RED/USE), traces (OpenTelemetry), and Monitor usage for live verification. Ensures new code is observable in production. Invoked during FAIRE step when adding server-side code, background jobs, or integrations. Complements prouver-verifier (staging evidence capture).
allowed-tools: Read, Grep, Bash
---

# observability — Observable production code

Code without observability is blind in production. This skill ensures logs/metrics/traces are added WITH the feature, not as an afterthought.

---

## 3 pillars

### 1. Logs

Structure:
- JSON format (not line-based)
- Include: timestamp (ISO 8601), level, message, correlation_id, user_id (if authed), request_id
- Levels: DEBUG (dev only), INFO (business events), WARN (recoverable problems), ERROR (user-impacting), FATAL (service-impacting)

What to log:
- Entry/exit of business operations (not every function)
- Unexpected conditions (stale cache hit, fallback triggered)
- External calls: URL, status, duration (no body unless safe)
- Auth events: login, logout, privilege change
- Errors: exception with stack trace + context

What NOT to log:
- Passwords, tokens, full credit card numbers, SSN
- Large payloads (truncate to N KB)
- Every function call (debug noise)

### 2. Metrics

**RED method** (services):
- **R**ate: requests/sec
- **E**rrors: error rate
- **D**uration: latency distribution (p50, p95, p99)

**USE method** (resources):
- **U**tilization: % of capacity used
- **S**aturation: queue depth / wait time
- **E**rrors: error events

Metric types:
- Counter: monotonically increasing (requests_total)
- Gauge: point-in-time value (connections_open)
- Histogram: distribution (request_duration_seconds)

Cardinality limit: tag values must be bounded (not user_id — too many series).

### 3. Traces (distributed)

OpenTelemetry / Jaeger / Zipkin:
- Propagate trace context across service boundaries (W3C Trace Context header)
- Spans: one per significant operation
- Attributes: non-sensitive context (no PII)
- Root span per incoming request; child spans per outbound call / DB query / cache miss

---

## Correlation ID pattern

Every log line + metric dimension + trace span carries a request_id:

1. Generated at edge (load balancer or first service)
2. Propagated via header: `X-Request-Id` / `traceparent`
3. Included in every log: `{..., "request_id": "req_abc123"}`
4. Included in error responses: `{error: {request_id: "..."}}`

Supports: "find all logs for this user's complaint about slow page" in 1 query.

---

## Output format

```
## OBSERVABILITY INSIGHTS

### Logs added
- <file:line> — <event logged> — <level> — <fields included>

### Metrics added
- <metric name> — <type: counter/gauge/histogram> — <labels>

### Traces added
- <span name> — <attributes>

### Correlation ID propagation
- Inbound: <header accepted?>
- Outbound: <header forwarded?>
- Logs: <field included?>

### Anti-patterns detected
- <file:line> — <logging PII / missing correlation / unbounded cardinality>
```

---

## How to verify

- [ ] Logs structured (JSON, not free-form)?
- [ ] Correlation ID on every log line?
- [ ] No secrets in logs (passwords, tokens, API keys)?
- [ ] Metrics cardinality bounded (no user_id labels)?
- [ ] RED metrics for services (Rate, Errors, Duration)?
- [ ] Traces propagate W3C Trace Context?
- [ ] Log levels appropriate (DEBUG/INFO/WARN/ERROR)?

## Guardrails

- **Never log secrets**: passwords, tokens, full credit card, API keys
- **Never create high-cardinality metrics**: user_id label → memory explosion
- **Structured logs only**: JSON, not free-form strings with `printf`
- **Correlation ID mandatory**: every log line must carry it for traceability
- **Don't log every function**: debug noise drowns signal; log business events

---

## When triggered

- FAIRE step when adding server-side code
- New endpoint / background job / integration
- Task mentions logging / metrics / tracing / observability
