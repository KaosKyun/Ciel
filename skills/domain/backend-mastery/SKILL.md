---
name: backend-mastery
description: Expert patterns for backend server development across Ktor, Go net/http, Node/Express, Rails, Django, FastAPI, Spring — routing, middleware, authentication, background jobs, connection pooling, error handling. Auto-activates on server framework files. Invoked in parallel with researcher agent when server-side change detected.
allowed-tools: Read, Grep, WebFetch
context: fork
agent: Explore
paths: "**/build.gradle*,**/pom.xml,**/go.mod,**/requirements.txt,**/Gemfile,**/routes/**,**/controllers/**,**/services/**,**/middleware/**"
---

# backend-mastery — Backend expert knowledge

Applied in parallel with `researcher` when server-side task detected. Contributes framework-idiomatic patterns specific to request-response / middleware / background processing.

For framework-specific cheatsheets, see `reference.md`.

---

## Inputs

```
TASK: [1-sentence description]
STACK: [Ktor | Express | Rails | Django | FastAPI | Spring | Go net/http | other]
VERSION: [exact version]
```

---

## Process

### 1. Identify framework and layer

Routes? Middleware? Services? Repositories? Jobs?

### 2. Apply framework-specific pattern checks

- **Request validation**: centralized? per-field? consistent across routes?
- **Error handling**: framework exception mapper? ad-hoc try/catch?
- **Middleware ordering**: auth before authz? logging before/after business logic?
- **Transaction boundaries**: per-request? per-operation? nested?
- **Connection pooling**: max connections? timeouts? closed on error?
- **Background jobs**: queue choice? retry strategy? idempotency?

### 3. Flag bypass signals

- Business logic in route handlers (should be in services)
- DB queries in controllers (should be behind repository)
- Raw SQL string concat (should be parameterized)
- `catch (Exception e) { }` swallowing errors
- Unclosed resources (connections, file handles, streams)

### 4. Scale considerations

For each route/handler in scope:
- Request/s under normal load?
- Latency budget?
- What breaks at 10x load?

---

## Output format

```
## BACKEND DOMAIN INSIGHTS — <framework> <version>

### Pattern recommendations
- <pattern> — <when to use> — <framework reason>

### Bypass signals detected
- <file:line> — <signal> — <idiomatic replacement>

### Middleware/transaction check
- Auth ordering: <OK | issue>
- Transaction scope: <OK | issue>
- Resource lifecycle: <OK | issue>

### Scale notes
- Current load assumption: <N req/s>
- Breakage at 10x: <what breaks first>

### CROSS-REFERENCES
- Conflicts with researcher findings: <none | list>
```

---

## Guardrails

- **Layer discipline**: business logic in services, not routes
- **Error handling policy**: uniform across codebase — pick one pattern and enforce
- **Resource closure**: every open needs a close (try-with-resources, `use`, `defer`, context managers)
- **Idempotency**: POST endpoints either idempotent-by-design or explicitly document non-idempotent

---

## When triggered

- `explorer` agent parallel dispatch when backend files detected
- Task mentions endpoint / route / handler / middleware / service / job / worker
- `paths` glob auto-activates on server framework files
