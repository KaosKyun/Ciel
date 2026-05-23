---
name: caching
description: "Caching — strategies cache, invalidation, Redis, CDN, stampede protection. A charger des qu'on parle de performance, temps de reponse, ou mise en cache."
---

# Caching

## Checklist
- [ ] La strategie de cache est choisie selon le pattern d'acces (cache-aside, write-through, write-behind)
- [ ] Le TTL est explicite et justifie (pas de cache infini)
- [ ] L'invalidation est automatique (TTL) ou explicite (evenement) — jamais manuelle
- [ ] Cache stampede protection en place (cold start avec 1000 requetes simultanees)
- [ ] Le cache est monitorable (hit rate, miss rate, eviction rate, memoire utilisee)
- [ ] Les cles de cache sont namespaced et versionnees (eviter les collisions)

## Anti-patterns
### Cache infini
**Ce qu'on voit :** `SET cache:user:123 {...}` sans TTL. Le cache n'expire jamais.
**Pourquoi c'est dangereux :** les donnees deviennent stales. L'utilisateur voit son ancien email. Redis finit par etre plein → eviction aleatoire de cles importantes.
**Faire plutot :** toujours un TTL. Court pour les donnees qui changent (1-5 min), long pour le statique (1-24h). Jamais infini.

### Cache-aside non-atomique
**Ce qu'on voit :** `cache.get(key)` → miss → `db.query(...)` → `cache.set(key, data)`. Sans lock.
**Pourquoi c'est dangereux :** 1000 miss simultanes → 1000 requetes DB en parallele. Cache stampede.
**Faire plutot :** probabilistical early recomputation. Ou lock distribue (Redis `SETNX`) pour qu'un seul worker remplisse le cache.

### Invalidation manuelle
**Ce qu'on voit :** "pense a vider le cache quand tu modifies cette table" dans un commentaire.
**Pourquoi c'est dangereux :** le commentaire n'est pas lu. Le cache et la DB sont incoherents. Bug intermittent.
**Faire plutot :** invalidation basee sur les evenements (DB trigger → event → cache invalidation). Ou TTL assez court pour que l'incoherence soit acceptable.

## Patterns
### Cache-aside
**Quand :** lecture dominante, tolerance a la stale data temporaire.
**Comment :** (1) lire le cache (2) si miss → lire la DB (3) ecrire dans le cache (4) retourner. L'app est responsable du cache.

### Write-through
**Quand :** les donnees ecrites sont souvent relues immediatement.
**Comment :** ecrire dans le cache ET dans la DB dans la meme operation. Le cache est toujours chaud pour les lectures recentes.

### Cache stampede protection
**Quand :** une cle chaude expire et reçoit un deluge de requetes simultanees.
**Comment :** avant d'expirer, un worker recalcule la valeur et met a jour le cache (probabilistic early recomputation). Ou lock le temps du recompute.
