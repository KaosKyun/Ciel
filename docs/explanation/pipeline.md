# Pipeline Ciel v5 : Les 16 etapes

> **Le pipeline est le c|ur de Ciel. Chaque tache, quelle que soit sa profondeur, traverse un sous-ensemble de ces 16 etapes.**

---

## Vue d'ensemble

```
┌────────────────────────────────────────────────────────────────────────────┐
│                     PIPELINE CIEL v5 (16 etapes)                           │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  1. DOCS        Lire README, ADRs, tickets, overlay, .ciel/map.json        │
│       ↓                                                                     │
│  2. QUOI        Goal + NOT-X + intentions partagees + DoD                  │
│       ↓                                                                     │
│  3. ASK         Utiliser le question tool (OpenCode) ou plan mode (Claude) │
│       ↓                                                                     │
│  4. AVEC QUOI   Verifier les versions installees (package.json, etc.)      │
│       ↓                                                                     │
│  5. DIVERGE     Explorer 2-3 approches radicalement differentes            │
│       ↓                                                                     │
│  6. RECHERCHE   Dispatch @ciel-researcher (docs + anti-patterns)           │
│       ↓                                                                     │
│  7. SECURITE    STRIDE + killer checklist (CRITICAL only)                  │
│       ↓                                                                     │
│  8. CODEBASE    Dispatch @ciel-explorer (LSP + scent-following + git)      │
│       ↓                                                                     │
│  9. EVALUER     Sizing + pre-mortem + divcompare + counterfactual           │
│       ↓                                                                     │
│ 10. ASK2        Questions sur le plan avant d'implementation               │
│       ↓                                                                     │
│ 11. FAIRE       Test-first (RED) + 6 quality gates (boy-scout v5)         │
│       ↓                                                                     │
│ 12. ADR         Documenter les decisions architecturales (docs/adrs/)      │
│       ↓                                                                     │
│ 13. RELIRE      Dispatch @ciel-critic MODE=RELIRE (3 RISQUES)              │
│       ↓                                                                     │
│ 14. PROUVER     AVANT/APRES evidence + CI gate + PR body                   │
│       ↓                                                                     │
│ 15. MEMOIRE     Sauvegarder .ciel/map.json + .ciel/learnings.md            │
│       ↓                                                                     │
│ 16. META        30s post-task reflection (10 items)                        │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Detail des etapes

### Etape 1 : DOCS
**Objectif** : Comprendre le projet avant de modifier quoi que ce soit.
**Actions** : Lire README.md, ADRs (docs/adrs/), tickets lies, overlay (ciel-overlay.md), carte du projet (.ciel/map.json), instructions (AGENTS.md / CLAUDE.md).
**Output** : Contexte du projet charge.

### Etape 2 : QUOI
**Objectif** : Definir precisement ce qui doit etre fait -- et ce qui ne doit PAS etre fait.
**Format** :
```
Goal: <1 phrase>
NOT-X: <contrainte explicite>
Intentions partagees: <ce qu'on cherche (pas la solution)>
Definition of Done: <criteres mesurables>
```

### Etape 3 : ASK (nouveau v5)
**Objectif** : Clarifier les ambiguites avant de coder.
**OpenCode** : Utiliser le `question` tool natif avec options + reponse personnalisee.
**Claude Code** : Utiliser le plan mode (Tab) avec echo interactif.
**Ne PAS** : Coder sur des assumptions non verifiees.

### Etape 4 : AVEC QUOI
**Objectif** : Lire les versions reelles -- ne jamais faire confiance a la memoire.
**Sources** : package.json, go.mod, Cargo.toml, pyproject.toml, etc.

### Etape 5 : DIVERGE (nouveau v5)
**Objectif** : Explorer 2-3 approches radicalement differentes avant d'en choisir une.
**Pourquoi** : La premiere approche qui vient a l'esprit est rarement la meilleure.
**Output** : 2-3 approches avec trade-offs, effort, risque. Pas d'evaluation -- reportee a EVALUER.

### Etape 6 : RECHERCHE
**Objectif** : Verifier les APIs et patterns aupres de sources officielles.
**Dispatch** : `@ciel-researcher` (contexte forke).
**Contenu** : Version changelog, anti-patterns, philosophie framework, API surface verify.

### Etape 7 : SECURITE (Critical only)
**Objectif** : Analyser les risques de securite avant d'ecrire du code.
**Contenu** : STRIDE (6 categories) + killer checklist + mitigations.

### Etape 8 : CODEBASE
**Objectif** : Explorer le code existant pour comprendre les patterns et le flux.
**Dispatch** : `@ciel-explorer` avec intention partagee.
**OpenCode** : LSP tool (goToDefinition, findReferences) si active.
**Claude Code** : Git history (blame + log) + isolation worktree.

### Etape 9 : EVALUER
**Objectif** : Evaluer l'approche selectionnee.
**Contenu** : Sizing (concret, avec chiffres) + pre-mortem (2 echecs) + comparaison approches (de DIVERGE) + counterfactual.

### Etape 10 : ASK2 (nouveau v5)
**Objectif** : Questions sur le plan avant d'implementer.
**Actions** : Valider l'approche, confirmer les trade-offs, verifier les risques.

### Etape 11 : FAIRE
**Objectif** : Implementer avec 6 quality gates :
1. **Test-first (RED)** : test avant le code source
2. **Alternatives** : justifier X vs Y
3. **Idiomatique** : pattern idiomatique du framework
4. **Qualite** : complexite < 15, nesting < 4, < 50 lignes
5. **Removal** : si suppression, verifier dependants
6. **Boy-scout** : laisser le code meilleur qu'avant

**SPIKE mode** (`.ciel/exploration.active`) : gates 1 et 4 assouplies.

### Etape 12 : ADR (nouveau v5)
**Objectif** : Documenter les decisions architecturales significatives.
**Format** : `docs/adrs/NNN-titre.md` (template M. Nygard).
**Seuil** : Si la decision est non-triviale (lib, pattern, schema, perf).

### Etape 13 : RELIRE
**Objectif** : Relecture hostile par un agent forke.
**Dispatch** : `@ciel-critic MODE=RELIRE`.
**Output** : Exactement 3 RISQUES (fonctionnel, API/imports, donnees) + FIX/ACCEPT/DEFER.

### Etape 14 : PROUVER
**Objectif** : Preuves tangibles que l'implementation fonctionne.
**Gates** : CI gate (tests passent) + AVANT/APRES evidence + PR body + issue comment.

### Etape 15 : MEMOIRE (nouveau v5)
**Objectif** : Persister la connaissance pour les sessions futures.
**Fichiers** : `.ciel/map.json` (carte du projet) + `.ciel/learnings.md` (lecons) + `.ciel/memory.json` (etat).
**Principe** : Si tu as appris quelque chose, sauvegarde-le.

### Etape 16 : META
**Objectif** : 30 secondes de reflexion post-tache.
**10 items** : depth match, failure mode, user correction, branches, issues, context, dead code, map, parking, boy-scout.

---

## Adaptation par depth

| Etape | Trivial | Standard | Critical | Spike |
|-------|---------|----------|----------|-------|
| 1. DOCS | - | Oui | Oui | - |
| 2. QUOI | Oui | Oui | Oui | Oui |
| 3. ASK | - | Oui | Oui | Oui |
| 4. AVEC QUOI | - | Oui | Oui | Oui |
| 5. DIVERGE | - | Oui | Oui | Oui |
| 6. RECHERCHE | - | si lib externe | Oui | - |
| 7. SECURITE | - | - | Oui | - |
| 8. CODEBASE | - | si 3+ fichiers | Oui | si necessaire |
| 9. EVALUER | - | Oui | Oui | - |
| 10. ASK2 | - | Oui | Oui | - |
| 11. FAIRE | inline | complet | complet | gates assouplies |
| 12. ADR | - | si decision | Oui | - |
| 13. RELIRE | inline | si 5+ fichiers | OBLIGATOIRE | - |
| 14. PROUVER | - | Oui | Oui | - |
| 15. MEMOIRE | - | Oui | Oui | Oui |
| 16. META | Oui | Oui | Oui | Oui |

---

## Implementation par harness

| Etape | OpenCode | Claude Code |
|-------|----------|-------------|
| ASK | question tool natif | Plan mode + echo |
| CODEBASE | LSP tool (experimental) | Bash git + worktree |
| FAIRE gates | Plugin tool.execute.before | Hook PreToolUse exit 2 |
| MEMOIRE | Plugin + .ciel/ fichiers | auto memory native |
| CARTE | .ciel/map.json (auto) | memory: project subagent |

---

## Voir aussi

- [Architecture generale](architecture.md)
- [Systeme d'agents](agents.md)
- [Bibliotheque de skills](skills.md)
- [Guide d'utilisation](../guides/using-ciel.md)
