# Architecture de Ciel v5

> **Comprendre comment les couches de Ciel interagissent, sur OpenCode ET Claude Code.**

---

## Principe fondateur

Ciel est conçu autour d'un principe unique :

> **"Understand before generating. Verify before claiming done."**

Ce principe se traduit en 4 regles architecturales :

1. **Classify before act** : chaque tache est classifiee par profondeur avant toute action (Trivial/Standard/Critical/Spike)
2. **Isolate to verify** : les critiques et recherches sont faites en contextes forkes, sans biais
3. **Gate every write** : 6 quality gates protegent chaque ecriture de code
4. **Ask before assume** : utiliser le question tool pour clarifier les ambiguites avant de coder

---

## Architecture duale : OpenCode + Claude Code

Ciel v5 fonctionne sur DEUX harness, avec la meme philosophie mais des implementations differentes :

```
OpenCode                        Claude Code
══════════                      ═══════════

Plugin TypeScript (.ts)         Hooks JSON (.settings.json)
  tool.execute.before/after       PreToolUse/PostToolUse
  session.* events                SessionStart/SubagentStop
  experimental.session.compacting PreCompact
  system.transform                CLAUDE.md instructions

Question tool natural            Plan mode avec echo
  question tool dedie              interaction via terminal

LSP experimental                 Git history + Bash
  goToDefinition, findReferences   git blame/log

Fork isolation via Task()        Fork isolation + fork mode
  subagents en contexte frais      CLAUDE_CODE_FORK_SUBAGENT=1

Permissions granulaires          Hooks exit 2 bloquant
  bash patterns, doom_loop         PreToolUse avec if conditions

Memory via .ciel/ fichiers       Auto memory native
  map.json, memory.json            per-git, auto-curation
  learnings.md, parking.md
```

---

## Les 8 couches de Ciel v5

### Couche 0 : Memoire persistante (.ciel/)

Nouveau en v5. Etat persistant du systeme, charge a chaque session :

```
.ciel/
  map.json          → Carte du projet (modules, fichiers, decisions)
  memory.json       → Etat de session (auto-persiste par le plugin)
  learnings.md      → Lecons apprises (MISTAKE -> RULE)
  parking.md        → Decouvertes fortuites
  exploration.active → Flag pour mode SPIKE
  exploration-log.md → Historique des explorations
  compact-log.md    → Historique des compactions
```

### Couche 1 : Plugin OpenCode (`ciel.ts`)

Point d'entree principal. S'injecte dans le cycle de vie OpenCode :

```
shell.env              → injecte CIEL_SESSION_ID, CIEL_DEPTH, CIEL_MODE
system.transform       → workflow v5 + overlay + map + memory + spike
messages.transform     → classification depth (Trivial/Standard/Critical/Spike)
session.created        → reset etat + charge overlay
session.diff           → track fichiers + RELIRE sticky
session.idle           → force META-CRITIQUER
session.compacted      → persist memory.json automatiquement
session.deleted        → log sessions enfants (subagents)
tool.execute.before    → FAIRE gates (test-first, critique, parking)
tool.execute.after     → file tracking + RELIRE + map auto-update
```

**Fichier** : `.opencode/plugins/ciel.ts` (562 lignes)

### Couche 2 : Agents (5)

5 agents orchestrent le pipeline :

| Agent | Mode | Outils | Role |
|-------|------|--------|------|
| `ciel` | primary | tout | Orchestrateur pipeline 16 etapes |
| `ciel-researcher` | subagent | read/webfetch/websearch/bash | Recherche docs + version changelog |
| `ciel-explorer` | subagent | read/glob/grep/bash/LSP | Exploration + scent-following + git history |
| `ciel-critic` | subagent | read/bash/grep | 5 modes : RELIRE/CRITIQUER/RCA/FEEDBACK/INVESTIGATE |
| `ciel-improver` | subagent | read/write/bash/webfetch | Meta-analyse, evals, patch-sets |

**Fichiers** : `.opencode/agents/ciel-*.md` (OpenCode) + `.claude/agents/ciel-*.md` (Claude Code)

### Couche 3 : Skills (63)

63 skills en 6 categories. Decouvrables via le `skill` tool (OpenCode) ou `.claude/skills/` (Claude Code) :

```
workflow/     (26)  Pipeline v5 : QUOI, ASK, DIVERGE, EVALUER, FAIRE, ADR, RELIRE, PROUVER, SPIKE...
domain/       (11)  frontend-mastery, database-mastery, security-hardening, api-architecture...
research/     (6)   research-web-sources, research-github-issues, fact-check-claims...
utility/      (8)   commit-writer, pr-opener, issue-creator, changelog-updater...
meta/         (6)   ciel-improve, learnings-capture, skill-creator, skill-freshness-auditor...
autres        (6)   ciel, ci-watcher, pr-merger, release-publisher, cicd-pipeline-designer...
```

### Couche 4 : Hooks OpenCode (plugin) + Claude Code (settings.json)

**OpenCode** : 9 hooks via plugin events (tool.execute.before/after, session.*, compacting...)

**Claude Code** : 7 hooks via `.claude/settings.json` :
- `SessionStart` : logging de demarrage
- `PreToolUse` (x3) : test-first gate, block destructive, PR body prompt
- `PostToolUse` (x2) : file tracking + STRIDE prompt pour auth/security
- `SubagentStart` : exploration logging
- `SubagentStop` : META-CRITIQUER
- `PreCompact` : etat persiste
- `TeammateIdle` : agent teams

### Couche 5 : Regles par chemin (`.claude/rules/`)

Nouveau en v5. Les regles path-scoped pour Claude Code :

```
.claude/rules/
  security.md   → pour auth/, crypto/, token/ (STRIDE obligatoire)
  testing.md    → pour *.test.* (pyramid, DAMP, AAA)
  api.md        → pour routes/, controllers/, api/ (contract-first)
```

### Couche 6 : CI/CD (6 workflows)

6 workflows GitHub Actions valident et deploient Ciel :

```
ci.yml                  → Lint hooks + test Node.js + validate config + byte limits + agents
test-hooks.yml          → Test des hooks (OpenCode + Claude Code)
platform-validation.yml → Validation 7 platforms
skill-integrity.yml     → Validation skills (frontmatter, taille, URLs)
deploy-staging.yml      → Deploiement staging
release.yml             → Release GitHub + SBOM
```

**SLSA Level 3** : SHA-pinned actions, permissions minimales, concurrency, timeouts.

### Couche 7 : Meta (Evals)

Sous-systeme d'auto-amelioration :
- `/ciel-improve` : analyse sessions, propose patch-set
- `/ciel-eval` : execute eval sur un skill
- `/ciel-refresh` : verify URLs, pins, citations
- `learnings-capture` : extrait les lecons des corrections

---

## Pipeline 16 etapes v5

Standard/Critical suit 16 etapes :

```
DOCS -> QUOI -> ASK -> AVEC QUOI -> DIVERGE -> RECHERCHE -> SECURITE
-> CODEBASE -> EVALUER -> ASK2 -> FAIRE -> ADR -> RELIRE
-> PROUVER -> MEMOIRE -> META
```

Voir [pipeline detaille](pipeline.md) pour chaque etape.

---

## Principes architecturaux

### 1. Fork isolation

Chaque subagent est lance dans un contexte forke :
- Pas d'acces a la session principale
- Pas de biais de confirmation
- Perspective fraiche sur le code
- Sur Claude Code : fork mode (`CLAUDE_CODE_FORK_SUBAGENT=1`) partage le contexte

### 2. Depth-aware pipeline

Le pipeline s'adapte a la profondeur :

```
Trivial  → QUOI -> FAIRE -> META (3 etapes)
Standard → 16 etapes completes (avec dispatch conditionnel)
Critical → 16 etapes + STRIDE + security-regression + critic obligatoire
Spike    → QUOI -> ASK -> AVEC QUOI -> DIVERGE -> FAIRE (gates assouplies) -> META
```

### 3. Skills-first + Anti-rationalization

63 skills avec tables d'anti-rationalization pour prevenir les excuses.
Les workflow skills sont liees explicitement au pipeline v5.

### 4. Harness-native

Meme philosophie, implementation specifique a chaque harness :
- **OpenCode** : plugin TypeScript, question tool, LSP, permissions
- **Claude Code** : hooks, auto memory, fork mode, agent teams, isolation worktree

---

## Comparaison v4 vs v5

| Aspect | Ciel v4 | Ciel v5 |
|--------|---------|---------|
| Pipeline | 10 etapes | 16 etapes |
| ASK window | Non | Oui (question tool / plan mode) |
| DIVERGE | Non (alternative unique) | 2-3 approches |
| ADR | Non | Auto documentation |
| MEMOIRE | Non | .ciel/map.json persistant |
| SPIKE | Non | .ciel/exploration.active |
| Parking lot | Non | .ciel/parking.md |
| Boy-scout | Non | Gate 6 dans FAIRE |
| Claude Code | Non supporte | Hooks + agents + rules |
| Skills | 50, v4 | 63, v5, anti-rationalization |
| Install | 691+744 lignes | 256+129 lignes, zero-config |

---

## Voir aussi

- [Pipeline detaille](pipeline.md) — Les 16 etapes en detail
- [Systeme d'agents](agents.md) — Isolation et dispatch
- [Bibliotheque de skills](skills.md) — 63 competences
- [Guide d'installation](../guides/install.md) — Zero-config
