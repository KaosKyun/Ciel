---
name: deployment-strategies
description: "Deployment Strategies — deploy small/deploy often, blue-green, canary, DB migration coordination, feature flags as decoupling, rollback as first-class. À charger quand on planifie ou améliore un déploiement."
---

# Deployment Strategies

**Principe premier :** La CD n'est pas "déployer vite" — c'est déployer PETIT. On ne fait pas de déploiement continu avec des PRs de 2000 lignes. La confiance vient de la taille du diff : un diff de 50 lignes est trivial à debug, un diff de 5000 lignes est un incident en attente. Blue-green, canary, feature flags — toutes ces stratégies sont des filets de sécurité, pas des enablers. Le vrai enabler, c'est la capacité à découper le travail en incréments déployables indépendamment.

## Checklist
- [ ] La taille du diff est le premier indicateur de risque — si > 500 lignes, découper
- [ ] DB migration ET rollback de migration testés AVANT le déploiement du code
- [ ] Health checks définis (liveness ≠ readiness ≠ startup) — basculer le trafic uniquement sur readiness OK
- [ ] Rollback = un clic ou un revert automatisé (pas de procédure manuelle de 10 étapes)
- [ ] Feature flags pour tout changement de comportement — dissociation déploiement / activation
- [ ] Smoke tests automatiques post-déploiement (endpoints critiques, pas toute la suite E2E)
- [ ] Observabilité du déploiement : dashboards de comparaison avant/après (erreurs, latence, throughput)

## Anti-patterns
### Déploiement = événement stressant
**Ce qu'on voit :** le déploiement est planifié, annoncé, tout le monde est en war room. On prie. Si ça casse, c'est la panique.
**Pourquoi c'est dangereux :** si déployer fait peur, c'est que la confiance est absente. La peur pousse à déployer moins souvent → les diffs grossissent → encore plus peur → spirale de la mort. Une équipe qui fait vraiment de la CD déploie 10×/jour sans y penser.
**Faire plutôt :** rendre le déploiement ennuyeux. Automatiser tout ce qui peut l'être. Si le déploiement est stressant, investir dans la confiance (tests, health checks, rollback automatique) plutôt que dans le processus.

### Déploiement et migration DB couplés
**Ce qu'on voit :** le déploiement inclut une migration DB `ALTER TABLE... NOT NULL`. Le rollback du code est facile, le rollback de la migration est impossible.
**Pourquoi c'est dangereux :** le couplage code/schema crée des déploiements irréversibles. Si le code est buggé, tu peux rollback le code mais pas la DB → le vieux code casse sur le nouveau schema. C'est la cause #1 des incidents de déploiement qui durent > 1h.
**Faire plutôt :** règle d'or — la migration DB doit être compatible avec l'ancien ET le nouveau code (expand/contract). Ajouter une colonne sans contrainte, déployer le code qui l'utilise, puis ajouter la contrainte. Chaque étape est réversible. Les migrations sont testées avec le rollback dans la CI.

### Feature flags sans plan de cleanup
**Ce qu'on voit :** `if (featureFlags.isEnabled("new-checkout-v2"))` partout. Après 6 mois, v1, v2, v3 coexistent. Le code est incompréhensible.
**Pourquoi c'est dangereux :** les feature flags sont une dette technique à intérêt composé. Chaque flag ajoute une branche, et les branches se multiplient (2^n combinaisons). Sans cleanup, le système devient intestable.
**Faire plutôt :** chaque flag a une date d'expiration. Une tâche de cleanup est créée au moment où le flag est introduit. Après 100% de rollout, le flag est supprimé dans les 2 semaines. Si un flag existe depuis > 1 mois, il devient une urgence tech.

### Canary sans critère de succès
**Ce qu'on voit :** "on envoie 5% du trafic au nouveau code et on voit bien". Pas de métrique, pas de seuil, pas de rollback automatique.
**Pourquoi c'est dangereux :** sans critère objectif, le canary est du théâtre. Personne ne sait à quel moment dire "le canary a échoué". Résultat : le canary "passe" toujours, jusqu'au déploiement complet où le bug explose à 100%.
**Faire plutôt :** canary avec critères automatiques. "Si P95 latency > +20% OU error rate > +50% pendant 5 min → rollback automatique. Si OK pendant 15 min → 30% → 50% → 100%." La décision est algorithmique, pas humaine.

## Patterns
### Expand/Contract pour les migrations DB
**Quand :** toute modification de schema en production.
**Comment :** Phase 1 (expand) : ajouter les nouvelles colonnes/tables, le code lit l'ancien et écrit les deux. Phase 2 (migrate) : backfill les données existantes par batches. Phase 3 (contract) : le code ne lit que le nouveau, supprimer l'ancien. Chaque phase est une PR séparée, déployable et rollbackable indépendamment.

### Blue-Green
**Quand :** zero downtime requis, rollback immédiat nécessaire.
**Comment :** 2 environnements identiques. Le live (blue) tourne. On déploie sur green, on smoke-test green, on bascule le trafic. Blue reste chaud 24h. Si incident → rebascule sur blue (10 secondes, pas 10 minutes). Le vrai coût est l'infra doublée — à réserver pour les services critiques.

### Feature flags comme architecture
**Quand :** toute fonctionnalité qui change le comportement utilisateur.
**Comment :** le flag ne cache pas juste un `if` — il est injecté, testable, avec un fallback explicite. `if (flags.isEnabled("new-checkout", { default: false }))`. Chaque flag est testé avec les deux valeurs dans la CI. Le flag est un contrat temporaire, pas un état permanent.
