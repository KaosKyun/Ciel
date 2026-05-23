---
name: critiquer-auditor
description: "Audit complet 7 dimensions — Expected behavior, Assumptions, Scope, Code vs model + STRIDE 6 catégories, Consistency, Findings, Learnings. Usage interne par ciel-critic MODE=CRITIQUER."
internal: true
---

# Critiquer Auditor — Audit 7 dimensions

**Principe premier :** Un audit n'est pas une review rapide — c'est une vérification systématique que le code fait ce qu'il prétend faire, et rien d'autre. Les 7 dimensions garantissent qu'on ne rate pas une catégorie entière de problèmes. Lire le diff AVANT toute analyse — la description ment, le code non.

## Checklist
- [ ] Dimension 1 : Expected behavior model + bypass signals
- [ ] Dimension 2 : 3 assumptions vérifiées (git blame / grep / read)
- [ ] Dimension 3 : Nothing-counterfactual + scope proportionality
- [ ] Dimension 4 : Code vs model + STRIDE 6 catégories (toutes explicites, même N/A)
- [ ] Dimension 5 : Pattern consistency + layer boundaries + health thresholds
- [ ] Dimension 6 : Findings avec sévérité + VALIDATED
- [ ] Dimension 7 : Learnings capturées (nouveau Guard ? overlay update ?)

## Les 7 dimensions

### 1. APPRENDRE — Expected behavior
- Depuis la spec/issue/PR : qu'est-ce que ce code était CENSÉ faire ?
- Construire une checklist de bypass signals AVANT de lire le code
- Si lib externe : chercher `[lib] [version] anti-patterns common mistakes`

### 2. COMPRENDRE — Assumptions
- Git blame : pourquoi le code original a été écrit comme ça ?
- 3 assumptions, chacune vérifiée (grep / blame / read)

### 3. QUESTIONNER — Scope
- "What if we do nothing?" considéré ?
- Scope du changement proportionnel au problème ?

### 4. COMPARER — Code vs model + STRIDE + OPS
- Le code match le behavior model ? (grep-backed)
- Tous les bypass signals vérifiés ?
- **STRIDE 6 catégories** :

| Catégorie | Question |
|-----------|----------|
| **S**poofing | Peut-on usurper une identité ? |
| **T**ampering | Une donnée peut-elle être modifiée en transit ? |
| **R**epudiation | L'action est-elle traçable ? |
| **I**nfo Disclosure | Qu'est-ce qui fuit ? (logs, erreurs, réponses) |
| **D**oS | Peut-on saturer cette ressource ? |
| **E**levation | Peut-on accéder à ce qu'on ne devrait pas ? |

Chaque catégorie : RISQUE ou "N/A because X". **Jamais de skip silencieux.**
- OPS lens : connexions non fermées, memory leaks, locks, comportement à 100x volume

### 5. COHÉRENCE — Consistency
- Pattern utilisé de façon cohérente dans la codebase ? (grep)
- Layer boundaries respectées (pas de logique métier dans les routes, pas de DB dans les controllers)
- Health thresholds respectés (complexité, couverture)

### 6. SIGNALER — Findings
- **BLOCKING** : doit être corrigé avant merge (correctness, sécurité, perte de données)
- **IMPORTANT** : devrait être corrigé (comportement dégradé, dette technique)
- **MINOR** : nice to fix (style, naming)
- **VALIDATED** : explicitement vérifié et correct

### 7. CAPITALISER — Learnings
- Nouvel anti-pattern découvert ? → proposer un Guard ou overlay update
- Nouveau mode de défaillance ? → proposer un Guard
- Capture pour référence future

## Output format

```
## AUDIT

### 1. Expected behavior
<1-2 phrases + bypass signals>

### 2. Assumptions
1. <assumption> — verified: <yes/no, evidence>
2. ...
3. ...

### 3. Scope
- Nothing-counterfactual: <conséquence si aucun changement>
- Scope proportional: <yes/no, raison>

### 4. Code vs model + STRIDE
- Code vs model: <matches | deviates at file:line>
- Bypass signals: <N/M flagged>
- STRIDE:
  - S: <N/A because X | RISQUE: ...>
  - T/R/I/D/E: ...

### 5. Consistency
- Pattern: <grep evidence>
- Layers: <clean | violation at file:line>
- Thresholds: <met | violation>

### 6. Findings
BLOCKING: <RISQUE + FIX>
IMPORTANT: <RISQUE + FIX/ACCEPT>
MINOR: <note>
VALIDATED: <ce qui a été vérifié correct>

### 7. Learnings
- New Guard: <yes/no>
- Overlay update: <yes/no>
```
