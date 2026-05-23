---
name: performance-engineering
description: Expert in back-of-envelope sizing, profiling, N+1 detection, hot-path optimization, allocation budgets, and 100x volume thought experiments. Invoked during ÉVALUER step and before FAIRE on any code path handling significant throughput. Complements evaluer-sizer workflow skill with deeper performance patterns.
allowed-tools: Read, Grep, Bash
---

# performance-engineering — Performance patterns

For optimization work, hot paths, and scaling concerns. Works alongside `evaluer-sizer` (sizing) and `observability` (measurement).

---

## Sizing first (before coding)

- Request rate: req/s under normal load, peak load
- Latency budget: p95 target for this endpoint
- Data volume: rows per request, bytes per response
- Resource: CPU-bound, memory-bound, I/O-bound, network-bound?

Back-of-envelope numbers (approximate):
- RAM access: ~100 ns
- SSD random read: ~100 µs
- Network RTT (same DC): ~1 ms
- Network RTT (cross-continent): ~100-150 ms
- Disk seek (HDD): ~10 ms
- DB query (indexed, small): ~5-20 ms
- DB query (full scan, 1M rows): seconds

---

## N+1 query detection

Pattern: loop with a query inside.

```python
# BAD
for user in users:
    user.posts = Post.query.filter(Post.user_id == user.id).all()

# GOOD
posts_by_user = Post.query.filter(Post.user_id.in_([u.id for u in users])).all()
# group by user_id
```

Grep signal:
```bash
grep -rnE 'for .* in .*\s*\{[^}]*query|findOne|findBy' src/
```

ORM-specific:
- Rails: `includes` / `preload` / `eager_load`
- Django: `select_related` (FK) / `prefetch_related` (M2M)
- Hibernate: `@Fetch(JOIN)` or `JOIN FETCH` in JPQL
- Prisma: `include` in query
- TypeORM: `leftJoinAndSelect`

---

## Hot-path optimization

Before optimizing:
1. Profile (cpu + heap + IO) — find the actual bottleneck
2. Measure baseline p50/p95/p99
3. Set target (e.g. "p95 < 100ms")

Common wins:
- **Cache**: memoize pure function calls within request; app-level cache (Redis) for expensive cross-request
- **Batching**: N writes → 1 batch write
- **Projection**: `SELECT name, email` not `SELECT *`
- **Lazy loading**: fetch associations only when needed
- **Algorithmic**: O(n²) → O(n log n) with sorted input or hash
- **I/O parallelism**: `asyncio.gather` / `Promise.all` / `launch` concurrently
- **Connection reuse**: HTTP keep-alive, DB pool

Don't optimize:
- Without profiling
- For scenarios that haven't manifested
- At the cost of correctness or readability

---

## Allocation budgets (latency-sensitive code)

- GC pressure from short-lived allocations = unpredictable pauses
- Pool objects where reuse is safe
- Prefer primitive arrays over object collections
- Streaming vs loading all in memory (files, DB results)

---

## 100x volume thought experiment

"If traffic became 100x tomorrow, what breaks first?"

Common failure layers:
1. DB connection pool exhausted
2. DB read latency degrades (no index)
3. In-memory cache eviction storm
4. HTTP client connection limit hit
5. Thread pool queue fills
6. CPU saturation

Run through this before shipping any new hot path.

---

## Output format

```
## PERFORMANCE INSIGHTS

### Sizing
- Request rate: <baseline, peak>
- Latency budget: <p95 target>
- Resource profile: <CPU | memory | I/O | network>

### Bottleneck candidates (from code review)
- <file:line> — <concern> — <suggested optimization>

### N+1 flagged
- <file:line> — <pattern> — <fix>

### 100x volume analysis
- First to break: <layer> — <why>
- Mitigation: <approach>

### Budget met?
- Estimated p95: <X ms> vs target: <Y ms> — <PASS | FAIL>
```

---

## How to verify

- [ ] Sizing done (request rate, latency budget, data volume)?
- [ ] Profiled before optimizing (CPU + heap + IO)?
- [ ] N+1 queries checked (grep for loops with queries)?
- [ ] 100x volume thought experiment completed?
- [ ] Budget met (estimated p95 vs target)?
- [ ] No optimization without profiling?

## Guardrails

- **Profile before optimizing** — intuition is wrong more than half the time
- **Measure, don't guess** — benchmarks with real data
- **Preserve correctness** — optimization that introduces subtle bugs is worse than slow correct code
- **Revisit after 6 months** — optimization targets shift with scale

---

## When triggered

- ÉVALUER step for Critical tasks
- Hot-path code (known bottleneck endpoints)
- Task mentions performance / latency / throughput / cache / optimization
- 100x scaling review before major launch
