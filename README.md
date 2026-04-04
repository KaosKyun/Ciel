# Ciel

> *Named after the Primordial Sage from Tensura — the advisor who reasons at infinite speed before Rimuru acts.*

Universal deep-reasoning workflow plugin for LLM-assisted development. Distributed across 5 enforcement layers to eliminate the systematic failure modes of single-skill AI workflows.

## The problem it solves

| LLM default behavior | Ciel solution |
|---|---|
| Skip research ("I already know this") | `researcher` agent — mandatory, isolated context |
| Copy patterns without fitness check | `explorer` agent — 3-question fitness check on every pattern |
| Self-critique in same context = same blind spots | `critic` agent — fresh context, MAR-inspired isolation |
| "Done" = code written | `PROUVER` — staging evidence mandatory before PR |
| Process skipped for "simple" tasks | Hooks — deterministic enforcement on every file write |
| No feedback loop on process quality | `CHANGELOG` — fix/revert ratio tracked per version |

**Baseline**: 62.8% fix/revert ratio on Neiyomi with monolithic dev-reasoning skill (2026-04-04).

## Architecture

```
Layer 1 — ciel-overlay.md    Project context (stack, versions, rules) — always loaded
Layer 2 — hooks/             Deterministic enforcement — never bypassable
Layer 3 — skills/ciel/       CRÉER/CRITIQUER workflow — explicit invocation
Layer 4 — agents/            researcher + explorer + critic — isolated contexts
Layer 5 — CHANGELOG.md       Fix/revert metrics per version — closed feedback loop
```

## Install

```bash
claude plugin install github:KaosKyun/Ciel

# Create your project overlay
cp .claude/plugins/ciel/overlay-template.md ./ciel-overlay.md
# Edit ciel-overlay.md: your stack, versions, CI, critical file patterns
```

## Usage

```
/ciel <task description>
```

Ciel classifies the task depth, dispatches researcher + explorer in parallel, enforces RELIRE via critic agent, and requires staging evidence before done.

## Portability

Ciel is stack-agnostic. Project-specific config lives in `ciel-overlay.md`:

```markdown
# ciel overlay — My Project
## Stack
- Frontend: React 19.0.0
- Backend: Ktor 3.0.0
## Versions (pour RECHERCHE)
- react: 19.0.0 — https://react.dev
## CI
- Staging: https://staging.example.com
- Deploy: git push origin branch (~30s)
```

The overlay stays in your project. The plugin stays generic.

## Hooks behavior

- **`pre-write-gate.sh`** — Before any code file write: injects FLUX checkpoint reminder. Critical files (auth/, Service, Route...) get a stronger STRIDE reminder.
- **`post-write-relire.sh`** — After any code file write: injects mandatory critic dispatch instruction.

Hooks inject context — they never block writes.

## Versions & metrics

See [CHANGELOG.md](CHANGELOG.md) — each version records the observed fix/revert ratio before and after.

## Research basis

Built from:
- Audit of 675 commits (62.8% fix/revert with monolithic skill)
- [MAR — Multi-Agent Reflexion](https://arxiv.org/html/2512.20845) (degeneration of thought in single-agent critique)
- [SICA — Self-Improving Coding Agent](https://arxiv.org/html/2504.15228v2) (17→53% improvement via self-edit + metrics)
- [Reflexion](https://arxiv.org/abs/2405.06682) (self-reflection improves problem-solving, p < 0.001)
- [Process debt research](https://planally.com/why-process-debt-is-the-new-tech-debt/) (monolithic process = friction = skipping)
