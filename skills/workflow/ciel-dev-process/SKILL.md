---
name: ciel-dev-process
description: Ciel development & release workflow — commit conventions, CI/CD pipeline, release-please automation, and downstream update process.
---

# Ciel Development & Release Process

## What this covers

How to develop features on Ciel and how releases are automated via CI/CD. Load this skill when working ON Ciel itself (not on projects using Ciel).

## Core principle

**Never manually bump VERSION, tag, or create a release.** Release Please does all of it. Manual intervention puts the manifest out of sync and breaks future automation.

---

## Development flow

```
Feature request / Bug
  → Checkout main, pull latest
  → Create feature branch
  → Implement (follow Ciel pipeline: 17 steps)
  → Conventional commits: feat(x): / fix(x): / refactor(x): / chore:
  → Push branch → Open PR
  → CI validates (lint + test)
  → Merge PR to main
  → Release Please opens Release PR (auto)
  → Merge Release PR (auto: tag + release + npm publish)
```

### Commit conventions

| Prefix | When | Version bump |
|--------|------|-------------|
| `feat:` | New feature | Minor (6.13.0 → 6.14.0) |
| `fix:` | Bug fix | Patch (6.13.0 → 6.13.1) |
| `feat!:` or `fix!:` | Breaking change | Major (6.13.0 → 7.0.0) |
| `refactor:` | Code change, no behavior | No bump |
| `chore:` | Version bump, sync, CI | No bump |
| `docs:` | Documentation only | No bump |

Only `feat:` and `fix:` trigger releases. Everything else is no-bump.

---

## CI/CD pipeline

| Workflow | Trigger | What it does |
|----------|---------|-------------|
| `ci.yml` | Push/PR to main | Lint hooks (ShellCheck), test suite (108 tests) |
| `release-please.yml` | Push to main | Opens Release PR. On merge → bumps VERSION, updates install.sh, creates git tag, creates GitHub Release, dispatches npm publish |
| `publish-npm.yml` | Dispatch from release-please | `npm publish` to `@neikyun/ciel` via OIDC |
| `test-hooks.yml` | Push/PR | Validates hook regex patterns against test vectors |

### Release Please detail

1. You push a `feat:` or `fix:` commit to main
2. Release Please opens a PR titled "chore(main): release 6.14.0"
3. The PR contains: VERSION bump, install.sh version update, package.json version bump, CHANGELOG entry
4. You **review and merge** the PR
5. Release Please: creates tag `v6.14.0`, creates GitHub Release with changelog, pushes the version commits back to main
6. Then: `sync-version` job commits the distribution files (`.claude/hooks/`, `assets/`)
7. Then: `publish-npm` dispatches → `@neikyun/ciel` updated on npm

### Manifest files (do NOT edit manually)

- `.github/.release-please-manifest.json` — current version (auto-managed)
- `.github/release-please-config.json` — extra files to bump
- `scripts/install.sh` — `CIEL_VERSION` auto-updated by release-please

---

## Downstream projects (Neiyomi, etc.)

When a new Ciel release is out:

```
Option A (manual, current):
  cd /path/to/project
  bash /path/to/ciel/scripts/install.sh --update -y

Option B (auto, planned):
  Ciel release triggers repository_dispatch → Neiyomi workflow runs
  Neiyomi workflow calls install.sh --update → opens PR with updated files
```

---

## Files you MUST never touch manually

| File | Reason |
|------|--------|
| `VERSION` | Release Please manages it |
| `scripts/install.sh` CIEL_VERSION line | Release Please manages it |
| `.github/.release-please-manifest.json` | Release Please manages it |
| `packages/ciel/package.json` version | Release Please manages it |
| `.claude-plugin/plugin.json` version | Release Please manages it |
| `.claude-plugin/marketplace.json` version | Release Please manages it |

---

## Files you edit during development

| File | Purpose |
|------|--------|
| `CLAUDE.md` | Project instructions (also synced to assets) |
| `hooks/*.sh` | Hook source of truth |
| `packages/ciel/src/**` | Plugin/CLI source |
| `packages/ciel/test/**` | Tests |
| `skills/**/SKILL.md` | Skill definitions |
| `scripts/sync-skills.sh` | Sync script |
| `.claude/rules/*.md` | Domain rules |

After editing: sync distribution copies and run tests.
```bash
# Sync hooks & CLAUDE.md
cp hooks/*.sh .claude/hooks/
cp hooks/*.sh packages/ciel/assets/.claude/hooks/
cp CLAUDE.md packages/ciel/assets/CLAUDE.md

# Test
cd packages/ciel && npm test
```

---

## Quick reference

```bash
# Develop a feature
git checkout -b feat/my-feature
# ... implement, test ...
git add -A && git commit -m "feat(scope): description"
git push && gh pr create

# After PR merged — wait for Release Please PR, then merge it.
# Nothing else to do. Tag, release, npm publish are automatic.
```
