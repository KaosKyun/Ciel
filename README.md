# Ciel v9

[![CI](https://github.com/KaosKyun/Ciel/workflows/CI/badge.svg)](https://github.com/KaosKyun/Ciel/actions/workflows/ci.yml)
[![npm](https://img.shields.io/npm/v/@neikyun/ciel?color=blue)](https://www.npmjs.com/package/@neikyun/ciel)

> *Named after the Primordial Sage from Tensura — the advisor who reasons at infinite speed before Rimuru acts.*

Deep-reasoning framework for LLM-assisted development. A **thin shell**: a small set
of hard rules and deterministic hooks that constrain an LLM coding agent to
understand before it generates and to prove a change works before claiming it done.
Dual harness (Claude Code + OpenCode), ~50 on-demand domain skills, 4 forked
subagents, cued-recall memory.

Principle: **"Understand before generating. Verify before claiming done."**

> **Versioning** — "v9" is the paradigm generation (the conceptual model). The npm
> package follows semver (the badge above); the two are different axes.

---

## The problem it solves

The point is not to *ask* the LLM to behave — it's to make good behavior the path of
least resistance, enforced by hooks the model cannot skip.

| LLM default behavior | Ciel mechanism |
|---|---|
| Skip research ("I already know this") | Dispatch gate blocks reading source until `@ciel-researcher` + `@ciel-explorer` run in a forked context |
| Code on assumptions | Hard rules auto-injected by path (`.claude/rules/`) — the reliable channel; non-negotiable |
| Self-critique in the same context = same blind spots | `@ciel-critic` in a fresh fork — RELIRE / CRITIQUER / RCA / FEEDBACK / INVESTIGATE |
| "Done" = code written | **Verification gate**: the Stop hook blocks completion until edited code has a test run with a *positive* signal observed |
| No persistence between sessions | Cued-recall memory under `.ciel/memory/` (recalled by prompt cues) |
| Process drift over time | A single canonical `src/` + a deterministic build + a consistency **doctor** gated in CI |

---

## Quick install

```bash
npm install -g @neikyun/ciel   # once, globally
cd /path/to/your/project
ciel init                       # install into the project
```

Zero-config. Auto-detects Claude Code and/or OpenCode. **Never touches `node_modules`.**

```bash
ciel check        # verify installation + version
ciel doctor       # health check (hooks, memory, rules)
ciel update       # reinstall after upgrading the binary
ciel uninstall    # remove from the project
```

---

## The model

**4 hard rules** (`CLAUDE.md`): test first (RED→GREEN→REFACTOR) · zero secrets in code ·
no placeholders · "no error in the logs" is never proof — trigger the scenario and see a
positive signal.

**Autonomous loop** (default for dev tasks; the human only steps in on a problem or an
irreversible decision):

```
Understand → RED (failing test) → GREEN → VERIFY (positive signal)
→ CRITIQUE (fork the critic if 3+ files) → iterate or ship
```

The **Stop hook blocks completion** until modified code has been verified — that guard
is what makes the autonomy safe.

**Depth** adapts rigor automatically: `Trivial` (no dispatch) · `Standard` (dispatch
researcher+explorer before writing) · `Critical` (auth/DB/security/payment → STRIDE +
mandatory critic).

---

## Knowledge: push (rules) vs pull (skills)

Two channels, two roles:

- **Rules** (`.claude/rules/*.md`, 17) — **hard constraints**, auto-injected by the
  harness on `paths:` match. The reliable channel: what must always apply lives here
  (never a secret, test first, cursor pagination, …).
- **Skills** (`Skill()`, ~50 domains) — **deep reference on demand**. Anti-patterns,
  playbooks, examples. Pulled when depth helps, not by ritual.

---

## Deterministic enforcement (hooks)

Hooks wired on 6 events (`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`,
`Stop`, `PreCompact`). They classify depth, route skills, gate dispatch, track file edits
and test runs, and block "done" without proof. A universal defer-guard prevents a global
install and a project install from double-firing.

---

## Single source of truth

One canonical `src/` feeds every target — no more hand-maintained copies that drift:

```
src/skills (93)    → .claude/skills, .opencode/skills, packages/ciel/assets/skills
src/hooks  (13)    → .claude/hooks,  packages/ciel/assets/.claude/hooks
src/rules  (17)    → .claude/rules,  packages/ciel/assets/.claude/rules
```

- `scripts/build.mjs` — deterministic, byte-faithful, mode-preserving, idempotent.
- `scripts/doctor.mjs` — gates version sync (everything == `VERSION`), src↔mirror parity
  (byte + executable bit), and stale generation labels. The committed npm assets are
  re-checked in CI with `git diff --exit-code`, so a `src/` edit that isn't rebuilt fails
  the build. See [ADR 0002](docs/adrs/0002-canonical-src-distribution.md).

---

## Dual harness

| Harness | Implementation | Strengths |
|---------|---------------|-----------|
| **Claude Code** | hooks + agents (`.claude/`) | auto memory, fork subagents, worktree isolation, deterministic hook gates |
| **OpenCode** | TypeScript plugin (`.opencode/`) | question tool, LSP, websearch, granular permissions, fork isolation via `Task()` |

Same philosophy, native implementation per harness.

---

## Agents (4 forked subagents)

| Agent | Role |
|-------|------|
| `ciel-researcher` | Official docs, anti-patterns, versions, changelogs |
| `ciel-explorer` | Codebase patterns, data-flow tracing, git history — reports facts, not judgments |
| `ciel-critic` | Hostile review before commit: 4 risks + FIX/ACCEPT/DEFER, 5 modes |
| `ciel-improver` | Self-improvement analysis (only on `/ciel-improve`, `/ciel-eval`) — never rewrites autonomously |

On Claude Code the subagents carry `memory`, `isolation: worktree`, and `maxTurns`.

---

## Skills (93)

| Category | Count | Discoverable | Examples |
|----------|-------|--------------|----------|
| domain | 52 | yes (top-level) | api-design, backend, frontend, database-design, appsec, system-design, environments, github |
| workflow | 19 | no (internal) | depth-classifier, stride-analyzer, debug-reasoning-rca, relire-critic, critiquer-auditor, memoire |
| utility | 9 | no | commit/PR/issue/changelog helpers |
| meta | 7 | no | skill-creator, freshness/variant auditors |
| research | 6 | no | research-web-sources, fact-check-claims, validate-source-credibility |

Claude Code discovers skills at the top level only; nested categories are internal
(OpenCode / reference). Some workflow skills still describe an earlier pipeline and are
slated for modernization.

---

## Self-improvement

- `/ciel-improve` — analyze recent sessions, propose a patch-set (with approval)
- `/ciel-eval` — run the binary eval dataset for a skill
- `/ciel-audit` — audit the current session for paradigm violations (health score)

---

## Research basis

- Anthropic Skills-first paradigm (Barry Zhang / Mahesh Murag)
- CriticBench 2024 — self-critique is the hardest critique mode for LLMs
- Process-debt research (planally.com)

---

## License

MIT
