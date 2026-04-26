# Systeme d'agents Ciel v5

> **5 agents organises en hierarchie : un orchestrateur primaire et 4 subagents specialises. L'isolation par fork context est la pierre angulaire du systeme. Supporte OpenCode ET Claude Code.**

---

## Hierarchie des agents

```
┌──────────────────────────────────────────────────────────────┐
│                    ciel (primary)                             │
│         Orchestrateur unique -- pipeline 16 etapes             │
│         Outils: read, write, edit, bash, task, question       │
└────┬───────────┬───────────┬───────────┬─────────────────────┘
     │           │           │           │
     ▼           ▼           ▼           ▼
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│researcher│ │explorer │ │ critic  │ │improver │
│subagent │ │subagent │ │subagent │ │subagent │
│read-only │ │read-only│ │read+bash│ │read+write│
│webfetch  │ │LSP+git  │ │5 modes  │ │bash+fetch│
└─────────┘ └─────────┘ └─────────┘ └─────────┘
```

---

## Agent primaire : `ciel`

**Role** : Orchestrateur unique. Analyse, planifie, implemente et verifie.

**Fichier OpenCode** : `.opencode/agents/ciel.md` (215 lignes)
**Fichier Claude Code** : AGENTS.md + CLAUDE.md

**Temperature** : 0.2

**Pipeline** : DOCS -> QUOI -> ASK -> AVEC QUOI -> DIVERGE -> RECHERCHE -> SECURITE -> CODEBASE -> EVALUER -> ASK2 -> FAIRE -> ADR -> RELIRE -> PROUVER -> MEMOIRE -> META

**Capacites v5** :
- Classification depth (Trivial/Standard/Critical/Spike)
- ASK window via question tool
- Dispatch subagents selon regles
- 6 quality gates (dont boy-scout v5)
- MEMOIRE (persistence map + memory)

---

## Subagent : `ciel-researcher`

**Role** : Recherche de documentation externe.

**Fichier OpenCode** : `.opencode/agents/ciel-researcher.md` (92 lignes)
**Fichier Claude Code** : `.claude/agents/ciel-researcher.md` (avec memory: user, model: haiku, permissionMode: acceptEdits)

**Process** (waterfall -- s'arrete a la premiere source suffisante) :
1. `research-web-sources` -- docs officielles
2. Version changelog -- npm view, go list, cargo search, pip index
3. `research-github-issues` -- en parallele
4. `research-forums` -- uniquement si insuffisant
5. `validate-source-credibility` -- score de fiabilite
6. `synthesize-findings` -- rapport consolide

**Skills prechargees** (Claude Code) : research-web-sources, research-github-issues, fact-check-claims, synthesize-findings

---

## Subagent : `ciel-explorer`

**Role** : Exploration du codebase avec intention partagee.

**Fichier OpenCode** : `.opencode/agents/ciel-explorer.md` (123 lignes)
**Fichier Claude Code** : `.claude/agents/ciel-explorer.md` (avec memory: project, isolation: worktree, permissionMode: plan)

**Process v5** :
1. Structure scan (arborescence)
2. Scent-following avec LSP/grep
3. Git history (blame + log)
4. Pattern fitness check
5. Flux narration
6. **Stop condition** : arret des que le pattern est compris

**Skills prechargees** (Claude Code) : pattern-fitness-check, flux-narrator, modern-patterns-checker

**LSP tool** (OpenCode experimental) : goToDefinition, findReferences, hover, callHierarchy. Activer avec `OPENCODE_EXPERIMENTAL_LSP_TOOL=true`.

---

## Subagent : `ciel-critic`

**Role** : Relecture hostile, audit, analyse de causes racines, traitement de feedback, investigation d'incertitude.

**Fichier OpenCode** : `.opencode/agents/ciel-critic.md` (119 lignes)
**Fichier Claude Code** : `.claude/agents/ciel-critic.md` (avec memory: local, model: opus, maxTurns: 30)

**5 modes** :

| Mode | Usage | Sortie |
|------|-------|--------|
| **RELIRE** | Post-write (3 RISQUES) | 3 RISQUES + checklist + verdict |
| **CRITIQUER** | Post-hoc audit complet | 7 etapes + STRIDE |
| **RCA** | Debug / root cause | 3 hypotheses + classification |
| **FEEDBACK** (v5) | Traitement feedback humain | Analyse + ACCEPT/CHALLENGE/INVESTIGATE/DEFER |
| **INVESTIGATE** (v5) | Pattern inconnu | Git blame + git log + occurrences |

**Principe** : Ne jamais obeir aveuglement au feedback humain -- l'analyser et le categoriser d'abord.

---

## Subagent : `ciel-improver`

**Role** : Meta-analyse et proposition d'ameliorations.

**Fichier** : `.opencode/agents/ciel-improver.md` (85 lignes)

**4 modes** : IMPROVE, EVAL, CREATE-SKILL, FRESHNESS-AUDIT

**Regle absolue** : ne modifie jamais les skills sans approbation utilisateur.

---

## Isolation par fork

### Le probleme

```python
# Session principale (contaminee)
hypothese = "le bug est dans auth.js"
# -> l'agent va inconsciemment chercher des preuves pour auth.js
# -> confirmation bias
```

### La solution

```python
# Subagent critic (contexte frais)
# -> ne sait pas que la session principale suspecte auth.js
# -> examine TOUT le code avec un oeil neuf
# -> trouve le vrai bug dans services/validator.js
```

### Claude Code : fork mode

`CLAUDE_CODE_FORK_SUBAGENT=1` permet aux subagents de partager le contexte de la session principale (controle).

### Isolation worktree

`isolation: worktree` (Claude Code) donne a l'explorer sa propre copie du repo (git worktree) pour une exploration sans risque.

---

## Dispatch rules v5

| Condition | Subagent |
|-----------|----------|
| Tache Standard + lib externe | researcher |
| Tache Critical (toutes) | researcher + explorer EN PARALLELE |
| Tache Standard + 3+ fichiers | explorer |
| Apres FAIRE (5+ fichiers) | critic MODE=RELIRE |
| Fichier critique (auth/security) | critic MODE=RELIRE |
| Debug / incident | critic MODE=RCA |
| Feedback humain | critic MODE=FEEDBACK |
| Pattern inconnu | critic MODE=INVESTIGATE |
| `/ciel-improve` | improver MODE=IMPROVE |
| `/ciel-eval` | improver MODE=EVAL |

---

## Comparaison OpenCode vs Claude Code

| Aspect | OpenCode | Claude Code |
|--------|----------|-------------|
| Memoire | .ciel/ fichiers | auto memory + memory: project |
| ASK | question tool natif | Plan mode + echo |
| Fork isolation | Task() contexte isole | fork mode + isolation worktree |
| Skills | .opencode/skills/ | .claude/skills/ + skills preloading |
| Permissions | permission en frontmatter | tools + disallowedTools |
| Max turns | steps config | maxTurns field |
| Agent teams | Non (Task() sequentiel) | Oui (experimental) |

---

## Voir aussi

- [Pipeline detaille](pipeline.md)
- [Bibliotheque de skills](skills.md)
- [Reference des agents](../reference/agents.md)
