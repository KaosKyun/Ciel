---
name: resilience
description: "Resilience — circuit breakers, retry with backoff, timeouts, bulkheads, graceful degradation. À charger quand on rend un système tolérant aux pannes."
---

# Resilience

**Principe premier :** La résilience n'est pas "gérer les erreurs" — c'est concevoir le système pour qu'il continue à fonctionner (même en mode dégradé) quand ses dépendances tombent. Chaque dépendance externe va tomber un jour. La question n'est pas "est-ce que Redis est fiable ?" mais "que fait mon application quand Redis est down ?". Le circuit breaker n'est pas un pattern — c'est un réflexe : ne pas continuer à appeler un service qui ne répond pas.

## Checklist
- [ ] Timeouts explicites sur tout appel externe : connect < 2s, read < 5s, request < 10s
- [ ] Circuit breaker sur chaque dépendance : échecs > N → circuit OPEN → fast fail
- [ ] Retry avec backoff exponentiel + jitter — pas de retry immédiat, max 3-5 tentatives
- [ ] Bulkhead : pools de connexions séparés par client/type de requête
- [ ] Fallback défini pour chaque point de défaillance : cache, defaults, degraded mode
- [ ] Chaos engineering : tester la résilience en production, pas en théorie

## Anti-patterns
### Retry sans backoff
**Ce qu'on voit :** `while (!ok) { try { call(); ok = true; } catch {} }` — retry immédiat en boucle.
**Pourquoi c'est dangereux :** thundering herd. Le service en difficulté reçoit 1000× plus de requêtes à cause des retries. L'incident s'aggrave. Un retry immédiat est une attaque DDoS contre soi-même.
**Faire plutôt :** backoff exponentiel avec jitter. 1s → 2s → 4s → 8s, max 5 tentatives. Le jitter (aléatoire ±25%) empêche la synchronisation des retries de tous les clients.

### Pas de fallback
**Ce qu'on voit :** si Redis est down → 500 Internal Server Error. Le cache est devenu un point de défaillance unique.
**Pourquoi c'est dangereux :** une dépendance non-critique (cache, analytics, recommandations) fait tomber tout le service. Le client voit une erreur pour une fonctionnalité qui aurait pu fonctionner sans cette dépendance.
**Faire plutôt :** si cache down → servir depuis la DB (plus lent mais fonctionnel). Si analytics down → logger localement et réessayer plus tard. Chaque dépendance a un fallback explicite.

### Timeout = 60 secondes
**Ce qu'on voit :** `http.get(url, { timeout: 60000 })`. L'utilisateur attend 60s.
**Pourquoi c'est dangereux :** les threads/workers sont bloqués. Le pool s'épuise. L'app devient non-réactive. Un timeout trop long transforme une défaillance partielle en outage total.
**Faire plutôt :** timeouts agressifs. Connect < 2s, read < 5s. L'utilisateur préfère un échec rapide qu'une attente infinie. Fast fail > slow timeout.

## Patterns
### Circuit Breaker
**Quand :** toute communication avec une dépendance externe.
**Comment :** CLOSED (normal) → OPEN après N échecs consécutifs → HALF_OPEN après timeout → CLOSED si succes. En OPEN, les appels sont rejetés immédiatement (pas de tentative inutile).

### Bulkhead
**Quand :** ressources partagées entre différents appels/clients.
**Comment :** pool de connexions séparé par client. Si un client sature son pool, les autres ne sont pas affectés. Comme les cloisons étanches d'un navire — une voie d'eau ne coule pas le bateau.
