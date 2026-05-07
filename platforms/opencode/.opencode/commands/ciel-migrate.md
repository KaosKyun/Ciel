---
description: ---
subtask: false
---

---
description: Migrates Ciel configuration between versions — updates CLAUDE.md format, skill references, hook wiring, and platform-specific configs. Supports v5→v6 migration (pipeline change, skill taxonomy reorganization). Non-destructive: backs up before any write.
---

# /ciel-migrate — Migrate Ciel Between Versions

*Migrates project config from one Ciel version to another.*

Usage: `/ciel-migrate [--dry-run] [--from=<version>] [--to=<version>]`

- `--dry-run` — show what would change without writing
- `--from=v5` — source version (auto-detected if absent)
- `--to=v6` — target version (default: latest)

## Supported migrations

| From | To | Changes |
|------|----|---------|
| v5 | v6 | Update CLAUDE.md format (pipeline steps + depth gauge), update skill catalog in ciel/reference.md, rewire hooks if settings.json references old paths, update platform deploy templates |

## Migration process

1. Read current version from `.ciel/memory.json` `cielVersion` field
2. Detect source version from config patterns
3. Back up all files that will be modified (`.bak-<timestamp>`)
4. Apply version-specific transformations
5. Write new `.ciel/memory.json` with updated version
6. Report summary of changes

## Guardrails

- **Always backs up before writing** — restore with `mv .bak-<timestamp>/* .`
- **`--dry-run` is safe** — no files are touched
- **Unknown version → abort** — don't guess the migration path
- **One version hop at a time** — v5→v6, not v4→v6 directly
