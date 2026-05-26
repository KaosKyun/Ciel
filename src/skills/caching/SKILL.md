---
name: caching
description: "Caching — cache-aside/write-through, cache stampede protection, TTL strategy, invalidation as the hard problem. À charger quand on parle de performance ou de mise en cache."
---

# Caching

**Principe premier :** Il y a deux problèmes difficiles en informatique : nommer les choses, l'invalidation de cache, et les off-by-one. Le cache est un mensonge délibéré — tu sers une version potentiellement périmée de la donnée en échange de latence réduite. La seule question qui compte est : "quelle est la péremption acceptable pour CE cas d'usage ?" Si la réponse est 0ms, pas de cache. Si la réponse est "5 minutes, c'est acceptable", tu as un budget d'incohérence. Nommer ce budget explicitement est le design du cache.

## Checklist
- [ ] La stratégie est choisie selon le pattern d'accès : cache-aside (read-heavy), write-through (read-after-write), write-behind (write-heavy)
- [ ] Chaque entrée de cache a un TTL explicite et justifié — jamais de cache infini
- [ ] La protection anti-stampede est en place — 1000 miss simultanés ne déclenchent pas 1000 requêtes DB
- [ ] Le cache est monitoré : hit rate, miss rate, eviction rate, mémoire utilisée
- [ ] L'invalidation est événementielle ou par TTL — jamais "pense à vider le cache" en commentaire

## Anti-patterns
### Cache infini
**Ce qu'on voit :** `cache.set('user:' + id, userData)` sans TTL. Le cache ne sera vidé que quand Redis sera plein et fera une éviction arbitraire.
**Pourquoi c'est dangereux :** l'incohérence grandit avec le temps. L'utilisateur change son email dans la DB, le cache sert l'ancien pendant des jours. Le bug est intermittent (parfois cache hit, parfois miss) — le pire type de bug à debugger.
**Faire plutôt :** toujours un TTL. Court pour les données dynamiques (1-5 min). Long pour le statique (1-24h). Le TTL est un compromis entre fraîcheur et performance — le choisir consciemment.

### Cache stampede
**Ce qu'on voit :** une clé chaude expire. 1000 requêtes simultanées arrivent. Toutes font un cache miss → toutes interrogent la DB. La DB reçoit 1000× la même requête.
**Pourquoi c'est dangereux :** le stampede transforme un cache miss en attaque DDoS auto-infligée. La DB qui allait bien voit soudainement 1000× la charge normale. Pire : elle génère 1000× la même réponse, et 999 réponses sont jetées.
**Faire plutôt :** probabilistic early recomputation (recalculer avec une probabilité croissante quand le TTL approche). Ou lock distribué temporaire — un seul worker recalcule, les autres attendent le résultat (SETNX).

### Invalidation commentée
**Ce qu'on voit :** `// PENSE À VIDER LE CACHE QUAND TU MODIFIES CETTE TABLE` — dans un commentaire. Qui n'est pas lu. Par un dev qui ne savait pas. Le cache et la DB divergent silencieusement.
**Pourquoi c'est dangereux :** l'invalidation manuelle est une machine à bugs intermittents. Chaque écriture est une opportunité d'oubli. Le bug n'apparaît que dans le cas "cache hit après écriture" — difficile à reproduire.
**Faire plutôt :** invalidation automatique. Événement DB → event bus → cache invalidation. Ou TTL assez court pour que l'incohérence maximale soit acceptable. Jamais de "penser à" dans la conception d'un système.

## Patterns
### Cache-aside
**Quand :** lecture dominante, tolérance à la stale data.
**Comment :** (1) lire le cache, (2) si hit → retourner, (3) si miss → lire la DB, (4) écrire dans le cache, (5) retourner. L'application est responsable de la cohérence. Simple, mais attention au stampede.

### Write-through
**Quand :** les données écrites sont presque toujours relues immédiatement.
**Comment :** écrire dans le cache ET dans la DB dans la même opération. Le cache est toujours chaud pour les lectures récentes. Coût : chaque écriture touche le cache, même si personne ne relit.

### Probabilistic early recomputation
**Quand :** protéger une clé chaude du stampede.
**Comment :** avant que le TTL n'expire, le worker vérifie si `random() < 1 / (TTL_remaining_seconds * request_rate)`. Si oui, il recalcule de manière anticipée et met à jour le cache. Statistiquement, un seul worker le fait.
