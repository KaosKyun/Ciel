# Ciel — Changelog

## v1.9.0 — 2026-04-05

**Changements** : CRITIQUER overhaul — parité output gates avec CRÉER

- **Entry**: instruction explicite "lire le diff/PR avant tout step"
- **APPRENDRE**: modèle de comportement attendu remplace "WebSearch anti-patterns" (langage CRÉER inadapté à la review); checklist de bypass signals explicite; 2 output gates ajoutés
- **COMPRENDRE**: 3 assumptions doivent être *vérifiées* (grep/blame/read), pas juste "surfacées" — distinction passive→active
- **QUESTIONNER**: 2 output gates ajoutés ("nothing considered?", "scope proportional?")
- **COMPARER**: STRIDE étendu — 6 questions explicites à cocher (Spoofing/Tampering/Repudiation/InfoDisclosure/DoS/Elevation); 3 output gates ajoutés
- **COHÉRENCE**: 3 checks concrets (grep pattern, layer boundaries, overlay thresholds) remplacent les bullets vagues
- **SIGNALER**: seuils de sévérité définis (BLOCKING = correctness/security/data loss; IMPORTANT = degraded behavior; MINOR = style; VALIDATED = confirmed correct); 3 output gates ajoutés
- **CAPITALISER**: actions concrètes (Guard ou overlay); 2 output gates ajoutés

**Problème adressé** : CRITIQUER avait 0 output gates sur 7 steps — exécutable sans produire aucune preuve. Un reviewer pouvait "compléter" CRITIQUER en 2 minutes et déclarer done.

**Métriques observées** :
- Critique de CRITIQUER (6 findings dont 3 BLOCKING) : 0 gates, STRIDE non exécuté, APPRENDRE = mauvais step, sévérités non définies, diff jamais explicitement lu, assumptions non vérifiées

**Déclenché par** : Audit capacités CRITIQUER de Ciel par CEO (2026-04-05)

---

## v1.8.0 — 2026-04-05

**Changements** (corrections structurelles — 0 nouvelles fonctionnalités, 6 fixes):
- SÉCURITÉ PASSE 4 supprimée du step 4 — elle instruisait une action post-FAIRE depuis un step pré-FAIRE (contradiction temporelle)
- Nouveau step **8b — SECURITY REGRESSION CHECK** entre FAIRE et RELIRE (Critical only) — même contenu, exécuté au bon moment
- **Before-state capture** ajouté à FAIRE (bug fix only) — capture AVANT avant d'écrire le code, satisfait l'obligation PROUVER AVANT/APRÈS
- PROUVER **Trivial allégé** : compile OK + push + no regression — CI gate et staging mandatory exclus pour les 1-line fixes
- RELIRE checklist TDD : `□ Tests written BEFORE` → `□ Tests could fail independently of implementation?` — vérifiable à n'importe quel moment
- RECHERCHE/CODEBASE boundary : `Imports/signatures` déplacé de RECHERCHE vers CODEBASE (API surface check) — clarification que RECHERCHE = externe, CODEBASE = interne
- META-CRITIQUER step 4 : grep `worktree-agent` spécifique Neiyomi → `git branch -r | wc -l` générique + note overlay

**Métriques observées** :
- Critique isolée (17 findings, 5 BLOCKING) a détecté : step 8b inaccessible depuis step 4, AVANT/APRÈS sans capture pre-FAIRE, PROUVER Trivial inutilisable, TDD check non-vérifiable à RELIRE, grep projet-spécifique dans un plugin universel

**Déclenché par** : Critique structurelle complète de SKILL.md v1.7.0 par agent critic isolé (2026-04-05)

---

## v1.7.0 — 2026-04-05

**Changements** :
- RECHERCHE output gate: version changelog check (breaking changes/deprecations for installed version)
- RECHERCHE output gate: framework philosophy now requires "HOW does this framework want me to solve this?" — not just API docs
- SÉCURITÉ PASSE 4: security regression check — grep diff for new inputs/trust boundaries/removed auth blocks
- PROUVER: CI gate — `gh run list --branch $BRANCH` mandatory before presenting report
- PROUVER: issue comment gate — staging PID + AVANT/APRÈS on linked issue BEFORE creating PR (not post-merge only)
- PROUVER: open PR hygiene — draft + CI green → convert to ready; PR > 2 days CI green → flag
- Guards: 6 new entries (security surface, CI ignored, draft PR left open, issue comment missing, version changelog missed)

**Déclenché par** : 3 retours CEO sur security rigor, PR/issue tracking, et profondeur de recherche (2026-04-05)

---

## v1.6.0 — 2026-04-05

**Changements** :
- ÉVALUER: recent-churn check — `git log --since=7days` on impacted files before proposing fix; prevents fix-of-fix chains
- FAIRE: volume gate — pause + verify each PR when 3+ created in same session
- RELIRE checklist: linter gate — explicit "0 new violations (Detekt/ESLint)" item
- PROUVER: PR body gate — `Closes #XXX` required, WIP title forbidden, PR closed check
- META-CRITIQUER: stale branch check

**Déclenché par** : Audit CRITIQUER des 25 issues + 8 PRs ouverts Neiyomi (2026-04-05)

---

## v1.3.0 — 2026-04-04

**Déclenché par** : Analyse des lacunes TDD — aucun gate ne forçait test-avant-implémentation, niveau de test implicite, failure path optionnel.

**Changements** : FLUX test level item, FAIRE test gate (RED first), RELIRE checklist TDD item, Guard TDD inversion.

---

## v1.2.0 — 2026-04-04

**Déclenché par** : Recherche 2026 (SWE-Bench Pro, SICA, MAST, SWE-EVO, AI Agent Memory 2026).

**Changements** : task decomposition gate, typed agent dispatch (MAST), assumption verification (SWE-EVO), 4-type memory model, SICA validator, self-cleaning cycle, self-update script.

---

## v1.1.0 — 2026-04-04

**Déclenché par** : Audit CRITIQUER dev-reasoning v18.3. 3 BLOCKING + 4 IMPORTANT.

**Changements** : RELIRE-A/B inline, removal gate, Guards "How it manifests" column, PROUVER attacker perspective, mini repo-map, SÉCURITÉ hygiene.

---

## v1.0.0 — 2026-04-04

**Déclenché par** : 62.8% fix/revert sur 675 commits Neiyomi avec dev-reasoning monolithique.

**Changements** : architecture 5-layer, agents OBLIGATOIRES Standard/Critical, RECHERCHE output gate (6 items), FLUX 3 items test-spécifiques.
