---
name: changelog-updater
description: Appends a versioned entry to CHANGELOG.md following Keep-a-Changelog format, with Added/Changed/Fixed/Removed sections and fix/revert ratio metric when available. Auto-triggered by version bumps or when /ciel-improve adopts new skill variants.
allowed-tools: Read, Bash
---

# changelog-updater — Structured version history

Keeps `CHANGELOG.md` up to date with a consistent format. Metric-driven: fix/revert ratio is the primary quality signal.

---

## Inputs

- **version**: new version number (semver)
- **date**: release date (YYYY-MM-DD)
- **changes**: structured changes — added / changed / fixed / removed / security
- **metric** (optional): fix/revert ratio measured since last release

---

## Process

### 1. Read current CHANGELOG.md

Confirm format. If the file follows Keep-a-Changelog structure, preserve it. If not, migrate to that structure.

### 2. Compose new entry

Template:

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
- Eval scores: <skill>: <baseline> → <winner>
```

Omit sections that have no entries.

### 3. Insert at top (most recent first)

After any header/preamble, before previous version entries.

### 4. Preserve previous entries

Never rewrite old entries — append only.

---

## Output format

```
## Proposed CHANGELOG.md update

### New entry
<block above>

### Diff
--- BEFORE
<first 10 lines of current changelog>
--- AFTER
<first 15 lines with new entry prepended>

Approve and write? [y/n/edit]
```

---

## Guardrails

- **Never rewrite old entries**: changelog is historical record, additive only
- **Metrics field mandatory if available**: empty metrics section = no data collected (honest)
- **Link to PRs/issues**: each entry references `#N` where possible
- **Breaking changes prominent**: mark with `!` or separate "BREAKING CHANGES" section
- **Date format**: ISO 8601 (YYYY-MM-DD)

---

## When triggered

- Version bump (SHA change in `.version`)
- After `/ciel-improve` adopts new skill variants
- User request: "update changelog" / "release notes"
- CI/CD pre-release step
