# ADR 0002 — Single canonical `src/` as the distribution source of truth

Status: Accepted (2026-05-26) · Branch: `levier-a-single-source-build`

## Context

Ciel artifacts (skills, hooks, rules) were duplicated across 5–10 directories
that had silently drifted (skill counts 48 / 85 / 99 / 100 across mirrors; the
`ciel` skill held 5 distinct md5s; the npm build read skills from a **gitignored**
directory, making `git clone && npm run build` non-reproducible). Two installers
disagreed on layout:

- `ciel init` (`claude.ts`) ships `assets/.claude/skills/` — flat domain, ~52.
- `npm install` (`postinstall.cjs`) ships `assets/skills/` — categorized, ~100.

Empirical fact (verified this session): **Claude Code discovers skills at the top
level only** — nested `workflow/`, `meta/` dirs are NOT exposed to `Skill()`.
Nesting is therefore a deliberate "internal/hidden" marker, not an accident.

## Decision

1. **`src/` is the only hand-edited source.** `src/skills`, `src/hooks`, `src/rules`.
   Top-level dirs = user-facing (discoverable); `workflow/ meta/ utility/ research/`
   nested = internal (hidden from Claude `Skill()`, available to OpenCode/reference).
2. **One build (`scripts/build.mjs`) generates every target**, including the
   committed npm assets (`packages/ciel/assets/…`). `scripts/mirrors.mjs` is the
   single source of the build topology, imported by build + doctor.
3. **`copy-assets.cjs` stops owning skills/hooks/rules** (build.mjs owns them).
   It keeps agents, commands, the `ciel` skill, the OpenCode plugin, CLAUDE.md.
4. **The committed assets are the gated artifact.** CI runs `build.mjs` then
   `git diff --exit-code -- packages/ciel/assets` — a real drift gate on the
   content actually published to users. (Gitignored local mirrors `.claude/*`,
   `.opencode/*` can't be git-diff-gated; their honest gate is `build.test.mjs`.)
5. **One install layout.** Both installers ship the same `src`-derived tree.

## Consequences

- Editing a skill = edit `src/`, run `npm run build:src`, commit. The doctor +
  CI `git diff` fail if assets weren't regenerated → drift becomes impossible.
- Version is single-sourced to `VERSION` (ADR-adjacent fix); banner truthful.
- **Phased rollout** (each slice tested, to avoid publish-path regressions):
  - Slice A (this ADR's first commit): hooks + rules → committed assets + gate.
    Content-neutral (assets already byte-equal to src).
  - Slice B (next): skills — unify the two installers onto one layout, with an
    `ciel init` integration test asserting skills land correctly. Higher risk
    (touches the user-facing install), so isolated and tested on its own.
- `.version` (legacy `5.1.0`) and the dual `assets/skills` vs `assets/.claude/skills`
  trees are removed as part of slice B.

## Alternatives rejected

- **Symlinks / git submodule** for sharing source — npm pack dereferences
  symlinks, Windows needs elevation, git noise; submodule adds checkout friction.
  A deterministic copy build is simpler and cross-platform (per research).
- **Keep two installers** — guarantees perpetual layout drift; the whole point is
  one source, one layout.
