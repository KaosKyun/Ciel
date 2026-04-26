# Référence des agents

> **Définitions techniques des 5 agents Ciel — modes, permissions, fichiers.**

---

## Agent primaire : ciel

| Propriété | Valeur |
|-----------|--------|
| **Fichier** | `.opencode/agents/ciel.md` |
| **Mode** | `primary` |
| **Température** | 0.2 |
| **Permissions edit** | `allow` |
| **Permissions bash** | `allow` |
| **Permissions task** | ciel-researcher, ciel-explorer, ciel-critic, ciel-improver |

**Outils disponibles** : read, write, edit, bash, glob, grep, webfetch, websearch, task

**Rôle** : Orchestrateur unique — pipeline complet QUOI → PROUVER

**Contenu** (143 lignes) :
- Règles d'exécution automatique (depth classification)
- Workflow en 8 étapes
- Auto-dispatch rules par depth
- Depth classification signals (Critical/Standard/Trivial)
- Intent routing table (13 entrées)
- Utility skills reference (13 skills)

---

## Subagent : ciel-researcher

| Propriété | Valeur |
|-----------|--------|
| **Fichier** | `.opencode/agents/ciel-researcher.md` |
| **Mode** | `subagent` |
| **Température** | 0.1 |
| **write** | false |
| **edit** | false |
| **bash** | false |
| **webfetch** | true |
| **websearch** | true |

**Rôle** : Recherche de documentation externe en contexte isolé

**Process** (waterfall) :
1. `research-web-sources` (docs officielles)
2. `research-github-issues` (en parallèle)
3. `research-forums` (uniquement si nécessaire)
4. `validate-source-credibility`
5. `synthesize-findings`

**Format de sortie** :
```
FINDINGS | ANTI-PATTERNS | PHILOSOPHY | API SURFACE | INCERTITUDES
```

**Limites** : max 2 WebFetch par étape, max 5 total

---

## Subagent : ciel-explorer

| Propriété | Valeur |
|-----------|--------|
| **Fichier** | `.opencode/agents/ciel-explorer.md` |
| **Mode** | `subagent` |
| **Température** | 0.1 |
| **write** | false |
| **edit** | false |
| **bash** | false |
| **webfetch** | false |
| **websearch** | false |

**Rôle** : Exploration du codebase à la recherche de patterns

**Process** :
1. Détection stack (React → frontend-mastery, SQL → database-mastery, etc.)
2. `pattern-fitness-check` (3 questions)
3. `flux-narrator` (data flow end-to-end)
4. Merge → rapport structuré

**Format de sortie** :
```
PATTERNS TROUVÉS | MINI REPO-MAP | DUPLICATION CHECK | FLUX | DOMAIN INSIGHTS
```

**Limites** : max 4 full-file reads, max 10 tool calls

---

## Subagent : ciel-critic

| Propriété | Valeur |
|-----------|--------|
| **Fichier** | `.opencode/agents/ciel-critic.md` |
| **Mode** | `subagent` |
| **Température** | 0.1 |
| **write** | false |
| **edit** | false |
| **bash** | true |

**Rôle** : Relecture hostile, audit, et analyse de causes racines

**3 modes** :

| Mode | Sortie | Règle |
|------|--------|-------|
| RELIRE | 3 RISQUES + checklist + verdict | Exactement 3 RISQUES |
| CRITIQUER | 7 étapes (APPRENDRE → CAPITALISER) | Tous les STRIDE présents |
| RCA | 3 hypothèses + fault type + verdict | 3 hypothèses minimum |

**Règle** : lire les fichiers modifiés AVANT tout — la description ment, le code non.

---

## Subagent : ciel-improver

| Propriété | Valeur |
|-----------|--------|
| **Fichier** | `.opencode/agents/ciel-improver.md` |
| **Mode** | `subagent` |
| **Température** | 0.1 |
| **write** | true |
| **edit** | true |
| **bash** | true |
| **webfetch** | true |
| **websearch** | true |

**Rôle** : Auto-amélioration de Ciel — analyse, évalue, propose

**4 modes** :

| Mode | Déclencheur | Processus |
|------|------------|-----------|
| IMPROVE | `/ciel-improve` | Session analysis → patch-set |
| EVAL | `/ciel-eval <skill>` | Eval harness → scoreboard |
| CREATE-SKILL | `/ciel-create-skill` | Squelette SKILL.md |
| FRESHNESS-AUDIT | `/ciel-refresh` | URLs + pins check |

**Règle absolue** : jamais de modifications autonomes — toujours des propositions pour approbation.

---

## Dispatch rules résumé

| Condition | Agent | Mode |
|-----------|-------|------|
| Tâche Standard + lib externe | researcher | — |
| Tâche Critical (toutes) | researcher + explorer | parallèle obligatoire |
| Tâche Standard + 3+ fichiers | explorer | — |
| Après FAIRE + 5+ fichiers | critic | RELIRE |
| Fichier critique (auth/security) | critic | RELIRE |
| Debug / incident | critic | RCA |
| `/ciel-improve` | improver | IMPROVE |
| `/ciel-eval <skill>` | improver | EVAL |
| `/ciel-create-skill` | improver | CREATE-SKILL |
| `/ciel-refresh` | improver | FRESHNESS-AUDIT |

---

## Voir aussi

- [Système d'agents (explication)](../explanation/agents.md)
- [Architecture générale](../explanation/architecture.md)
- [opencode.json](configuration.md) — Définition des agents dans la config
