# Ciel — Changelog

## v1.1.0 — 2026-04-04

**Déclenché par** : Audit CRITIQUER complet par dev-reasoning v18.3 comparant Ciel v1.0 point par point. 3 BLOCKING + 4 IMPORTANT + 2 nouvelles additions issues de la recherche 2025-2026.

**Changements** :

BLOCKING résolus :
1. **RELIRE-A/B format restauré inline** — Le format Reflexion (`RISQUE: X parce que Y — IMPACT: Z`) est maintenant dans SKILL.md pour les tâches Trivial (sans agent). Avant : RELIRE n'avait aucun format structuré pour Trivial.
2. **Removal gate ajoutée dans FAIRE** — 3 questions obligatoires avant toute suppression : Who uses it? What replaces it? What degrades? Portée depuis dev-reasoning (incident 2026-03-26 : suppression SW image-cache sans vérification).
3. **Guards table restaurée** — 22 guards avec colonne "How it manifests" (contre 13 et 2 colonnes en v1.0). 9 guards manquants restaurés : false confidence, prior AI pattern, context overflow (NOUVEAU), removing without understanding, proposing without calculating, debugging wrong layer, coding without mental model, fixation after failure, coverage theater.

IMPORTANT résolus :
4. **Depth Gauge enrichi** — Colonne CRITIQUER ajoutée (Trivial → COMPRENDRE+SIGNALER, Standard → Full, Critical → Full+multi-pass).
5. **PROUVER complété** — 3 éléments manquants : attacker perspective test (security), same-source rule (complète), post-merge issue closure (evidence obligatoire).
6. **CODEBASE** — Mini repo-map 3-grep recipe documentée inline (pour Trivial sans explorer agent).
7. **SÉCURITÉ** — Checklist hygiene + multi-PR delegation ajoutés.

Nouveaux guards issus de la recherche 2025-2026 :
- **Context overflow silencieux** (Partnership on AI, 2025) — Agent report < 200 tokens sur Standard = suspect. Re-dispatcher.
- **Over-engineering / Counterfactual** (Nightwire pattern, 2025) — "What if we do NOTHING?" ajouté dans ÉVALUER et Guards.

**Métriques** : baseline = 62.8% fix/revert (Neiyomi 2026-04-04). Cible v1.1.0 → < 30%.
**Guards ajoutés** : context overflow, prior AI pattern, over-engineering, false confidence
**Guards supprimés** : aucun (tous les guards existants catchent des failure modes réels)

---

## v1.0.0 — 2026-04-04

**Déclenché par** : Audit de 675 commits sur Neiyomi montrant 62.8% de ratio fix/revert avec le workflow dev-reasoning monolithique (skill unique de ~600 lignes).

**Problèmes adressés** :
- RECHERCHE ne vérifiait pas les imports/API surfaces → imports manquants, colonnes DB inexistantes
- FLUX absent pour les tests → MSW URL mismatch, mock lifecycle errors, timeout CI
- RELIRE dans le même contexte que FAIRE → degeneration of thought (MAR, 2025)
- Agents optionnels → systématiquement skippés sur les "simple fixes"
- Pas de métriques par version → amélioration à l'aveugle
- Architecture monolithique → process debt, friction = skipping

**Changements vs dev-reasoning v18.3** :
1. Architecture 5-layer : hooks déterministes + skill + agents isolés + overlay + métriques
2. Agents researcher/explorer/critic rendus OBLIGATOIRES sur Standard/Critical
3. RECHERCHE : output gate avec 3 items API surface (imports, colonnes DB, format)
4. FLUX : 3 items test-spécifiques (URL routing, mock lifecycle, timing)
5. RELIRE : 3 items ajoutés (imports réels, colonnes DB réelles, mocks alignés)
6. Portabilité : overlay pattern — tout ce qui est projet-spécifique hors du plugin
7. Guards : pruning des guards redondants, ajout degeneration of thought + stale overlay

**Métriques de départ** : fix/revert ratio = 62.8% (baseline Neiyomi, 2026-03-25 → 2026-04-04)
**Cible v1.1.0** : < 30%

---

## Format des entrées futures

```markdown
## vX.Y.Z — [date]
**Déclenché par** : [incident ou audit]
**Changements** : [description]
**Métriques observées** : fix/revert avant = X%, après = Y%
**Guards ajoutés** : [liste]
**Guards supprimés** : [liste — ne catchaient plus rien]
```
