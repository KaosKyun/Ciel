---
name: debug-reasoning-rca
description: "Root Cause Analysis — 3 hypothèses causalement distinctes (≥2 fault-types), semantic diff (EXPECTED/ACTUAL/GAP/ROOT), fix direct + systémique. Supporte 5 Whys, Ishikawa, Tree Diagram, Relations Diagram pour cas complexes. Usage interne par ciel-critic MODE=RCA."
internal: true
---

# Debug Reasoning — Root Cause Analysis

**Principe premier :** Ne jamais proposer un fix avant qu'une hypothèse soit SUPPORTÉE par des preuves. "It might be this, let me fix it" est interdit. Le plus dur n'est pas de trouver le fix — c'est de résister à l'envie de fixer avant de comprendre. La méthode des 3 hypothèses force à considérer des alternatives avant de s'engager sur une.

## Checklist
- [ ] Step 1 : Contexte rassemblé (stack trace, code au file:line, changements récents, repro)
- [ ] Step 2 : 3 hypothèses générées, ≥ 2 fault-types différents
- [ ] Step 3 : Chaque hypothèse validée par un check ciblé (pas un fix)
- [ ] Step 4 : Semantic diff complété (EXPECTED/ACTUAL/GAP/ROOT)
- [ ] Step 5 : Fix direct + fix systémique
- [ ] Confidence level déclaré (HIGH/MEDIUM/LOW)

## Step 1 — Gather context

Avant toute hypothèse :
- **Lire l'erreur littéralement** — stack trace, log line, exit code
- **Lire le code au file:line exact** de la trace
- **Check recent changes** — `git log -p --since="7 days ago" -- <scope>`
- **Run the repro** une fois, capture complète

Skip cette étape = hypothèses basées sur des impressions.

## Step 2 — Generate 3 hypotheses

EXACTLY 3 hypothèses **causalement distinctes**. Pas 3 variantes de la même théorie.

Format :
```
H<n>: <cause> → <mechanism> → <observable effect>
  Evidence for: <ce qui serait vrai si correct>
  Evidence against: <ce qui serait vrai si faux>
  Fault-type: [MODEL | CONTEXT | ORCHESTRATION | ENVIRONMENT]
```

### Fault-type taxonomy

| Type | Signification | Exemple |
|------|-------------|---------|
| **MODEL** | Logique code erronée | Off-by-one, mauvais algo, mauvaise hypothèse |
| **CONTEXT** | Input manquant/périmé | Mauvaise config, race window, state leak |
| **ORCHESTRATION** | Infrastructure mal configurée | Retry/timeout wrong, queue backlog |
| **ENVIRONMENT** | Changement externe | Dependency drift, OS change, infra outage |

**Règle de distribution** : ≥ 2 fault-types différents. Trois hypothèses MODEL = tunnel vision.

## Step 3 — Validate (targeted checks)

Pour chaque hypothèse, UN check ciblé (pas un fix) :
- MODEL → ajouter un log ou test unitaire qui vérifie l'invariant attendu
- CONTEXT → dump l'input/config réel au point de défaillance ; diff vs attendu
- ORCHESTRATION → vérifier retry count, timeout, queue depth au moment de la panne
- ENVIRONMENT → `<pkg-mgr> list | grep <dep>` vs lockfile

## Step 4 — Semantic diff

```
EXPECTED: <comportement attendu>
ACTUAL:   <comportement observé>
GAP:      <mécanisme précis de l'écart>
ROOT:     <pourquoi cet écart existe — pas "because the code is buggy", le vrai pourquoi>
```

Si ROOT ressemble à "parce que le code est buggé" → t'as trouvé le symptôme, pas la cause. Demande "pourquoi" encore.

## Step 5 — Fix (two layers)

- **Direct fix** — adresse l'hypothèse supportée (le bug lui-même)
- **Systemic fix** — adresse pourquoi le bug était possible (test manquant, alerte manquante, type manquant)

Le systemic fix est le levier 75% de réduction du MTTR. Ne pas le skip.

## Méthodes RCA complémentaires

| Problème | Méthode | Pourquoi |
|-----------|---------|---------|
| Linéaire, symptôme unique | **3 hypothèses** (défaut) | Rapide, parallèle |
| Incident récurrent, processus | **5 Whys** | Itératif jusqu'à la cause systémique |
| Multi-facteur, exploration exhaustive | **Ishikawa (Fishbone)** | 6M families guident la couverture |
| Multi-couche, système complexe | **Drill Down / Tree Diagram** | Décomposition récursive MECE |
| Causes interactives, feedback loops | **Relations Diagram** | Causal links → drivers vs effects |

## Output format

```
## RCA VERDICT

### Symptom
<1 phrase>

### Repro
<commande exacte ou "flaky — triggers ~1/N runs">

### Hypotheses explored
H1 [MODEL]: <cause> — <supported|refuted|inconclusive> — <evidence>
H2 [CONTEXT]: <cause> — <supported|refuted|inconclusive> — <evidence>
H3 [ORCHESTRATION]: <cause> — <supported|refuted|inconclusive> — <evidence>

### Root cause
<hypothesis>: <cause>

### Semantic diff
EXPECTED/ACTUAL/GAP/ROOT

### Fix
- Direct: <code change>
- Systemic: <test/alert/process to add>

### Confidence
HIGH | MEDIUM | LOW — <why>
```
