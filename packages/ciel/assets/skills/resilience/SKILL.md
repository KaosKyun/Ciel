---
name: resilience
description: "Resilience — circuit breaker, retry, timeout, bulkhead, fallback, graceful degradation. A charger quand on rend un systeme resilient."
triggers:
  path: "**/resilience*,**/retry*,**/circuit-breaker*,**/fault-tolerance*"
---

# Resilience

## Checklist
- [ ] Les timeouts sont definis sur toutes les appels externes (connect, read, write)
- [ ] Circuit breaker configure pour chaque dependance externe (DB, API, Redis)
- [ ] Retry avec backoff exponentiel + jitter (pas de retry immediat)
- [ ] Bulkhead isole les ressources critiques (pool de connexions separe par client)
- [ ] Fallback defini pour chaque point de defaillance (cache, defaults, degrade)
- [ ] Graceful degradation : le service marche meme si une dependance est down
- [ ] Test de resilience automatise (chaos engineering)

## Anti-patterns
### Retry infini sans backoff
**Ce qu'on voit :** `while (!success) { try { await call(); success = true; } catch {} }`.
**Pourquoi c'est dangereux :** le retry immediat sature le service deja en difficulte. L'incident empire. C'est l'effet "thundering herd".
**Faire plutot :** retry avec backoff exponentiel (1s, 2s, 4s, 8s, max 3-5 tentatives). Jitter pour eviter la synchronisation. Circuit breaker apres N echecs.

### Pas de fallback
**Ce qu'on voit :** si Redis est down, l'application plante avec une erreur 500.
**Pourquoi c'est dangereux :** un cache down rend toute l'application indisponible. Un point de defaillance unique.
**Faire plutot :** si le cache est down, servir les donnees depuis la DB (plus lent mais fonctionnel). Fallback vers des valeurs par defaut. Afficher une version degradee.

### Timeout trop long
**Ce qu'on voit :** `http.get(url, { timeout: 60000 })` pour une API utilisateur.
**Pourquoi c'est dangereux :** l'utilisateur attend 60s. Le thread est bloque. Les connexions s'accumulent. L'application tombe en panne de ressources.
**Faire plutot :** timeout court : connect < 2s, read < 5s, request < 10s. L'utilisateur prefere un echec rapide qu'une attente interminable.

## Patterns
### Circuit Breaker
**Quand :** toute communication avec une dependance externe.
**Comment :** etat CLOSED (normal) → OPEN (apres N echecs) → HALF_OPEN (apres timeout) → CLOSED si succes. Les appels sont coupe net pendant OPEN. Pas de requete inutile.

### Bulkhead
**Quand :** plusieurs clients partagent les memes ressources.
**Comment :** pool de connexions separe par client ou par type de requete. Si un client sature son pool, les autres clients ne sont pas affectes.
