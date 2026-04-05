# Ciel — Changelog

## v1.7.0 — 2026-04-05

**Changements** :
- RECHERCHE output gate: version changelog check (breaking changes/deprecations for installed version)
- RECHERCHE output gate: framework philosophy now requires "HOW does this framework want me to solve this?" — not just API docs
- SÉCURITÉ PASSE 4: security regression check — grep diff for new inputs/trust boundaries/removed auth blocks
- PROUVER: CI gate — `gh run list --branch $BRANCH` mandatory before presenting report
- PROUVER: issue comment gate — staging PID + AVANT/APRÈS on linked issue BEFORE creating PR (not post-merge only)
- PROUVER: open PR hygiene — draft + CI green → convert to ready; PR > 2 days CI green → flag
- Guards: 6 new entries (security surface, CI ignored, draft PR left open, issue comment missing, version changelog missed)

**Métriques observées** :
- Baseline (pre-Ciel): 62.8% fix/revert
- Issues observées ayant déclenché cette version: draft PRs non mergés, commentaires manquants sur issues, security fixes sans vérification de régression, CI non vérifié avant rapport

**Déclenché par** : 3 retours CEO sur security rigor, PR/issue tracking, et profondeur de recherche (2026-04-05)

---

## v1.6.0 — 2026-04-05

**Changements** :
- ÉVALUER: recent-churn check — `git log --since=7days` on impacted files before proposing fix; prevents fix-of-fix chains
- FAIRE: volume gate — pause + verify each PR when 3+ created in same session
- RELIRE checklist: linter gate — explicit "0 new violations (Detekt/ESLint)" item
- PROUVER: PR body gate — `Closes #XXX` required, WIP title forbidden, PR closed check
- META-CRITIQUER: stale branch check — `worktree-agent` branches > 5 → cleanup

**Métriques observées** :
- Staging verification: 100% des PRs (8/8) avaient AVANT/APRÈS PID evidence ✓
- Commit discipline: 100% prefixes conventionnels ✓
- Linter violations pushées avant fix: ~35% des PRs contenaient Detekt violations → cible 0%
- Issues non linkées (`Closes #` manquant): ~30% → cible 0%
- Fix-of-fix chains: 4 PRs sur update subsystem en 1 jour → cible ≤ 1 PR/module/jour

**Déclenché par** : Audit CRITIQUER des 25 issues + 8 PRs ouverts Neiyomi (2026-04-05)

---

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
