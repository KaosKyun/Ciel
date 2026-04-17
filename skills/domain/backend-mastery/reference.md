# backend-mastery — Reference

## Ktor (Kotlin) patterns

- **Routing**: `routing { get("/users") { ... } }` — avoid nested conditionals in handler, delegate to service
- **Plugin order**: `install(Authentication) { ... }` before route, `install(ContentNegotiation)` early
- **Authentication**: `authenticate("jwt") { ... }` block wraps protected routes
- **Request params**: `call.parameters["id"]` vs `call.receive<RequestBody>()` — validate both
- **Call attributes**: set user from JWT claim in auth block, read in route handler via `call.principal<UserPrincipal>()`
- **Exception handling**: `install(StatusPages) { exception<MyException> { cause -> call.respond(...) } }`
- **Coroutines**: every route handler is suspend; don't block with `runBlocking`

Ktor 3.x breaking changes:
- `install(CallLogging)` renamed to `install(Koin)` structure in some places — check version changelog

## Express (Node.js) patterns

- **Route file per resource**: `/routes/users.js` exports router
- **Middleware order**: body parser → cors → auth → route → error handler
- **Async handlers**: wrap with `asyncHandler(fn)` or use Express 5 auto-await
- **Error handler**: 4-arg function `(err, req, res, next)` at the end of middleware chain
- **Validation**: `express-validator` or `zod`-schema middleware

Anti-patterns:
- `app.get('/users', async (req, res) => { try { ... } catch(e) { res.status(500).send() } })` — repeated try/catch on every route → use error middleware
- `req.query.id * 1` — never cast user input without validation

## Rails patterns

- **Thin controller, fat model** (but not too fat — extract to service objects or concerns)
- **Strong parameters**: `params.require(:user).permit(:name, :email)` always
- **Callbacks**: avoid life-cycle callbacks for cross-cutting concerns (use service objects)
- **N+1 queries**: `.includes(:comments)` for associations; enable bullet gem in dev
- **Background jobs**: Sidekiq for Redis-backed, ActiveJob for abstraction; idempotent retries

## Django patterns

- **Class-based views** for CRUD, function views for edge cases
- **Serializers** (DRF): validate + transform in one place
- **Permissions**: class-based `IsAuthenticated`, `IsAdminUser`, custom
- **Middleware**: `MIDDLEWARE` list order matters — auth before common
- **ORM**: `.select_related()` for FK, `.prefetch_related()` for M2M

## FastAPI patterns

- **Pydantic models for request/response**: type safety + auto-docs
- **Dependency injection**: `Depends(get_db)`, `Depends(get_current_user)` — composable
- **Async by default**: every route is async unless you have CPU-bound work
- **Background tasks**: `BackgroundTasks` for in-request fire-and-forget, Celery for durable

## Spring Boot patterns

- **Controller / Service / Repository layering** — strict
- **`@Transactional` boundaries**: on service methods, not repositories
- **Profiles**: `application-dev.properties`, `application-prod.properties` — don't hardcode
- **Error handling**: `@ControllerAdvice` + `@ExceptionHandler`

## Go net/http patterns

- **Routing**: `http.ServeMux` for simple, `chi` / `gorilla/mux` for advanced
- **Middleware**: chain via `func(next http.Handler) http.Handler`
- **Context propagation**: `r.Context()` — cancel on client disconnect, timeout
- **Graceful shutdown**: `srv.Shutdown(ctx)` with timeout, not `srv.Close()`
- **Error wrapping**: `fmt.Errorf("op: %w", err)` → preserves chain

## Transaction patterns

- **Per-request transaction** (Rails, Django default with ATOMIC_REQUESTS): simple, but long-held locks
- **Per-operation transaction** (default Spring, manual Ktor): explicit scope, less contention
- **Saga pattern** (distributed tx): compensating actions across services

Rule: shortest transaction that maintains invariants. Don't hold transactions across external API calls.

## Connection pooling

| Framework | Default | Key config |
|-----------|---------|------------|
| HikariCP (JVM) | 10 | maximumPoolSize, connectionTimeout, idleTimeout |
| pgx pool (Go) | 4 | MaxConns, MinConns, MaxConnIdleTime |
| psycopg / asyncpg (Python) | app-specific | max_size, min_size, timeout |

Always:
- Max pool size ≤ DB max_connections / number of app instances
- Set statement timeout (kill slow queries)
- Set idle timeout (don't keep connections forever)

## Background jobs

- **Sidekiq** (Ruby): Redis-backed, concurrent, retry with exponential backoff
- **Celery** (Python): Redis/RabbitMQ, complex routing, periodic tasks
- **BullMQ** (Node): Redis-backed, TypeScript-native
- **Faktory**, **Resque**: Ruby alternatives
- **Cloud Tasks**, **SQS**: managed, at-least-once

Idempotency: every job should be safe to run twice. Use a job_id in DB to dedupe.

## Authentication checklist

- JWT: short access token (15min) + longer refresh token (7-30 days)
- Refresh rotation: new refresh issued on every use, old one invalidated
- Session storage: signed cookies for simple, server-side sessions (Redis) for revocable
- Password hashing: bcrypt, argon2id, scrypt — NEVER SHA/MD5
- Rate limiting: per-IP on auth endpoints, per-user on data endpoints

## Scale breakage signals

- Single-threaded event loop (Node) with CPU-bound work → latency spikes at load
- Synchronous I/O in async framework (FastAPI, Ktor) → blocks other requests
- Connection pool exhausted at peak → cascading timeouts
- In-memory cache without invalidation → stale reads
- Singleton mutex held during I/O → contention
