---
name: database-mastery
description: Expert patterns for PostgreSQL, MySQL, Redis, MongoDB, SQLite — migrations, indexes, query planning, connection pooling, parameterized queries, schema evolution. Auto-activates on SQL files, migrations, prisma schemas, supabase folders. Invoked in parallel with researcher when DB work detected. Always verifies real schema before asserting column existence.
allowed-tools: Read, Grep, Bash
context: fork
agent: Explore
paths: "**/*.sql,**/migrations/**,**/prisma/**,**/supabase/**,**/schema.*,**/*Migration*,**/*migration*"
---

# database-mastery — Database expert knowledge

Applied in parallel with `researcher` when DB work detected. Contributes schema/query patterns + safety checks specific to transactional systems.

For engine-specific cheatsheets, see `reference.md`.

---

## Inputs

```
TASK: [1-sentence description]
DB: [PostgreSQL | MySQL | Redis | MongoDB | SQLite | other]
VERSION: [exact version]
```

---

## Process

### 1. Identify DB engine + version

From `docker-compose.yml`, `ciel-overlay.md`, environment files.

### 2. Verify schema reality (never assume column existence)

For any column reference:
- Read the migration file that created it
- OR query `information_schema` / `pg_attribute` / `sqlite_master`
- Never trust memory for column names

### 3. Apply engine-specific checks

- **PostgreSQL**: index types (btree/hash/gin/gist/brin), DML concurrency (CONCURRENTLY), JSON operators
- **MySQL**: InnoDB vs MyISAM, charset (utf8mb4), strict_mode
- **Redis**: data structure choice, TTL strategy, persistence (RDB/AOF)
- **MongoDB**: index compound order, aggregation pipeline stages, sharding key

### 4. Migration safety

- **Backward compat**: new column NOT NULL without DEFAULT breaks in-flight writes
- **Index addition**: PostgreSQL `CREATE INDEX CONCURRENTLY`, MySQL pt-online-schema-change
- **Column type change**: often full table rewrite — test on prod-scale data copy
- **Drop column**: deploy code ignoring it first, drop column later
- **Rename**: avoid in production; add new + dual-write + migrate + drop old

### 5. Query patterns

- Parameterized queries ALWAYS (never string concat)
- `EXPLAIN ANALYZE` for any non-trivial query before shipping
- N+1 detection: grep for loops containing queries
- Transaction scope as narrow as possible

---

## Output format

```
## DATABASE DOMAIN INSIGHTS — <engine> <version>

### Schema verification
- Table: <name> — verified from <migration:line | pg_attribute query>
- Columns: <list with types, verified>

### Query patterns
- <query shape> — <index used? full scan?>
- <N+1 risk flagged or none>

### Migration safety
- <migration file> — <safe | risky + why>
- Rollback plan: <explicit | implicit via version control>

### Connection / transaction
- Pool size: <N> — <sufficient for load?>
- Tx scope: <OK | too wide | nested>

### CROSS-REFERENCES
- Conflicts with researcher findings: <none | list>
```

---

## Guardrails

- **Never assume a column exists** — verify from migration or `pg_attribute` / equivalent
- **SQL must be parameterized** — no string concat with user input, ever
- **Migration review mandatory** for schema changes — backward compat, locking, size
- **Index before production scale** — adding index on 100M rows takes minutes to hours; plan it
- **Backup verification** — "we have backups" ≠ tested restore. If relevant, ask when last restore test was.

---

## When triggered

- `explorer` agent parallel dispatch when DB files detected
- Task mentions query / migration / schema / index / table
- `paths` glob auto-activates on SQL / migrations / prisma / supabase files
