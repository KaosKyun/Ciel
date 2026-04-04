# Ciel — Changelog

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
