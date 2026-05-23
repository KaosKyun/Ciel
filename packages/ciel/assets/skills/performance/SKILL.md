---
name: performance
description: "Performance — mesurer avant d'optimiser, P95 > moyenne, performance budgets, profiling, N+1, slow queries. À charger quand on parle d'optimisation."
---

# Performance

**Principe premier :** "Make it work, make it right, make it fast" — dans cet ordre. La performance est une feature, pas une propriété magique. Comme toute feature, elle a un coût et doit être mesurée. Le piège classique est l'optimisation prématurée : du code complexe et illisible pour gagner 5ms sur un endpoint appelé 10×/jour. La règle d'or : ne jamais optimiser sans avoir mesuré. Le bottleneck réel n'est presque jamais là où on pense. Et la métrique qui compte n'est pas la moyenne — c'est le P95 (ou P99). La moyenne ment parce qu'elle cache les outliers, et ce sont les outliers qui pourrissent l'expérience utilisateur.

## Checklist
- [ ] Profiling AVANT optimisation — jamais d'optimisation sur une intuition
- [ ] Métriques RED par endpoint : Rate, Errors, Duration (P50, P95, P99)
- [ ] Les requêtes N+1 sont identifiées et résolues (eager loading, batch, JOIN)
- [ ] Performance budget dans la CI : JS < 200KB, LCP < 2.5s, P95 < 500ms
- [ ] Les requêtes lentes sont loguées (> 100ms) avec EXPLAIN automatique
- [ ] Cache en place avec TTL explicite — pas de calcul redondant sur la hot path

## Anti-patterns
### Optimisation prématurée
**Ce qu'on voit :** micro-optimisations de boucles, bit-shifting, allocation pooling — sur un endpoint appelé 100×/jour. Le code est devenu illisible pour gagner 2ms.
**Pourquoi c'est dangereux :** l'optimisation prématurée a un double coût : le code devient plus dur à maintenir, et le temps passé à optimiser n'est pas passé sur des vrais problèmes. Pire : l'optimisation cible souvent le mauvais endroit parce qu'elle est basée sur l'intuition, pas sur la mesure.
**Faire plutôt :** "Make it work, make it right, make it fast." Mesurer. Profiler. Identifier le vrai bottleneck (souvent une requête DB, pas une boucle). Optimiser là où le profiling montre un gain. Si le gain est < 10%, se demander si la complexité ajoutée le justifie.

### Optimiser la moyenne
**Ce qu'on voit :** "la latence moyenne est de 200ms, c'est bon." Le P95 est à 8 secondes — 5% des utilisateurs attendent 8 secondes. Mais la moyenne est belle.
**Pourquoi c'est dangereux :** la moyenne est insensible aux outliers. 95% des requêtes à 50ms + 5% à 10s = moyenne de ~550ms. Tu regardes 550ms et tu penses "acceptable". Mais 5% de tes utilisateurs ont une expérience exécrable. Les percentiles existent pour cette raison précise.
**Faire plutôt :** P50 (médiane), P95, P99. Le P95 est l'expérience "normale dans le pire cas". Le P99 est l'expérience "vraiment mauvaise". Alerter et optimiser sur les percentiles, pas sur la moyenne.

### Cache sans stratégie
**Ce qu'on voit :** `cache.set(key, data)` sans TTL. Le cache garde des données stales indéfiniment. Ou pire : le cache est invalidé à chaque écriture mais jamais rechargé (cache toujours vide).
**Pourquoi c'est dangereux :** un cache mal conçu est pire que pas de cache — il ajoute de la latence (aller-retour Redis) pour servir des données périmées ou pour ne jamais avoir de hit. Le hit rate est la métrique qui dit si ton cache sert à quelque chose.
**Faire plutôt :** TTL explicite basé sur la fraîcheur acceptable. Surveiller le hit rate — si < 50%, le cache est probablement mal configuré. Cache-aside pour les lectures, write-through pour les lectures après écriture.

## Patterns
### Performance budget
**Quand :** application web ou mobile.
**Comment :** définir des seuils dans la CI. JS bundle < 200KB, page weight < 1MB, LCP < 2.5s, TTI < 3s, P95 API < 500ms. Si la PR dépasse, bloquer. Le budget force la discipline — comme un budget financier, tu ne peux pas ajouter sans enlever ailleurs.

### Slow query monitoring
**Quand :** toute application avec une base de données.
**Comment :** loguer toute requête > 100ms avec son EXPLAIN ANALYZE. Dashboard des slow queries. Alerte si une nouvelle slow query apparaît (requête qui était rapide avant, lente maintenant = probablement un index ou un volume de données). Chaque slow query est un ticket.
