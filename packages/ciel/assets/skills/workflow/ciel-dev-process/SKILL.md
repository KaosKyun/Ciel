---
name: ciel-dev-process
description: Ciel development & release workflow — commit conventions, CI/CD pipeline, release-please automation, and downstream update process. AUTO-LOAD when working ON the Ciel project itself (hooks/, skills/, packages/ciel/, scripts/). Never edit VERSION or manifest files manually.
paths:
  - "hooks/**"
  - "skills/**"
  - "packages/ciel/**"
  - "scripts/**"
  - ".github/workflows/**"
  - ".github/release-please-config.json"
  - ".github/.release-please-manifest.json"
  - ".claude/agents/**"
  - ".claude/skills/**"
  - ".claude/rules/**"
  - "ciel-overlay.md"
---

# Ciel Development & Release Process

## Core principle

**Never manually bump VERSION, tag, or create a release.** Release Please does all of it. Manual intervention puts the manifest out of sync and breaks future automation.

---

## Development flow

```
Feature / Bug
  → Checkout main, pull latest
  → Create feature branch
  → Implement (follow Ciel 17-step pipeline)
  → Conventional commits: feat(x): / fix(x): / refactor(x): / chore:
  → Push → Open PR
  → CI validates (ShellCheck + 108 tests)
  → Merge PR
  → Release Please opens Release PR (auto)
  → Merge Release PR → auto: tag + GitHub Release + npm publish
```

## Commit conventions

| Prefix | Bump | Example |
|--------|------|---------|
| `feat:` | Minor (6.13.0 → 6.14.0) | `feat(hooks): add dispatch gate enforcement` |
| `fix:` | Patch (6.13.0 → 6.13.1) | `fix(installer): curl-mode 404 on hooks` |
| `feat!:` / `fix!:` | Major (6.13.0 → 7.0.0) | Breaking change |
| `refactor:` | No bump | `refactor(claude.md): optimize template` |
| `chore:` | No bump | `chore: bump version to X.Y.Z` |
| `docs:` | No bump | `docs: update README` |

---

## Files NEVER edit manually

| File | Managed by |
|------|-----------|
| `VERSION` | Release Please |
| `scripts/install.sh` → `CIEL_VERSION=` line | Release Please |
| `.github/.release-please-manifest.json` | Release Please |
| `packages/ciel/package.json` → `version` | Release Please |
| `.claude-plugin/plugin.json` → `version` | Release Please |
| `.claude-plugin/marketplace.json` → `version` | Release Please |

---

## After editing source files

```bash
# Sync hooks & CLAUDE.md to distribution copies
cp hooks/pre-tool-write.sh.claude/hooks/
cp hooks/user-prompt-submit.sh.claude/hooks/
cp CLAUDE.md packages/ciel/assets/CLAUDE.md
cp hooks/*.sh packages/ciel/assets/.claude/hooks/

# Test
cd packages/ciel && npm test
```

## CI/CD pipeline

| Workflow | Trigger | Action |
|----------|---------|--------|
| `ci.yml` | Push/PR | ShellCheck + 108 tests |
| `release-please.yml` | Push to main | Release PR → on merge: tag, release, npm publish dispatch |
| `publish-npm.yml` | Dispatch | `npm publish @neikyun/ciel` via OIDC |
| `test-hooks.yml` | Push/PR | Hook regex validation |

## Downstream update (Neiyomi)

```bash
cd /path/to/Neiyomi
bash /path/to/ciel/scripts/install.sh --update -y
```
