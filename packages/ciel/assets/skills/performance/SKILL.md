---
name: performance
description: "Performance — profiling, benchmarking, optimisation, latence, throughput, bottleneck, caching. A charger quand on optimise les performances."
---

# Performance

## Checklist
- [ ] Les metriques RED (Rate, Errors, Duration) sont mesurees pour chaque endpoint
- [ ] Un benchmark existe pour les parcours critiques (perf-test dans la CI)
- [ ] Le cache est utilise avec TTL explicite et strategie d'invalidation
- [ ] Les requetes N+1 sont identifiees et resolues (eager loading, batch)
- [ ] Les assets sont optimises (minification, compression, lazy loading)
- [ ] Les indexes DB sont verifies (EXPLAIN ANALYZE sur les requetes lentes)
- [ ] Le temps de reponse P95 est connu et suivi (pas seulement la moyenne)

## Anti-patterns
### Optimisation prematuree
**Ce qu'on voit :** du code complexe "pour la perf" alors que le parcours fait 10 req/s.
**Pourquoi c'est dangereux :** le code est illisible, difficile a maintenir, et l'optimisation cible peut-etre le mauvais endroit.
**Faire plutot :** "Make it work, make it right, make it fast" — dans cet ordre. Mesurer avant d'optimiser. Les vrais goulots sont rarement ceux qu'on imagine.

### Optimiser la moyenne pas le percentile
**Ce qu'on voit :** "le temps de reponse moyen est de 200ms, c'est bon". Mais le P95 est a 5s.
**Pourquoi c'est dangereux :** la moyenne cache la queue. 1% des requetes a 10s pourrit l'experience utilisateur.
**Faire plutot :** P95, P99, et P999. La moyenne est un mensonge. Les outliers sont les vrais problemes.

### Cache sans invalidation
**Ce qu'on voit :** `cache.set('user_data', data)` sans TTL ni strategie d'eviction.
**Pourquoi c'est dangereux :** les donnees stale sont servies indefiniment. L'utilisateur voit des informations obsoletes.
**Faire plutot :** TTL explicite. Invalidation sur write (cache-aside). Cache court (60s) pour les donnees dynamiques, long (1h) pour les donnees statiques.

## Patterns
### Performance budget
**Quand :** application web ou mobile.
**Comment :** budget defini : JS < 200KB, page < 1MB, LCP < 2.5s, TTI < 3s. Mesure dans la CI. Si le budget est depasse, la PR est bloquee.

### Slow query monitoring
**Quand :** application avec base de donnees.
**Comment :** loguer toutes les requetes > 100ms. `EXPLAIN ANALYZE` automatique. Alerte si une nouvelle query lente apparait. Index manquant = ticket prioritaire.
