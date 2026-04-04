# Ciel — Changelog

## v1.3.0 — 2026-04-04

**Déclenché par** : Analyse des lacunes TDD — aucun gate ne forçait test-avant-implémentation, niveau de test implicite, failure path optionnel.

**Problèmes adressés :**
1. **TDD inversion** — tests écrits après passent par définition, ne catchent rien.
2. **Test level implicite** — aucune décision unit vs integration vs E2E dans FLUX.
3. **Failure path optionnel** — seul le happy path était testé de facto.

**Changements v1.3.0 :**
1. **FLUX** — 4ème item "If writing a test" : `Test level: unit / integration / E2E — justify the choice`.
2. **FAIRE — Test gate** (before writing implementation code — no exception) : RED first · behavior not execution · failure path mandatory.
3. **RELIRE Standard checklist** — `□` Tests written BEFORE implementation (not after)?
4. **Guards** — TDD inversion : write failing test FIRST.
**Fix post-RELIRE** : condition reformulée `(when writing source code)` → `(before writing implementation code — no exception)`.

**Guards ajoutés** : TDD inversion | **Guards supprimés** : aucun

---

## v1.2.0 — 2026-04-04

**Déclenché par** : Recherche 2026 (SWE-Bench Pro, SICA, MAST, SWE-EVO, AI Agent Memory 2026).

**Changements** : task decomposition gate, typed agent dispatch (MAST), assumption verification (SWE-EVO), 4-type memory model, SICA validator, self-cleaning cycle, self-update script.
**Guards ajoutés** : assumption invalidation, agent coordination failure, poor task decomposition, self-improvement regression.

---

## v1.1.0 — 2026-04-04

**Déclenché par** : Audit CRITIQUER dev-reasoning v18.3. 3 BLOCKING + 4 IMPORTANT.

**Changements** : RELIRE-A/B inline, removal gate, Guards "How it manifests" column, PROUVER attacker perspective, mini repo-map, SÉCURITÉ hygiene.

---

## v1.0.0 — 2026-04-04

**Déclenché par** : 62.8% fix/revert sur 675 commits Neiyomi avec dev-reasoning monolithique.

**Changements** : architecture 5-layer, agents OBLIGATOIRES Standard/Critical, RECHERCHE output gate (6 items), FLUX 3 items test-spécifiques.
