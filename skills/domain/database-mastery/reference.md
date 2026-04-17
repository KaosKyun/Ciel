# database-mastery — Reference

## PostgreSQL essentials

### Index types
- **btree**: default, for equality + range queries
- **hash**: equality only, small index, PostgreSQL 10+ durable
- **gin**: for JSONB, arrays, full-text search
- **gist**: for geometric, ranges, exclusion constraints
- **brin**: for very large tables with natural ordering (time-series)

### Query planning
```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT ... ;
```

Look for:
- `Seq Scan` on large tables → missing index
- `Index Scan` + high `Filter` rows → partial index possibility
- `Hash Join` vs `Nested Loop` — optimizer choice depends on stats
- `Sort` without index on ORDER BY → index covers sort?

### JSONB operators
- `->` returns JSONB
- `->>` returns text
- `@>` contains
- `?` key exists
- GIN index on `->'field'` or whole column

### Locking levels

| Lock | When | Blocks |
|------|------|--------|
| ACCESS SHARE | SELECT | ACCESS EXCLUSIVE |
| ROW SHARE | SELECT FOR UPDATE | none concurrent |
| ROW EXCLUSIVE | INSERT/UPDATE/DELETE | ACCESS EXCLUSIVE |
| SHARE | CREATE INDEX (non-CONCURRENTLY) | writes |
| SHARE ROW EXCLUSIVE | rare | writes |
| EXCLUSIVE | rare | all but ACCESS SHARE |
| ACCESS EXCLUSIVE | ALTER TABLE, DROP | everything |

ALTER TABLE on a large table = downtime unless you use `SET NOT NULL ... NOT VALID` + `VALIDATE CONSTRAINT` or pt-online-schema-change-alike.

### Concurrent index creation

```sql
CREATE INDEX CONCURRENTLY idx_foo ON bar(baz);
```

- No write lock, but takes longer
- Can fail partially → remove with `DROP INDEX CONCURRENTLY` and retry
- Each run logs progress in `pg_stat_progress_create_index`

### Adding a NOT NULL column safely

```sql
-- Phase 1: nullable, deploy
ALTER TABLE users ADD COLUMN last_login TIMESTAMPTZ;

-- Phase 2: backfill
UPDATE users SET last_login = NOW() WHERE last_login IS NULL;

-- Phase 3: NOT NULL
ALTER TABLE users ALTER COLUMN last_login SET NOT NULL;
```

Don't do `ADD COLUMN NOT NULL DEFAULT NOW()` on large tables — PostgreSQL < 11 rewrites entire table.

## Checking schema reality

```bash
# PostgreSQL — via psql
psql -c "\d users"

# PostgreSQL — via SQL
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'users';

# SQLite
sqlite3 db.sqlite ".schema users"

# MySQL
mysql -e "DESCRIBE users;"

# MongoDB (no fixed schema — sample docs)
db.users.findOne()
```

## Common anti-patterns

- **SELECT \*** in production code: returns everything, breaks on column add/rename
- **OFFSET pagination on deep pages**: OFFSET 100000 LIMIT 20 is O(n) — use keyset pagination
- **COUNT(\*) for pagination**: O(n); approximate or cached count
- **Implicit transactions** (autocommit): hidden surprises; be explicit
- **N+1 in ORMs**: loop loading one object's associations → `includes` / `preload` / `select_related`
- **NULL comparison with `=`**: `WHERE col = NULL` always false; use `IS NULL`
- **Date in VARCHAR**: no index ordering, no arithmetic — use TIMESTAMPTZ

## Keyset pagination (vs OFFSET)

```sql
-- OFFSET (bad for deep pages)
SELECT * FROM posts ORDER BY id DESC OFFSET 10000 LIMIT 20;

-- Keyset (O(log n))
SELECT * FROM posts WHERE id < :last_seen_id ORDER BY id DESC LIMIT 20;
```

Return `lastSeenId` in response, client sends it back.

## Redis patterns

| Need | Structure | Example |
|------|-----------|---------|
| Session | String (JSON) or Hash | `user:42:session` |
| Rate limit | String with TTL | `INCR rate:user:42` + `EXPIRE` |
| Leaderboard | Sorted Set (ZSET) | `ZADD leaderboard 100 user:42` |
| Pub/sub | Channel | `PUBLISH notify.user.42 "..."` |
| Queue | List (LPUSH/RPOP) or Stream | `RPUSH jobs "{...}"` |
| Distributed lock | `SET NX EX` | `SET lock:resource uuid NX EX 30` |

TTL always. Plan expiration, don't rely on LRU (eviction is best-effort).

Persistence: RDB (snapshots) for backup, AOF for durability. `save` config in `redis.conf`.

## MongoDB patterns

- Compound index order matters: `{userId: 1, createdAt: -1}` supports `.find({userId}).sort({createdAt: -1})` — swapping order breaks both
- `$in` on large arrays → prefer pagination of IDs
- `$regex` without anchor → full scan
- Aggregation pipeline: `$match` early, `$lookup` is expensive

Transactions: available since 4.0 (replica set) / 4.2 (sharded); use sparingly, designed for multi-doc atomicity.

## Backup verification

- Daily logical backup (pg_dump / mysqldump / mongodump)
- Weekly physical backup (pg_basebackup / xtrabackup)
- Monthly restore test: restore to staging, validate data integrity
- Point-in-time recovery if using WAL archiving

## Monitoring queries

PostgreSQL:
```sql
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY duration DESC LIMIT 10;
```

Kill long-running: `SELECT pg_cancel_backend(pid)` or `pg_terminate_backend(pid)` for forceful.

## Schema migration tools

- Flyway (JVM): versioned, checksums, migration history table
- Liquibase (JVM): XML/YAML/SQL, rollback support
- Alembic (Python): SQLAlchemy-based, autogenerate from models
- Prisma Migrate (Node): schema-first, generates SQL
- golang-migrate: language-agnostic, CLI-based
- Rails migrations: built-in, deploy-safe conventions

All: keep migrations **additive** and **idempotent**. Destructive changes via phased deploys.
