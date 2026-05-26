---
name: cicd-pipeline
description: "CI/CD — feedback loops, DORA metrics, trunk-based dev, pipeline as constraint theory, matrix builds, OIDC, ephemeral runners. À charger quand on conçoit ou optimise un pipeline CI/CD."
---

# CI/CD Pipeline

**Principe premier :** La CI/CD n'est pas "automatiser les builds". C'est réduire le temps entre un commit et le feedback de production. Chaque minute perdue entre "j'écris" et "je sais si ça marche" est du gaspillage. Les 4 métriques DORA (Lead Time, Deploy Frequency, MTTR, Change Failure Rate) mesurent cette performance. Tout le reste — caching, parallel builds, OIDC — est un moyen, pas une fin.

## Checklist
- [ ] La pipeline donne du feedback en < 5 min (sinon les devs arrêtent de l'attendre)
- [ ] Le trunk-based development est la norme — branches ≤ 1 jour, pas de long-lived branches
- [ ] Les 4 DORA metrics sont mesurées et visibles (dashboard, pas dans un coin)
- [ ] Les secrets utilisent OIDC — zéro credential long-lived
- [ ] Les runners sont éphémères — rien ne survit entre deux builds
- [ ] Concurrency groups — pas deux pipelines en parallèle sur la même branche
- [ ] Le pipeline bloque sur flaky test detection (> 2% de flaky rate = quarantaine automatique)
- [ ] L'artefact de build est immutable et signé (hash + signature vérifiés au déploiement)

## Anti-patterns
### Branches longue durée
**Ce qu'on voit :** un dev travaille 2 semaines sur `feature/big-refactor`. Merge conflict de 200 fichiers. Tests jamais lancés ensemble.
**Pourquoi c'est dangereux :** le "I" de CI, c'est l'intégration. Si le code n'est pas intégré au trunk au moins 1×/jour, ce n'est pas de la CI. Le merge final est un événement traumatique — les bugs apparaissent tous en même temps, impossible de bisecter proprement.
**Faire plutôt :** trunk-based development. Branches ≤ 1 jour. Feature flags pour cacher le code incomplet. Petits commits fréquents — le diff est la meilleure défense contre les bugs.

### Pipeline vu comme un checklist et non une contrainte
**Ce qu'on voit :** lint → test → build → deploy, séquentiel. Le pipeline met 20 min et personne ne se demande pourquoi c'est lent.
**Pourquoi c'est dangereux :** un pipeline lent n'est pas juste chiant — il tue la boucle de feedback. Les devs ne poussent plus, ils accumulent, les PRs grossissent, la CI devient un bottleneck systémique. C'est la théorie des contraintes : le pipeline EST la contrainte.
**Faire plutôt :** traiter le pipeline comme un système à optimiser. Paralléliser tout ce qui peut l'être. Investir dans le cache. Splitter les tests lents. CI < 5 min — si c'est pas possible, c'est que l'architecture de test a un problème.

### Pipeline non versionné
**Ce qu'on voit :** le pipeline est configuré dans l'UI GitHub Actions, pas dans `.github/workflows/`. Ou pire : un Jenkins configuré à la main.
**Pourquoi c'est dangereux :** le pipeline n'est pas reproductible. Si le runner crashe, personne ne sait le reconstruire. Pas de code review sur les changements de pipeline. Le pipeline devient un snowflake.
**Faire plutôt :** pipeline as code — dans le repo, revu comme du code. Tout changement de pipeline passe par une PR. Le pipeline se teste lui-même (les changements de CI s'exécutent sur la PR qui les propose).

### Flaky tests ignorés
**Ce qu'on voit :** "ah ce test faille parfois, relance le job". Le pipeline a un taux de succès de 70% et tout le monde rerun jusqu'à ce que ça passe.
**Pourquoi c'est dangereux :** un test flaky tue la confiance dans le pipeline. Quand le rouge ne veut plus dire "bug", les vrais bugs passent au travers. Les devs développent une tolérance à l'échec — c'est la mort lente de la CI.
**Faire plutôt :** quarantaine automatique. Un test qui faille > 2% du temps est isolé dans une suite "quarantaine". Le pipeline principal bloque sur vrai rouge. La quarantaine est traitée comme dette technique prioritaire.

## Patterns
### OIDC
**Quand :** tout pipeline qui parle à un cloud provider.
**Comment :** GitHub Actions → OIDC token → AWS IAM / GCP WIF → credentials temporaires (< 1h). Zéro secret stocké. Rotation automatique. Si le token fuit, il expire avant d'être utilisable.

### Matrix build
**Quand :** bibliothèque ou outil utilisé sur plusieurs versions/OS.
**Comment :** `matrix: { node: [18, 20, 22], os: [ubuntu, macos] }`. Chaque combinaison est un job indépendant. Pas de "ça marche sur ma machine" quand la CI couvre 3 OS.

### Concurrency groups
**Quand :** éviter les interférences entre runs.
**Comment :** `concurrency: { group: deploy-${{ github.ref }}, cancel-in-progress: true }`. Un seul déploiement à la fois par branche. Le nouveau run annule le précédent. Évite les race conditions de déploiement.

### Flaky test quarantine
**Quand :** suite de tests avec > 100 tests.
**Comment :** chaque test a un compteur de flaky (fail suivi de pass sans changement de code). Si > 2% sur 100 runs → déplacé en `quarantine/`. Le pipeline principal ignore cette suite. La quarantaine est revue chaque sprint — chaque test est soit fixé, soit réécrit, soit supprimé.
