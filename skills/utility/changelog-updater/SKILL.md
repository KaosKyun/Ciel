---
name: changelog-updater
description: Appends a versioned entry to CHANGELOG.md following Keep-a-Changelog format, with Added/Changed/Fixed/Removed sections and fix/revert ratio metric when available. Auto-triggered by version bumps or when /ciel-improve adopts new skill variants.
allowed-tools: Read, Bash
---

# changelog-updater — Structured version history

## What this covers
Keeps `CHANGELOG.md` up to date with a consistent format. The changelog is the project's public-facing history — every user and contributor reads it.

## Core principle
**Changelog is append-only history.** Never rewrite old entries. Each new entry answers: "What changed since last release, and why should I care?"

## Inputs

- **version**: new version number (semver)
- **date**: release date (YYYY-MM-DD)
- **changes**: structured changes — added / changed / fixed / removed / security
- **metric** (optional): fix/revert ratio measured since last release

## Process

### 1. Read current CHANGELOG.md

Confirm format. If the file follows Keep-a-Changelog structure, preserve it. If not, migrate to that structure.

### 2. Compose new entry

```markdown
## [<version>] — <YYYY-MM-DD>

### Added
- <new feature / skill / command>

### Changed
- <modified behavior / skill rewrite>

### Fixed
- <bug fix with reference>

### Removed
- <deprecated / removed>

### Security
- <security fix (CVE-like severity)>

### Metrics
- Fix/revert ratio: <X%> (baseline v<prev>: <Y%>)
```

Omit sections that have no entries.

### 3. Insert at top (most recent first)

After any header/preamble, before previous version entries.

### 4. Preserve previous entries

Never rewrite old entries — append only.

## Common patterns

### Good changelog entry

```markdown
## [3.5.0] — 2026-04-17

### Added
- `test-strategy-vitest-playwright` skill — 2026 test pyramid (70/20/10) with decision rules per test type
- `playwright-visual-critic` skill — accessibility-first UI review using Playwright MCP

### Changed
- Skills refactored from pipeline steps to knowledge references (Phase 5 of v4.0.0 plan)
- Agent frontmatter: added `model`, `memory`, `skills` preload fields

### Fixed
- Hook `session.deleted` renamed to `session.destroy` (OpenCode 0.4 breaking change)
- Agent dispatch: removed stale `context: fork` from 3 workflow skills

### Removed
- Platform directories for Cursor, Windsurf, Codex, KiloCode, LMStudio, Ollama (unsupported)
```

### Bad changelog entry

```markdown
## update
- fixed stuff
- changed things
- added new features
```

Problems: no version, no date, no specifics, sections not following Keep-a-Changelog.

## Anti-patterns

- **Rewriting old entries** — changelog is historical record, additive only
- **Missing date** — every entry needs a `YYYY-MM-DD` date
- **Vague descriptions** — "fixed bugs" says nothing. Link to issue: "fix: prevent N+1 query in dashboard (#567)"
- **Missing breaking changes** — breaking changes must be prominent, in a separate section or with `!` marker
- **Empty sections** — omit sections with no entries, don't leave empty headers
- **Not linking to issues/PRs** — each entry should reference `#N` where possible

## How to verify

- [ ] Version follows semver? (`MAJOR.MINOR.PATCH`)
- [ ] Date is ISO 8601? (`YYYY-MM-DD`)
- [ ] Entry inserted at top (most recent first)?
- [ ] Previous entries untouched?
- [ ] Breaking changes highlighted (if any)?
- [ ] Each entry references issue/PR number (where applicable)?
- [ ] Sections follow Keep-a-Changelog names? (Added, Changed, Fixed, Removed, Security)

## When triggered

- Version bump (SHA change in `.version`)
- After `/ciel-improve` adopts new skill variants
- User request: "update changelog" / "release notes"
- CI/CD pre-release step

## References

- Keep a Changelog v1.1.0 — keepachangelog.com
- Semantic Versioning v2.0.0 — semver.org
