---
name: database-mastery
description: Expert patterns for PostgreSQL, MySQL, Redis, MongoDB, SQLite — migrations, indexes, query planning, connection pooling, parameterized queries, schema evolution. Auto-activates on SQL files, migrations, prisma schemas. Always verifies real schema before asserting column existence.
allowed-tools: Read, Grep, Bash
paths: "**/*.sql,**/migrations/**,**/prisma/**,**/supabase/**,**/schema.*,**/*Migration*,**/*migration*"
---

# database-mastery — Database expert knowledge

## What this covers
Schema/query patterns + safety checks specific to transactional systems. Ensures migrations are safe, queries are efficient, and schema claims are verified.

## Core principle
**Never assume a column exists.** Verify from migration or `pg_attribute`. Never trust memory for schema details.

## Key patterns (2026)

### PostgreSQL 17 — Measure before optimizing

```sql
-- ❌ BEFORE: Blind optimization
CREATE INDEX idx_orders_customer ON orders(customer_id);

-- ✅ AFTER: Measure first
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE customer_id = 42;
-- Shows: Seq Scan on orders (cost=0..1520 rows=50)
-- THEN create index, re-measure, confirm improvement
```

- Always `EXPLAIN (ANALYZE, BUFFERS)` before optimizing
- Create extended statistics for correlated columns: `CREATE STATISTICS (dependencies)`
- Use `COPY` for bulk loads, drop indexes first, recreate after
- Connection poolers (PgBouncer) — PG spawns OS process per connection

### MongoDB 8 — Aggregation pipeline over multiple finds

```js
// ❌ BEFORE: Multiple finds
const users = await db.users.find({ status: 'active' });
for (const user of users) {
  user.orders = await db.orders.find({ userId: user._id });
}

// ✅ AFTER: Single aggregation pipeline
const result = await db.users.aggregate([
  { $match: { status: 'active' } },
  { $lookup: { from: 'orders', localField: '_id', foreignField: 'userId', as: 'orders' } }
]);
```

## Migration safety checklist

- **Backward compat**: new column NOT NULL without DEFAULT breaks in-flight writes
- **Index addition**: PostgreSQL `CREATE INDEX CONCURRENTLY`, MySQL `pt-online-schema-change`
- **Column type change**: often full table rewrite — test on prod-scale data copy
- **Drop column**: deploy code ignoring it first, drop column later
- **Rename**: avoid in production; add new + dual-write + migrate + drop old

## Query patterns

- Parameterized queries ALWAYS (never string concat)
- `EXPLAIN ANALYZE` for any non-trivial query before shipping
- N+1 detection: grep for loops containing queries
- Transaction scope as narrow as possible

## Anti-patterns

- **N+1 queries** — loop with query inside → batch or JOIN
- **Missing indexes on foreign keys** — check `pg_indexes` for FK columns
- **Stale statistics after bulk load** — run `ANALYZE` if `pg_stat_user_tables.last_analyze` is old
- **String concatenation in SQL** — always parameterized
- **Assuming column exists** — verify from migration or `pg_attribute`
- **Wide SELECT *** — select only needed columns

## How to verify

- [ ] Schema verified from migration files or `pg_attribute`?
- [ ] Queries parameterized (no string concat)?
- [ ] `EXPLAIN ANALYZE` run for non-trivial queries?
- [ ] N+1 checked (grep for loops containing queries)?
- [ ] Migration backward-compatible (no NOT NULL without DEFAULT)?
- [ ] Index addition uses CONCURRENTLY (PostgreSQL)?
- [ ] Connection pool sized appropriately?

## When triggered

- `explorer` agent parallel dispatch when DB files detected
- Task mentions query / migration / schema / index / table
- `paths` glob auto-activates on SQL / migrations / prisma / supabase files

## References

- PostgreSQL 17 performance — https://www.postgresql.org/docs/17/performance-tips.html
- MongoDB 8 aggregation — https://www.mongodb.com/docs/manual/aggregation/
