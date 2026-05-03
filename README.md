# Ciel v6

[![CI](https://github.com/KaosKyun/Ciel/workflows/CI/badge.svg)](https://github.com/KaosKyun/Ciel/actions/workflows/ci.yml)
[![Release](https://github.com/KaosKyun/Ciel/workflows/Release/badge.svg)](https://github.com/KaosKyun/Ciel/actions/workflows/release.yml)
[![npm](https://img.shields.io/npm/v/@neikyun/ciel?color=blue)](https://www.npmjs.com/package/@neikyun/ciel)

> *Named after the Primordial Sage from Tensura — the advisor who reasons at infinite speed before Rimuru acts.*

Deep-reasoning framework for LLM-assisted development. Pipeline 16 etapes, dual harness (OpenCode + Claude Code), 63 skills, 5 agents, anti-rationalization tables, memory persistante.

Principle: **"Understand before generating. Verify before claiming done."**

---

## The problem it solves

| LLM default behavior | Ciel v6 solution |
|---|---|
| Skip research ("I already know this") | `research/` skills + `@ciel-researcher` in forked context |
| Code on assumptions ("I'll fix it later") | **ASK window**: question tool (OpenCode) / plan mode (Claude Code) |
| First approach bias ("this should work") | **DIVERGE**: 2-3 approaches before choosing |
| No persistence between sessions | **MEMOIRE**: .ciel/map.json, .ciel/learnings.md persistants |
| Self-critique in same context = same blind spots | `@ciel-critic` in fresh fork — 5 modes (RELIRE/CRITIQUER/RCA/FEEDBACK/INVESTIGATE) |
| "Done" = code written | 6 quality gates + PROUVER (AVANT/APRES evidence) |
| Skip process for "simple" tasks | Depth-aware pipeline (Trivial/Standard/Critical/Spike) |
| Prototype code becomes permanent | **SPIKE mode**: explication avec gates assouplies, FIXME obligatoire |
| No feedback loop | META-CRITIQUER (10 items) + .ciel/learnings.md |
| Excuses to skip steps | **Anti-rationalization tables** dans 7 skills |

---

## Quick install

### NPM (recommended)

```bash
npm install -D @neikyun/ciel
npx ciel init
```

### Curl

```bash
cd /path/to/your/project
curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh | bash
```

Zero-config. Auto-detecte OpenCode ou Claude Code. Idempotent.

---

## Pipeline 16 etapes

```
DOCS -> QUOI -> ASK -> AVEC QUOI -> DIVERGE -> RECHERCHE -> SECURITE
-> CODEBASE -> EVALUER -> ASK2 -> FAIRE -> ADR -> RELIRE
-> PROUVER -> MEMOIRE -> META
```

Chaque etape s'adapte a la profondeur (Trivial/Standard/Critical/Spike).

---

## Dual harness

| Harness | Implementation | Forces |
|---------|---------------|--------|
| **OpenCode** | Plugin TypeScript (.opencode/) | question tool, LSP experimental, websearch, permissions granulaires, fork isolation via Task() |
| **Claude Code** | Hooks + agents (.claude/) | auto memory, fork mode, agent teams, isolation worktree, 7 hooks dont prompt type |

Meme philosophie, implementation native a chaque harness.

---

## Architecture

```
ciel/
├── .opencode/              # OpenCode harness
│   ├── plugins/ciel.ts     # Plugin principal (562 lignes)
│   ├── agents/             # 5 agents (ciel + 4 subagents)
│   ├── commands/           # 8 commandes slash
│   └── skills/             # 63 skills discoverables
├── .claude/                # Claude Code harness
│   ├── agents/             # 4 subagents avec memory/isolation/maxTurns
│   ├── hooks/              # 4 hooks shell (test-first, block-destructive, track-file, meta-critiquer)
│   ├── settings.json       # 7 hooks configures (PreToolUse, PostToolUse, SubagentStart/Stop, etc.)
│   ├── rules/              # 3 path-scoped (security, testing, api)
│   └── skills/             # 63 skills discoverables
├── .ciel/                  # Etat persistant (map.json, memory.json, learnings.md, parking.md)
├── skills/                 # 63 skills source (workflow 26, domain 11, research 6, utility 8, meta 6, autres 6)
│   ├── workflow/           # Pipeline v5: quoi-framer, ask-window, diverge, evaluer-sizer, faire-gatekeeper, adr-auto, relire-critic, meta-critiquer, spike-mode...
│   ├── domain/             # frontend-mastery, backend-mastery, database-mastery, security-hardening...
│   ├── research/           # research-web-sources, research-github-issues, fact-check-claims...
│   ├── utility/            # commit-writer, pr-opener, issue-creator, changelog-updater...
│   └── meta/               # ciel-improve, learnings-capture, skill-creator, skill-freshness-auditor...
├── agents/                 # 5 agents OpenCode
├── commands/               # 8 commandes slash
├── docs/                   # Documentation (Diataxis)
├── scripts/                # Install zero-config (256 lignes .sh, 129 .ps1)
├── evals/                  # Self-improvement harness
├── CLAUDE.md               # Instructions Claude Code
├── AGENTS.md               # Workflow complet
└── platforms/              # Build multi-platforms
```

---

## 5 Agents

| Agent | Mode | Role | Particularites v6 |
|-------|------|------|-------------------|
| `ciel` | primary | Orchestrateur pipeline 16 etapes | ASK window, intentions partagees, depth gauge SPIKE |
| `ciel-researcher` | subagent | Recherche docs + version changelog | Waterfall, anti-hallucination, skills prechargees |
| `ciel-explorer` | subagent | Exploration + scent-following + git history | LSP tool, stop condition, intentions partagees |
| `ciel-critic` | subagent | 5 modes: RELIRE/CRITIQUER/RCA/FEEDBACK/INVESTIGATE | Feedback processor (D2), investigation (D5) |
| `ciel-improver` | subagent | Meta-analyse, evals, patch-sets | Ne modifie jamais sans approbation |

**Sur Claude Code** : les subagents ont `memory: user/project/local`, `isolation: worktree` (explorer), `permissionMode`, `maxTurns`, `skills` preloading.

---

## 63 Skills

Les skills sont organisees en 6 categories. Les workflow skills sont liees explicitement au pipeline v6 et incluent des tables d'anti-rationalization.

| Categorie | Nb | Exemples |
|-----------|----|----------|
| workflow | 26 | quoi-framer, ask-window, diverge, evaluer-sizer, faire-gatekeeper, adr-auto, memoire, spike-mode, relire-critic, meta-critiquer |
| domain | 11 | frontend-mastery, backend-mastery, database-mastery, security-hardening |
| research | 6 | research-web-sources, research-github-issues, fact-check-claims |
| utility | 8 | commit-writer, pr-opener, issue-creator, changelog-updater |
| meta | 6 | ciel-improve, learnings-capture, skill-creator |
| autres | 6 | ciel, ci-watcher, pr-merger, release-publisher |

---

## New in v6

- **Harness enrichment**: agents OpenCode (48→107 lignes) et Claude Code (CLAUDE.md 7→90+ lignes) avec pipeline complet, Top 10 Guards, subagent dispatch rules
- **NPM distribution**: `npm install -D @neikyun/ciel` + `npx ciel init`
- **Version aligned**: 6.0.0 across GitHub, NPM, VERSION file
- **Dependency pinned**: `@opencode-ai/plugin` exact version, no caret
- **Tests renforces**: 31 tests (15→31, +16 behavioral)
- **ciel-plan.md**: nettoye (merge dans l'agent primaire)

## Legacy v5 features

- **Pipeline 16 etapes** (vs 10): DOCS, ASK, DIVERGE, ADR, MEMOIRE, SPIKE
- **ASK window**: question tool (OpenCode) / plan mode (Claude Code) — ne codez pas sur des assumptions
- **DIVERGE**: 2-3 approches radicalement differentes avant d'en choisir une
- **ADR auto**: documentation des decisions architecturales dans docs/adrs/
- **MEMOIRE**: .ciel/map.json + .ciel/learnings.md persistants entre sessions
- **SPIKE mode**: .ciel/exploration.active pour prototypes, gates assouplies
- **Boy-scout rule**: gate 6 dans FAIRE
- **Parking lot**: .ciel/parking.md pour decouvertes fortuites
- **Claude Code support complet**: subagents, hooks, rules, fork mode, agent teams
- **Anti-rationalization tables**: 7 skills avec tables d'excuses
- **Install zero-config**: 256 lignes (vs 691), 129 lignes PS1 (vs 744)

---

## Self-improvement

Ciel peut analyser ses propres performances et proposer des ameliorations :
- `/ciel-improve` : analyse sessions, propose patch-set
- `/ciel-refresh` : verify URLs, pins, citations
- `/ciel-eval` : execute eval sur un skill

---

## Research basis

- Anthropic Skills-first paradigm (Barry Zhang / Mahesh Murag)
- CriticBench 2024 : self-critique is the hardest critique mode for LLMs
- Process debt research (planally.com)

---

## License

MIT
