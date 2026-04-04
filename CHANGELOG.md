# Ciel — Changelog

## v1.2.0 — 2026-04-04

**Déclenché par** : Intégration de la recherche 2026 (SWE-Bench Pro, SICA, MAST taxonomy, SWE-EVO, State of AI Agent Memory 2026, AWS Agent Plugins).

**Problèmes adressés que Ciel ne savait pas gérer :**
1. **Mauvaise décomposition de tâches** (SWE-Bench Pro 2026 : planning = root cause de 80% des échecs multi-fichiers) — Ciel n'avait pas de gate sur la décomposition avant RECHERCHE.
2. **Ambiguité inter-agents** (MAST 2026 : 37% des échecs = messages free-form entre agents) — dispatches non structurés.
3. **Assumptions invalidées silencieusement** (SWE-EVO 2026 : agents échouent quand le codebase change sous eux) — aucun mécanisme d'inventaire d'assumptions.
4. **Auto-amélioration sans validateur** (SICA 2025 : sans validateur indépendant → Goodhart's Law) — Guards ajoutés sans vérification de régression sur les corrections précédentes.
5. **Mémoire plate** (State of AI Agent Memory 2026) — overlay + lessons = tout dans un seul format → dérive sémantique.
6. **Auto-update impossible** — plugin sans mécanisme de mise à jour depuis GitHub.

**Changements v1.2.0 :**
1. **QUOI — Task decomposition gate** : 3+ fichiers → décomposer en sub-tasks atomiques AVANT RECHERCHE. + Assumption inventory (top 3 hypothèses, vérifiées à RELIRE).
2. **Typed agent dispatch schema** (MAST) : TYPE + AGENT + TASK + EXPECTED_OUTPUT sur tous les dispatches researcher/explorer/critic.
3. **RELIRE — Assumption verification** : vérifie que chaque assumption de QUOI tient encore après FAIRE (SWE-EVO).
4. **ÉVOLUER — 4-type memory model** : Procedural (SKILL.md) / Semantic (overlay) / Episodic (CHANGELOG) / Working (in-context). Routage explicite.
5. **ÉVOLUER — SICA validator** : avant de persister un Guard/step change, valider contre les 3 dernières corrections CEO. Prévient Goodhart.
6. **ÉVOLUER — Self-cleaning cycle** : suivi de fréquence par Guard. 0 triggers sur 10+ sessions → candidat à la suppression. Vérification avant suppression.
7. **Nouveau Guard** : assumption invalidation, agent coordination failure, poor task decomposition, self-improvement regression.
8. **`scripts/self-update.sh`** — auto-update via gh CLI : compare SHA local vs GitHub, hot-swap si différent.
9. **`commands/ciel-update.md`** — commande `/ciel-update`.

**Métriques** : baseline = 62.8% fix/revert. Cible v1.2.0 → < 25%.
**Guards ajoutés** : assumption invalidation, agent coordination failure, poor task decomposition, self-improvement regression
**Guards supprimés** : aucun

---

## v1.1.0 — 2026-04-04

**Déclenché par** : Audit CRITIQUER complet par dev-reasoning v18.3 comparant Ciel v1.0 point par point. 3 BLOCKING + 4 IMPORTANT + 2 nouvelles additions issues de la recherche 2025-2026.

**Changements** :
1. RELIRE-A/B format restauré inline (Trivial sans agent)
2. Removal gate ajoutée dans FAIRE (incident 2026-03-26)
3. Guards table : 22 guards, colonne "How it manifests"
4. Depth Gauge : colonne CRITIQUER ajoutée
5. PROUVER : attacker perspective test, same-source rule, post-merge closure
6. CODEBASE : mini repo-map 3-grep recipe inline
7. SÉCURITÉ : checklist hygiene + multi-PR delegation
8. Nouveaux guards : context overflow, over-engineering/counterfactual

**Métriques** : baseline 62.8%, cible < 30%.

---

## v1.0.0 — 2026-04-04

**Déclenché par** : Audit de 675 commits sur Neiyomi montrant 62.8% de ratio fix/revert avec dev-reasoning monolithique.

**Changements vs dev-reasoning v18.3** :
1. Architecture 5-layer : hooks + skill + agents isolés + overlay + métriques
2. Agents OBLIGATOIRES sur Standard/Critical
3. RECHERCHE output gate (6 items)
4. FLUX : 3 items test-spécifiques
5. RELIRE : 3 items ajoutés
6. Overlay pattern — portabilité totale

**Métriques** : fix/revert ratio baseline = 62.8%.

---

## Format des entrées futures

```markdown
## vX.Y.Z — [date]
**Déclenché par** : [incident ou audit]
**Problèmes adressés** : [ce que Ciel ne savait pas faire avant]
**Changements** : [description]
**Métriques** : fix/revert avant = X%, cible = Y%
**Guards ajoutés** : [liste]
**Guards supprimés** : [liste + raison]
```
