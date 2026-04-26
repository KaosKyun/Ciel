# Documentation Ciel v5

> **Deep-reasoning framework pour le developpement assiste par LLM.**
>
> Ciel v5 est un framework de raisonnement profond qui orchestre le pipeline de developpement sur OpenCode ET Claude Code.
> Il classifie chaque tache par profondeur (Trivial/Standard/Critical/Spike), dispatche des subagents specialises
> en isolation par fork, applique 6 quality gates, et persiste la connaissance entre sessions via .ciel/.
>
> Principe : **"Understand before generating. Verify before claiming done."**

---

## Navigation

Cette documentation suit le framework **Diataxis** :

| Besoin | Section |
|--------|---------|
| **Apprendre** | [Tutoriels](tutorials/quick-start.md) |
| **Comprendre** | [Explication](explanation/architecture.md) |
| **Realiser** | [Guides](guides/install.md) |
| **Consulter** | [Reference](reference/agents.md) |

---

## Structure du projet Ciel v5

```
Ciel/
├── .opencode/            # Configuration OpenCode
│   ├── plugins/ciel.ts   # Plugin principal (562 lignes)
│   ├── agents/           # 5 agents (ciel + 4 subagents)
│   ├── commands/         # 8 commandes slash
│   └── skills/           # 63 skills discoverables
├── .claude/              # Configuration Claude Code
│   ├── agents/           # 4 subagents avec memory/isolation/maxTurns
│   ├── hooks/            # 4 hooks shell (test-first, block, track, meta)
│   ├── settings.json     # 7 hooks configures
│   ├── rules/            # Regles path-scoped (security, testing, api)
│   └── skills/           # 63 skills discoverables
├── .ciel/                # Etat persistant (map, memory, learnings, parking)
├── CLAUDE.md             # Instructions Claude Code
├── AGENTS.md             # Workflow complet + philosophie
├── ciel-overlay.md       # Overlay projet
├── VERSION               # 5.0.0
├── skills/               # 63 skills source
├── scripts/              # Install zero-config (256 lignes .sh, 129 .ps1)
├── hooks/                # 8 hooks legacy
├── docs/                 # Documentation
├── .github/workflows/    # 7 workflows CI/CD
└── platforms/            # Build 7 platforms
```

---

## Pipeline 16 etapes

```
DOCS -> QUOI -> ASK -> AVEC QUOI -> DIVERGE -> RECHERCHE -> SECURITE
-> CODEBASE -> EVALUER -> ASK2 -> FAIRE -> ADR -> RELIRE
-> PROUVER -> MEMOIRE -> META
```

[Voir le pipeline detaille](explanation/pipeline.md)

---

## Harnesses supportees

| Harness | Mecanisme principal | Forces |
|---------|-------------------|--------|
| **OpenCode** | Plugin TypeScript | question tool, LSP, permissions, websearch |
| **Claude Code** | Hooks + auto memory | fork mode, agent teams, isolation worktree |

---

## Par ou commencer ?

| Si vous voulez... | Allez vers... |
|-------------------|---------------|
| Installer Ciel | [Guide d'installation](guides/install.md) |
| Comprendre l'architecture | [Vue d'ensemble](explanation/architecture.md) |
| Premier pas | [Tutoriel quick-start](tutorials/quick-start.md) |
| Pipeline en details | [Pipeline 16 etapes](explanation/pipeline.md) |
| Creer un skill | [Guide creation](guides/creating-skill.md) |
| Consulter les agents | [Reference agents](reference/agents.md) |

---

## References

- **Version** : 5.0.0 (voir [VERSION](../VERSION))
- **AGENTS.md** : [Workflow complet](../AGENTS.md)
- **Depot GitHub** : [github.com/KaosKyun/Ciel](https://github.com/KaosKyun/Ciel)
